# Terraform AWS Modules template

Provisioned from [`Qode-Fleet-Control/fleet-template-v1`](https://github.com/Qode-Fleet-Control/fleet-template-v1) — the fleet
lifecycle contract (`bin/`, `fleet.conf`, `compose.yaml`, deploy workflows) with a
Terraform root module built from the community
[terraform-aws-modules](https://github.com/terraform-aws-modules) laid on top.

**This repo is a job, not a service.** Its container runs `terraform fmt -check`, `init`
and `validate`, then exits — 0 when all of it passes. **No AWS credentials are needed or
used**: `validate` never calls the AWS API. Nothing listens on `$PORT`.

## What is in it

| file | |
|---|---|
| `versions.tf` | `required_version`, `hashicorp/aws ~> 6.29` |
| `providers.tf` | the AWS provider: region from `var.region`, `default_tags` on everything |
| `variables.tf` | name, environment, region, VPC CIDR, AZ count, single/per-AZ NAT |
| `main.tf` | `terraform-aws-modules/vpc/aws ~> 6.7` — public, private and database subnets over N AZs, NAT, DNS, EKS-style subnet tags; `terraform-aws-modules/security-group/aws ~> 6.0` — a web SG (HTTPS in, all out) |
| `outputs.tf` | VPC id, subnet ids, DB subnet group, SG id |
| `.terraform.lock.hcl` | the AWS provider pinned with hashes for linux/darwin amd64+arm64 and windows amd64 — commit it |
| `terraform.tfvars.example` | copy to `terraform.tfvars` (git-ignored) to override defaults |
| `scripts/check.sh` | the job: `fmt -check -recursive`, `init -backend=false -lockfile=readonly`, `validate` |

Subnets are carved from `vpc_cidr` with `cidrsubnet`, and AZ names are built from the
region (`us-east-1a` …) rather than read from the `aws_availability_zones` data source,
so the module stays checkable without an AWS account. Switch to the data source once it
runs with credentials.

## Run it

**On the fleet:** `bin/run` builds the image (`docker compose build`) and stops there —
`DOCKER_START_CMD` is empty because there is no server. Run the job with
`docker compose run --rm app`.

**With docker:**

    docker compose build
    docker compose run --rm app        # exit 0 = fmt, init and validate all passed

**Without docker** (needs `terraform` >= 1.10 on `PATH`):

    sh scripts/check.sh
    # with AWS credentials in the environment, for real:
    terraform init && terraform plan && terraform apply

`FLEET_RUNTIME=process bin/run` runs `INSTALL_CMD` (`terraform init`) and `BUILD_CMD`
(`terraform validate`) and then stops at the start step, by design.

## Origin

    hand-written — Terraform ships no project generator

A root module in HashiCorp's standard module structure consuming registry modules, the
way the terraform-aws-modules READMEs show (`source = "terraform-aws-modules/vpc/aws"`,
`version = "~> 6.7"`). The lock file came from the official image:

    docker run --rm -u $(id -u):$(id -g) -e HOME=/tmp -v "$PWD":/w -w /w hashicorp/terraform:1.16.5 init -backend=false
    docker run --rm -u $(id -u):$(id -g) -e HOME=/tmp -v "$PWD":/w -w /w hashicorp/terraform:1.16.5 \
      providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64 -platform=windows_amd64

## Deviations, and why

- `Dockerfile` is a job image on `hashicorp/terraform:1.16.5`: its `ENTRYPOINT` (`terraform`)
  is cleared and the default command is `scripts/check.sh`. Runs as non-root `app` (uid 10001).
- Unlike the other Terraform templates, `init` runs when the job runs, not at image build:
  the AWS provider is several hundred MB unpacked, and baking it into the image would
  multiply its size for a step that only checks the code. The download is pinned and
  verified by the committed lock file, so the job needs registry access when it runs.
- `init -backend=false`: validation needs no state. Add a backend (S3 + DynamoDB/lockfile)
  before planning against a real account.
- The fleet passes `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` through
  `compose.yaml` (they point at the workspace's MinIO). `init`/`validate` never use them;
  do not run `plan`/`apply` with them.

## Verified

**The docker job has NOT been verified yet.** On 2026-10-05 the build host's docker disk
stayed below the 6 GB floor (0-3 GB free) for over three hours, so `docker compose build`
was never run for this repo. Build and run it once before trusting it:

    docker compose build && docker compose run --rm app; docker compose down --rmi local -v

What WAS checked, with the real CLIs outside docker (same `scripts/check.sh` the image runs):

    terraform 1.16.5: sh scripts/check.sh   # fmt ok, init ok (vpc 6.7.3, security-group 6.0.0, aws 6.67.0),
                                            # validate "Success!" -> exit 0, no AWS credentials set

## Serving over HTTP

There is no HTTP surface. If you add one, listen on `0.0.0.0:$PORT`, serve at `/`, set
`PORT`, `HEALTH_PATH`, `START_CMD` and `DOCKER_START_CMD` in `fleet.conf`, and publish
`"${PORT}:${PORT}"` in `compose.yaml`. See `docs/fleet-lifecycle.md`.
