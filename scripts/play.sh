#!/usr/bin/env bash

# runs the specified playbooks (refer to comments
# in runlist.sh for how args are parsed to create
# the runlist)

# shellcheck disable=SC1091 # Not following: not input file
# shellcheck disable=SC2046 # Quote to avoid word splitting
# shellcheck disable=SC2015 # A && B || C isn't if-then-else
# shellcheck disable=SC2207 # Prefer mapfile to split output
# shellcheck disable=SC2155 # Declare and assign separately
# shellcheck disable=SC2198 # Arrays don't work as operands

# run from project root
cd "$(dirname "$0")/.."
set -eo pipefail

# replace script args with modified list
args="$(scripts/runlist.sh "$@")" || exit
eval "set -- $args"

if [ "${@: -1}" == temp.yml ]; then
  # ensure cleanup of temp.yml
  trap "rm -f temp.yml" EXIT
fi

export ANSIBLE_CONFIG=./ansible.cfg
export ANSIBLE_PRIVATE_KEY_FILE=$HOME/.ssh/$USER.pem
export ANSIBLE_FORCE_COLOR=true

# https://docs.astral.sh/uv/
use_uv=$(command -v uv 2> /dev/null)

echo -e "\nActivating Python virtual environment...\n"
[ "$use_uv" ] && uv venv --allow-existing || python3 -m venv .venv
. .venv/bin/activate

echo -e "\nInstalling Ansible from requirements...\n"
[ "$use_uv" ] || python3   -m -U ensurepip
[ "$use_uv" ] && uv      sync -U --no-cache --no-dev --link-mode=copy \
              || pip3 install -U --no-cache-dir -r requirements.txt

# get playbooks that will be run
get_playbooks() {
  jo PLAYBOOKS="$(jo -a \
    $(for arg in "$@"; do
        if [ "$arg" == temp.yml ]; then
          yq '.[].tags | select(.)' temp.yml
        elif [[ $arg == *.yml ]]; then
          basename "${arg%.yml}"
        fi
      done
    ))"
}
# pass extra var to indicate
# playbooks that will be run
extra_vars="$(get_playbooks "$@")"

# install roles from requirements
install_roles() {
  # list of playbooks that use roles
  local use_roles="$(jo -a basics)"

  jq -n --argjson extra_vars "$extra_vars" \
        --argjson use_roles  "$use_roles"  \
    'halt_error(if any($extra_vars.PLAYBOOKS[]; . as $x |
      $use_roles | index($x)) then 0 else 1 end)' || return 0

  echo -e "\nInstalling roles and collections..."
  ansible-galaxy install -r requirements.yml > /dev/null
}
install_roles

# purge facts cache when re-running all playbooks
[ "${@: -1}" == temp.yml ] && [ -f temp.yml ] && \
  diff -q temp.yml main.yml &> /dev/null && \
    rm -f .ansible/facts/*

# strip ANSI color codes
no_color() {
  sed -E 's/(\x1B|\\x1B|\033|\\033)\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g'
}

ansible-playbook "$@" -e "$extra_vars" \
  2>&1 | tee >(no_color > ansible.log)
