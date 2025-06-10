#!/usr/bin/env bash

# Runs Ansible playbook main.yml unless one or more .yml
# files are specified.  If the last argument is a tag in
# main.yml (playbook without .yml extension), plus a '-'
# suffix (e.g. "storage-"), runs all remaining playbooks
# starting with that playbook; otherwise, runs only the
# playbooks specified by tags (e.g. "minio monitoring")

# shellcheck disable=SC1091 # Not following: not input file
# shellcheck disable=SC2164 # Use cd ... || exit if cd fails
# shellcheck disable=SC2207 # Prefer mapfile to split output
# shellcheck disable=SC2015 # A && B || C isn't if-then-else
# shellcheck disable=SC2016 # Expr won't expand in '' quotes
# shellcheck disable=SC2046 # Quote to avoid word splitting
# shellcheck disable=SC2128 # Expanding array without index

cd "$(dirname "$0")"

# require given commands
# to be $PATH accessible
# example: _reqcmds aws jq || return
_reqcmds() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" &> /dev/null && continue
    echo >&2 "Please install \"$cmd\" first!"
    return 1
  done
}

_reqcmds yq jo || exit $?

# https://docs.astral.sh/uv/
use_uv=$(command -v uv 2> /dev/null)

export ANSIBLE_CONFIG=./ansible.cfg
export ANSIBLE_FORCE_COLOR=true

echo -e "\nActivating Python virtual environment..."
[ "$use_uv" ] && uv venv --allow-existing || python3 -m venv .venv
. .venv/bin/activate

echo -e "Installing Ansible from requirements...\n"
[ "$use_uv" ] || pip install -U pip
[ "$use_uv" ] && uv sync || pip3 install -r requirements.txt

prettify() {
  # first sed adds newline between tasks
  # second removes trailing blank lines
  sed -E 's/^([[:space:]]+tags:.+)$/\1\n/' | \
  sed -e :a -e '/./,$!d;/^\n*$/{$d;N;};/\n$/ba'
}

args=("$@")
trap "rm -f temp.yml" EXIT

[[ "${args[*]}" == *.yml* ]] || {
  # check if last arg is tag-
  last=$(( ${#args[@]} -1 ))

  if [[ $last -ge 0 && "${args[last]}" == *- ]]; then
    start="${args[last]%?}" args=("${args[@]::last}")

    # create sliced version of main.yml
    START=$start yq '. as $d | .[] | select(.tags == env(START)) |
               path[0] as $i |  $d | .[$i:]' main.yml | prettify > temp.yml
    args+=("temp.yml")

  elif [ "${args[*]}" ]; then
    picks="$(jo -a -- "${args[@]}" <<< "")"

    # create picked version of main.yml
    yq -PM 'load("/dev/stdin") as $picks | map(
             select(.tags as $t | $picks[] == $t))'  \
                    main.yml <<< "$picks" | prettify > temp.yml

    # remove all args that were picked
    eval "args=($(
      yq -r 'map(.tags) as $picks | load("/dev/stdin")[] |
          select(. as $a | $picks | contains([$a]) | not)' \
             temp.yml <<< "$picks"))"

    # play main.yml if nothing picked
    [ $(yq length temp.yml) -gt 0 ] && \
      args+=("temp.yml") || \
      args+=("main.yml")
  else
    # run all playbooks
    args+=("main.yml")
  fi
}
ansible-playbook "${args[@]}" 2>&1 | tee ansible.log
