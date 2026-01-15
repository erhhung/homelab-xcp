# Provision Kubernetes Cluster Nodes on XCP-ng using Terraform

## Local Environment

A pinned version of OpenTofu has been baked into the custom Docker
image that will be built and run by "`tf.sh`".  
Aside from **Docker** itself, no tools need to be installed in the
local environment.

## Terraform State

Create S3 bucket for OpenTofu to store its state _(assumes
**AWS CLI profile `personal` already exists!**)_:

```bash
AWS_PROFILE=personal
BUCKET=homelab-infra-tfstate
REGION=us-west-2

aws s3api create-bucket \
  --bucket $BUCKET \
  --create-bucket-configuration "LocationConstraint=$REGION" \
  --object-ownership BucketOwnerEnforced

aws s3api put-public-access-block \
  --bucket $BUCKET \
  --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'

aws s3api put-bucket-encryption \
  --bucket $BUCKET \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-bucket-policy \
  --bucket $BUCKET \
  --policy '{"Version":"2012-10-17","Statement":[{"Sid":"OnlyAllowAccessViaTLS","Effect":"Deny","Principal":"*","Action":"s3:*","Resource":["arn:aws:s3:::'$BUCKET'/*","arn:aws:s3:::'$BUCKET'"],"Condition":{"Bool":{"aws:SecureTransport":"false"}}}]}'
```

## Terraform Init

```bash
./tf.sh init
```

## Terraform Apply

```bash
./tf.sh apply
```

## Auto-Install ISO

Cluster nodes are provisioned using **Ubuntu 24.04 Server Minimal**.
The stock `ubuntu-24.04.3-live-server-amd64.iso` ISO image has been
patched by `utils/ubuntu-autoinstall-generator.sh` to add `autoinstall`
to the kernel command line and to reduce the GRUB timeout to 1 second.

The patched `ubuntu-24.04.3-autoinstall-amd64.iso` ISO image has been
added to the XCP-ng "Shared ISO library" NFS storage repository with
the VDI object tagged as `shared`:

```bash
xe vdi-param-add uuid=<vdi-uuid> param-name=tags param-key=shared
```
