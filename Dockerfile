# Built by .github/workflows/deploy.yml (context ., file Dockerfile) and pushed
# to Artifact Registry.
#
# A job image, not a server: the default command runs scripts/check.sh
# (fmt -check, init, validate) and exits 0 when all of it passes. It never
# listens on $PORT, and needs no AWS credentials.
#
# `terraform init` runs when the JOB runs, not at build: the AWS provider is
# several hundred MB unpacked, and baking it into every image would make the
# image that much bigger for a step that only checks the code. The download
# is pinned and verified by the committed .terraform.lock.hcl.

FROM hashicorp/terraform:1.16.5 AS runtime
ARG BUILD_ID=""
ENV BUILD_ID=$BUILD_ID TF_IN_AUTOMATION=1 TF_INPUT=0 HOME=/home/app
RUN adduser -D -u 10001 -h /home/app app \
 && mkdir /app && chown app:app /app
WORKDIR /app
COPY --chown=app:app . .
USER app
# the base image's ENTRYPOINT is `terraform`; the job is a script
ENTRYPOINT []
CMD ["sh", "scripts/check.sh"]
