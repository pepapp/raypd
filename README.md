# Rapyd Sentinel

## TL;DR

Two isolated VPCs, each with its own EKS cluster, in `us-east-2`:

- **Gateway** (`vpc-gateway`, `eks-gateway`): HAProxy behind a public NLB. This is the only thing on the internet.
- **Backend** (`vpc-backend`, `eks-backend`): the `web` service behind an **internal** NLB. It's reachable only from the gateway's nodes, over VPC peering.

```
internet ─► public NLB ─► HAProxy (eks-gateway) ─► VPC peering ─► internal NLB ─► web pods (eks-backend)
```

Everything is Terraform modules, deployed by GitHub Actions (OIDC, no stored AWS keys). Nothing is applied from a laptop except the one-time bootstrap.

👉 **[How to test](#how-to-test)**

---

## How to test

```bash
curl http://sentinel-gateway-haproxy-09e7aa4cf7df2269.elb.us-east-2.amazonaws.com/            # hello from backend!
```

The backend is not public:

```bash
BACKEND=$(aws elbv2 describe-load-balancers --names sentinel-backend-web --region us-east-2 \
  --query "LoadBalancers[0].DNSName" --output text)
dig +short $BACKEND              # private 10.11.x.x addresses only
curl http://$BACKEND/       # times out - internal NLB, and its SG only allows the gateway's private subnets
```

---

## Repository layout

```
.github/workflows/
  lint.yml          terraform fmt, tflint, terraform validate (every stack)
  terraform.yml     plan on every branch, apply on master - changed stacks only, in dependency order
  services.yml      build image + bake chart for changed services, push to ECR on master

bootstrap/          one-time, run locally: Terraform state bucket + GitHub OIDC roles for CI

terraform/
  modules/          vpc, vpc-peering, eks, ecr, aws-lb-controller, helm-service
  resources/        the stacks (one state each):
    vpc/              both VPCs, NAT gateways, peering + routes
    eks/              both clusters, node groups, add-ons, access entries
    ecr/              image + chart repositories per service
    services/envs/
      backend/        AWS LB Controller + the services running in eks-backend
      gateway/        AWS LB Controller + the services running in eks-gateway

services/<name>/    one folder per service
  infra/defaults.yaml   service settings (chart type, port, replicas, load balancer)
  infra/Dockerfile      only for services we build (web); absent for upstream ones (haproxy)

helms/
  deployment/       generic chart for our own services (Deployment, ClusterIP, optional NLB)
  haproxy/          thin wrapper around the official haproxytech/haproxy chart

scripts/
  stacks.py         finds the Terraform stacks and orders them by dependency
  bake_chart.py     merges a service's defaults.yaml into its chart
```

---

## Design

### Stacks and dependencies

Each directory under `terraform/resources` with a `backend.tf` is a **stack**: its own state file in S3, with S3-native locking. An optional `tf_info` file declares what must exist first:

```
# terraform/resources/services/envs/gateway/tf_info
depends_on: [eks, ecr, backend]
```

| Stack | Depends on | Why |
|---|---|---|
| `vpc` | – | |
| `ecr` | – | |
| `eks` | `vpc` | clusters go into the VPCs' private subnets |
| `backend` | `eks`, `ecr` | installs charts from ECR into `eks-backend` |
| `gateway` | `eks`, `ecr`, `backend` | HAProxy is configured with the backend NLB's DNS name |

`scripts/stacks.py` reads these files and prints the stacks in execution order. With `--changed`, it keeps only the stacks affected by a commit: the stack's own files, any local module it uses, and anything that depends on it.

Stacks read what they need with data sources (VPCs by name, subnets by tag, the backend NLB by name), not with remote state.

### CI/CD

| Workflow | Runs on | What it does |
|---|---|---|
| `lint` | every push | `fmt -check`, `tflint --recursive`, `validate` per stack |
| `terraform` | every push | **plan** the changed stacks (parallel, plan role); on **master**, **apply** them one by one in dependency order (apply role) |
| `services` | every push | build image (if there's a Dockerfile), bake chart, `helm lint` + `kubeconform`; on **master**, push image + chart to ECR |

### Services: build once, deploy by version

1. **Build (CI).** For each changed service, `services.yml` produces two immutable artifacts:
   - image `sentinel-fadi-images/<svc>:<sha7>`
   - chart `sentinel-fadi-charts/<svc>:<chart version>-g<sha7>`: the chart from `helms/<type>`, plus the service's `defaults.yaml`, plus that image.

   ECR tags are immutable and scanned on push.
2. **Deploy (CD).** Each environment stack lists what runs in its cluster, pinned to an exact chart version:

   ```hcl
   # terraform/resources/services/envs/backend/locals.tf
   web = {
     version   = "0.1.0-g1a2b3c4"
     namespace = "web"
     values    = { 
      service = { 
        loadBalancer = { 
          sourceRanges = [
            "10.10.0.0/20",
            "10.10.16.0/20"] 
        } 
      }
      }
   }
   ```

   **A deploy is a PR that bumps `version`.** The PR's plan shows the diff. Merging applies it through the Terraform Helm provider, which waits for the rollout and rolls back if it fails. Reverting the PR is the rollback.

Values are layered: chart defaults values, then the service's `defaults.yaml`, then environment overrides in `locals.tf`.

Adding a service: create `services/<name>/`, add `<name>` to the ECR stack, then add it to an environment's `locals.tf`.

### Branches and permissions

CI assumes AWS roles through GitHub OIDC. The trust policies are pinned to this repository's ID-based `sub` claim.

| | Plan role `sentinel-fadi-gha-plan-v2` | Apply role `sentinel-fadi-gha-apply-v2` |
|---|---|---|
| Who can assume it | any branch of this repo | **only** `refs/heads/master` |
| AWS | read-only, scoped to this project, plus the state lock | create and modify, scoped to this project's resources |
| Terraform state | read `envs/*`, write lock files only | read/write `envs/*`; never the bootstrap state |
| Kubernetes | read-only access entry (`AmazonEKSAdminViewPolicy`) | cluster admin (it created the clusters) |
| ECR | pull charts (for Helm diffs) | push `sentinel-fadi-*` repos |

- **Feature branches** can lint, plan and build, but can't change anything.
- **`master`** is the only branch that applies. With branch protection (PR plus green checks), a review is the gate for every change.
- **Separate IAM namespaces:** CI can create and manage `eks-fadi-*` roles only, for workloads like the cluster, the nodes and the LB controller. Its own `sentinel-fadi-gha-*` roles are out of its reach, so CI can't widen its own permissions.
- **Trade-off:** the plan role's read access to the clusters includes Secrets, because Helm stores its release state in Secrets. Nothing sensitive runs in the clusters. The stricter option would be to not plan the service stacks on feature branches at all.
