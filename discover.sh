#!/usr/bin/env bash
# Sentinel challenge - READ-ONLY permission & account discovery.
# Makes no changes: only Get/List/Describe/Simulate calls.
# Usage:  AWS_PROFILE=sentinel bash discover.sh
# Output: ./sentinel-discovery.txt  (no secrets are written to it)

set -u
OUT="sentinel-discovery.txt"
: > "$OUT"

log()  { echo -e "$*" | tee -a "$OUT"; }
hdr()  { log "\n\n==================== $* ===================="; }
run()  { log "\n\$ $*"; "$@" >>"$OUT" 2>&1 || log "  -> FAILED (exit $?)"; }

REGION="$(aws configure get region 2>/dev/null || echo '')"
REGION="${AWS_REGION:-us-east-2}"   # Candidates_Policy pins this user to us-east-2
export AWS_REGION="$REGION" AWS_PAGER=""

hdr "IDENTITY"
run aws sts get-caller-identity
ARN="$(aws sts get-caller-identity --query Arn --output text)"
ACCT="$(aws sts get-caller-identity --query Account --output text)"
USER="${ARN##*/}"
log "Region: $REGION | Account: $ACCT | User: $USER"

hdr "USER DETAILS (incl. permissions boundary)"
run aws iam get-user --user-name "$USER"

dump_managed() {  # $1 = policy arn
  local v
  v="$(aws iam get-policy --policy-arn "$1" --query Policy.DefaultVersionId --output text 2>>"$OUT")" || return
  run aws iam get-policy-version --policy-arn "$1" --version-id "$v" --query PolicyVersion.Document
}

