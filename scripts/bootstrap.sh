#!/usr/bin/env bash
# Project Bedrock — one-time bootstrap script
# Run this ONCE before terraform init to create the remote state bucket.
# Usage: ./scripts/bootstrap.sh

set -euo pipefail

STUDENT_ID="alt-soe-025-3783"
REGION="us-east-1"
STATE_BUCKET="project-bedrock-tfstate-${STUDENT_ID}"
LOCK_TABLE="project-bedrock-tfstate-lock"
TAG="Project=karatu-2025-capstone"

echo "==> Creating Terraform state S3 bucket: ${STATE_BUCKET}"
aws s3api create-bucket \
  --bucket "${STATE_BUCKET}" \
  --region "${REGION}"

echo "==> Enabling versioning"
aws s3api put-bucket-versioning \
  --bucket "${STATE_BUCKET}" \
  --versioning-configuration Status=Enabled

echo "==> Enabling SSE encryption"
aws s3api put-bucket-encryption \
  --bucket "${STATE_BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "==> Blocking public access"
aws s3api put-public-access-block \
  --bucket "${STATE_BUCKET}" \
  --public-access-block-configuration \
  'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'

echo "==> Tagging state bucket"
aws s3api put-bucket-tagging \
  --bucket "${STATE_BUCKET}" \
  --tagging "TagSet=[{Key=Project,Value=karatu-2025-capstone}]"

echo "==> Creating DynamoDB lock table (optional, for state locking)"
aws dynamodb create-table \
  --table-name "${LOCK_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}" \
  --tags "Key=Project,Value=karatu-2025-capstone" || echo "Lock table may already exist — continuing"

echo ""
echo "Bootstrap complete! Now run:"
echo "  cd terraform && terraform init"
