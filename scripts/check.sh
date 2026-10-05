#!/bin/sh
# The job: format check, init (modules + providers), validate. No AWS credentials are
# needed or used: validate never calls the AWS API. Exits non-zero on the first failure.
set -eu
cd "$(dirname "$0")/.."
echo "==> terraform fmt -check";  terraform fmt -check -recursive -diff
echo "==> terraform init";        terraform init -input=false -backend=false -lockfile=readonly
echo "==> terraform validate";    terraform validate
