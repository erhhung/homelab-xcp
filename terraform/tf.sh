#!/usr/bin/env bash

# shellcheck disable=SC2012 # find is better at non-alphanum
# shellcheck disable=SC2155 # Declare and assign separately
# shellcheck disable=SC2206 # Quote to avoid word splitting
# shellcheck disable=SC2086 # Double quote prevent globbing

cd "$(dirname "$0")"
set -eo pipefail

[ "$1" ] || {
  script=$(basename "$0")
  cat <<EOT
Run OpenTofu command from Docker container
that has required tools already installed.

  Usage: $script <opentofu-command>
Example: $script apply
EOT
  exit
}

# require any of commands
# to be $PATH accessible
_reqany() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" &> /dev/null && return
  done
  (IFS=/; echo >&2 "Please install any of $* first!")
  return 1
}
_reqany docker buildah || exit $?

if command -v docker &> /dev/null && \
         docker info &> /dev/null; then
  DOCKER=docker
elif command -v buildah &> /dev/null && \
           buildah info &> /dev/null; then
  DOCKER=buildah
else
  echo >&2 "Please install Docker or Buildah"
  exit 1
fi

if [[ "$1" =~ ^(show|plan|apply|refresh|destroy)$ ]]; then
  LOG=$(basename "$0" .sh).log
  rm -f "$LOG"
else
  LOG=/dev/null
fi

# strip ANSI color codes
no_color() {
  sed -E 's/(\x1B|\\x1B|\033|\\033)\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g'
}

# show color output but
#  no color in log file
log() {
  local log="$LOG"
  # append optional extension to log filename unless /dev/null
  [ "$LOG" == /dev/null ] || log+="$1"
  tee >(no_color >> "$log")
}

docker_build() {
  log >&2 <<< 'Building Docker image "'$TAG':latest"...'
  local args=(--no-cache -t $TAG ./opentofu)
  [ $DOCKER == docker ] && args+=(--progress plain)
  $DOCKER build "${args[@]}" 2>&1 | log >&2 || exit
}

docker_run() {
  local name=$(n=10000; printf "opentofu-%04d" $((RANDOM % n)))
  # mount ~/.aws so OpenTofu can use the AWS provider for backend
  # mount $TMPDIR because community.general.terraform passes -out
  # parameter to write .tfplan file
  local args common_args=(
    --hostname  terraform
    -v "$(pwd):/terraform"
    -v "$HOME/.aws:/root/.aws:ro"
    -v "${TMPDIR:-/tmp}:/tmp"
  )

  if [ $DOCKER == docker ]; then
    args=(--rm --name $name "${common_args[@]}" $TAG)
    # allocate TTY if stdout is terminal
    [ -t 1 ] && args=(-it "${args[@]}")

    ( [ "$2" == init ] || echo; set -x
      $DOCKER run "${args[@]}" "$@"
    # write stdout and stderr to separate files
    # to avoid interleaving--combine them later
    ) > >(log .out) 2> >(log .err >/dev/null)

  else # buildah
    args=("${common_args[@]}" $name)
    # allocate TTY if stdout is terminal
    [ -t 1 ] && args=(-t "${args[@]}")

    ( trap '$DOCKER rm $name &> /dev/null' EXIT
      [ "$2" == init ] || echo; set -x
      $DOCKER from --name $name $TAG >&2
      $DOCKER run  "${args[@]}" "$@"
    # write stdout and stderr to separate files
    # to avoid interleaving--combine them later
    ) > >(log .out) 2> >(log .err >/dev/null)
  fi

  [ "$LOG" == /dev/null ] || {
    cat   "$LOG.err" "$LOG.out" > "$LOG"
    rm -f "$LOG".*
  }
}

TAG=opentofu
[ "$($DOCKER images --format "{{.ID}}" $TAG 2> /dev/null)" ] || docker_build
docker_run tofu "$@"
