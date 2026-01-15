# https://opentofu.org/docs/intro/install/docker
# https://opentofu.org/docs/intro/install/docker#building-your-own-image

FROM ghcr.io/opentofu/opentofu:1.11.2-minimal AS tofu

FROM alpine:latest

COPY --from=tofu /usr/local/bin/tofu /usr/local/bin/

RUN apk add --no-cache ca-certificates openssh sshpass
# add fourteeners.local CA certificate to trust store
COPY ./ca.crt /usr/local/share/ca-certificates/ca.crt
RUN update-ca-certificates

# https://github.com/vatesfr/terraform-provider-xenorchestra#log-to-file
ENV TF_LOG_PROVIDER="DEBUG"
ENV TF_LOG_PATH="provider.log"

# https://developer.hashicorp.com/terraform/cli/config/environment-variables#tf_cli_args-and-tf_cli_args_name
ENV TF_CLI_ARGS_init="-upgrade -backend-config=state.config"
ENV TF_CLI_ARGS_plan="-var-file=creds.tfvars -var-file=k8s.tfvars -out=k8s.tfplan"
ENV TF_CLI_ARGS_apply="-var-file=creds.tfvars -var-file=k8s.tfvars -auto-approve"
ENV TF_CLI_ARGS_destroy="-var-file=creds.tfvars -var-file=k8s.tfvars"

WORKDIR /terraform