hdr "USER: ATTACHED MANAGED POLICIES"
run aws iam list-attached-user-policies --user-name "$USER"
for p in $(aws iam list-attached-user-policies --user-name "$USER" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
  log "\n--- $p"; dump_managed "$p"
done

hdr "USER: INLINE POLICIES"
run aws iam list-user-policies --user-name "$USER"
for n in $(aws iam list-user-policies --user-name "$USER" --query 'PolicyNames[]' --output text 2>/dev/null); do
  log "\n--- inline: $n"; run aws iam get-user-policy --user-name "$USER" --policy-name "$n" --query PolicyDocument
done

hdr "PERMISSIONS BOUNDARY DOCUMENT"
PB="$(aws iam get-user --user-name "$USER" --query 'User.PermissionsBoundary.PermissionsBoundaryArn' --output text 2>/dev/null)"
if [[ -n "$PB" && "$PB" != "None" ]]; then dump_managed "$PB"; else log "(none, or not readable)"; fi

hdr "GROUPS"
run aws iam list-groups-for-user --user-name "$USER"
for g in $(aws iam list-groups-for-user --user-name "$USER" --query 'Groups[].GroupName' --output text 2>/dev/null); do
  log "\n##### group: $g"
  for p in $(aws iam list-attached-group-policies --group-name "$g" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
    log "\n--- $p"; dump_managed "$p"
  done
  for n in $(aws iam list-group-policies --group-name "$g" --query 'PolicyNames[]' --output text 2>/dev/null); do
    log "\n--- inline: $n"; run aws iam get-group-policy --group-name "$g" --policy-name "$n" --query PolicyDocument
  done
done

# ---------------------------------------------------------------------------
# Policy simulation (includes permissions boundary + SCP effects when readable).
# NOTE: allows that depend on conditions (tags, PassedToService, etc.) can show
# as implicitDeny here - the raw policy docs above are the ground truth.
# ---------------------------------------------------------------------------
sim() {  # $1 = resource arn ("*" ok), rest = actions
  local res="$1"; shift
  log "\n--- simulate on resource: $res"
  aws iam simulate-principal-policy --policy-source-arn "$ARN" \
    --action-names "$@" --resource-arns "$res" \
    --context-entries "ContextKeyName=aws:RequestedRegion,ContextKeyValues=$REGION,ContextKeyType=string" \
                      "ContextKeyName=aws:username,ContextKeyValues=$USER,ContextKeyType=string" \
    --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output table >>"$OUT" 2>&1 \
    || log "  -> simulate FAILED (probably no iam:SimulatePrincipalPolicy)"
}

hdr "SIMULATION: EC2 / VPC / NETWORKING"
sim "*" ec2:CreateVpc ec2:CreateSubnet ec2:CreateInternetGateway ec2:AttachInternetGateway \
  ec2:AllocateAddress ec2:CreateNatGateway ec2:CreateRouteTable ec2:CreateRoute ec2:AssociateRouteTable \
  ec2:CreateSecurityGroup ec2:AuthorizeSecurityGroupIngress ec2:AuthorizeSecurityGroupEgress \
  ec2:CreateVpcPeeringConnection ec2:AcceptVpcPeeringConnection ec2:ModifyVpcPeeringConnectionOptions \
  ec2:CreateTransitGateway ec2:CreateVpcEndpoint ec2:CreateFlowLogs ec2:CreateTags \
  ec2:CreateLaunchTemplate ec2:RunInstances ec2:DescribeAvailabilityZones ec2:DeleteVpc

hdr "SIMULATION: EKS"
sim "*" eks:CreateCluster eks:DescribeCluster eks:CreateNodegroup eks:CreateAddon eks:DescribeAddonVersions \
  eks:CreateAccessEntry eks:AssociateAccessPolicy eks:CreatePodIdentityAssociation eks:TagResource \
  eks:UpdateClusterConfig eks:DeleteCluster

hdr "SIMULATION: IAM ROLES by name prefix"
for r in eks-probe sentinel-probe other-probe; do
  sim "arn:aws:iam::$ACCT:role/$r" iam:CreateRole iam:GetRole iam:TagRole iam:AttachRolePolicy \
    iam:PutRolePolicy iam:DeleteRolePolicy iam:PassRole iam:UpdateAssumeRolePolicy iam:DeleteRole
done

hdr "SIMULATION: IAM POLICIES / OIDC / MISC"
for p in eks-probe sentinel-probe other-probe; do
  sim "arn:aws:iam::$ACCT:policy/$p" iam:CreatePolicy iam:CreatePolicyVersion iam:DeletePolicy
done
sim "arn:aws:iam::$ACCT:oidc-provider/token.actions.githubusercontent.com" \
  iam:CreateOpenIDConnectProvider iam:GetOpenIDConnectProvider iam:TagOpenIDConnectProvider
sim "*" iam:CreateServiceLinkedRole iam:ListOpenIDConnectProviders iam:CreateInstanceProfile iam:ListRoles

hdr "SIMULATION: STATE BACKEND, LB, KMS, ECR, LOGS, SSM"
sim "*" s3:CreateBucket s3:PutBucketVersioning s3:PutEncryptionConfiguration s3:PutBucketPolicy \
  s3:PutBucketPublicAccessBlock s3:PutObject s3:GetObject s3:ListAllMyBuckets \
  dynamodb:CreateTable dynamodb:PutItem \
  elasticloadbalancing:CreateLoadBalancer elasticloadbalancing:CreateTargetGroup \
  elasticloadbalancing:CreateListener elasticloadbalancing:ModifyLoadBalancerAttributes \
  kms:CreateKey kms:CreateAlias kms:CreateGrant \
  ecr:CreateRepository ecr:PutImage ecr:GetAuthorizationToken \
  logs:CreateLogGroup logs:PutRetentionPolicy \
  autoscaling:CreateAutoScalingGroup ssm:GetParameter \
  servicequotas:GetServiceQuota

# ---------------------------------------------------------------------------
hdr "EXISTING STATE IN ACCOUNT ($REGION)"
run aws ec2 describe-availability-zones --query 'AvailabilityZones[].[ZoneName,ZoneId,State]' --output table
run aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock,IsDefault,Tags[?Key==`Name`]|[0].Value]' --output table
run aws ec2 describe-addresses --query 'Addresses[].[PublicIp,AllocationId,AssociationId]' --output table
run aws ec2 describe-nat-gateways --query 'NatGateways[].[NatGatewayId,State,VpcId]' --output table
run aws ec2 describe-vpc-peering-connections --query 'VpcPeeringConnections[].[VpcPeeringConnectionId,Status.Code]' --output table
run aws eks list-clusters
run aws eks describe-cluster --name eks-gateway --query 'cluster.[name,status,version]'
run aws eks describe-cluster --name eks-backend --query 'cluster.[name,status,version]'
run aws ec2 describe-subnets --query 'Subnets[].[SubnetId,VpcId,CidrBlock,AvailabilityZone]' --output table
run aws ec2 describe-instance-type-offerings --location-type availability-zone --filters Name=instance-type,Values=t3.medium,t3.small --query 'InstanceTypeOfferings[].[InstanceType,Location]' --output table
run aws iam get-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::$ACCT:oidc-provider/token.actions.githubusercontent.com"
run aws iam list-open-id-connect-providers
run aws s3api list-buckets --query 'Buckets[].Name'
run aws dynamodb list-tables
run aws ecr describe-repositories --query 'repositories[].repositoryName'
run aws elbv2 describe-load-balancers --query 'LoadBalancers[].[LoadBalancerName,Scheme,Type]' --output table

hdr "QUOTAS (relevant limits)"
run aws service-quotas get-service-quota --service-code ec2 --quota-code L-0263D0A3 --query 'Quota.[QuotaName,Value]'   # EIPs per region
run aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE --query 'Quota.[QuotaName,Value]'   # VPCs per region
run aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A --query 'Quota.[QuotaName,Value]'   # On-demand std vCPUs

log "\n\nDONE. Report written to $(pwd)/$OUT"