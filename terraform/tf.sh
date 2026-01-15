#!/usr/bin/env bash

# shellcheck disable=SC2012 # find is better at non-alphanum
# shellcheck disable=SC2155 # Declare and assign separately
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

# require given commands
# to be $PATH accessible
_reqcmds() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" &> /dev/null && continue
    echo >&2 "Please install \"$cmd\" first!"
    return 1
  done
}

_reqcmds docker || exit $?

if [[ "$1" =~ ^(show|plan|apply|refresh)$ ]]; then
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
  tee >(no_color >> "$LOG")
}

docker_build() {
  log >&2 <<< 'Building Docker image "'$TAG':latest"...'
  docker build --no-cache -t $TAG ./opentofu \
    --progress plain 2>&1 | log >&2 || exit
}

docker_run() {
  local name=$(n=10000; printf "opentofu-%04d" $((RANDOM % n)))
  # mount ~/.aws so OpenTofu can use the AWS provider for backend;
  # mount $TMPDIR because community.general.terraform passes -out
  # parameter to write .tfplan file
  local args=(--rm \
    --name "$name" \
    -h terraform   \
    -v "$(pwd):/terraform" \
    -v "$HOME/.aws:/root/.aws:ro" \
    -v "$TMPDIR:$TMPDIR" \
    "$TAG"
  )
  # allocate TTY if stdout is terminal
  [ -t 1 ] && args=(-it "${args[@]}")
  { set -x
    docker run "${args[@]}" "$@"
  } > >(log) 2> >(log >/dev/null)
}

TAG=opentofu
[ "$(docker images --format "{{.ID}}" $TAG)" ] || docker_build
docker_run tofu "$@"
