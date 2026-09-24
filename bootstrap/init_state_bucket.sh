#!/usr/bin/env bash

set -euo pipefail

BUCKET="sentinel-fadi-tfstate"
REGION="us-east-2"
CI_ROLES="arn:aws:iam::721500739616:role/sentinel-fadi-gha-*"
ME="$(aws sts get-caller-identity --query Arn --output text)"

# 1. Create the bucket if it doesn't exist (ACLs disabled from the start).
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket $BUCKET exists - applying settings."
else
  echo "Creating bucket $BUCKET in $REGION..."
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=$REGION" \
    --object-ownership BucketOwnerEnforced
fi

# 2. Versioning: every state write is kept, so a bad apply can be rolled back.
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# 3. No public access, encryption at rest (SSE-S3; KMS is denied in this account).
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# 4. Retention: old state versions are kept 90 days, then expire.
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration '{
  "Rules": [{
    "ID": "state-version-retention",
    "Status": "Enabled",
    "Filter": {},
    "NoncurrentVersionExpiration": { "NoncurrentDays": 90 },
    "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 1 }
  }]
}'

# 5. Bucket policy:
#    - TLS only
#    - nobody can delete the bucket or purge state versions
#    - only me and the project CI roles can access it (every candidate in this
#      shared account has s3:* on all buckets; without this they could read our state)
aws s3api put-bucket-policy --bucket "$BUCKET" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Sid\": \"DenyInsecureTransport\",
      \"Effect\": \"Deny\", \"Principal\": \"*\", \"Action\": \"s3:*\",
      \"Resource\": [\"arn:aws:s3:::$BUCKET\", \"arn:aws:s3:::$BUCKET/*\"],
      \"Condition\": { \"Bool\": { \"aws:SecureTransport\": \"false\" } }
    },
    {
      \"Sid\": \"DenyDeletion\",
      \"Effect\": \"Deny\", \"Principal\": \"*\",
      \"Action\": [\"s3:DeleteBucket\", \"s3:DeleteObjectVersion\"],
      \"Resource\": [\"arn:aws:s3:::$BUCKET\", \"arn:aws:s3:::$BUCKET/*\"]
    },
    {
      \"Sid\": \"OnlyOwnerAndCi\",
      \"Effect\": \"Deny\", \"Principal\": \"*\", \"Action\": \"s3:*\",
      \"Resource\": [\"arn:aws:s3:::$BUCKET\", \"arn:aws:s3:::$BUCKET/*\"],
      \"Condition\": { \"ArnNotLike\": { \"aws:PrincipalArn\": [\"$ME\", \"$CI_ROLES\"] } }
    }
  ]
}"

echo "Done: s3://$BUCKET is versioned, private, encrypted, delete-protected and restricted to $ME + CI."