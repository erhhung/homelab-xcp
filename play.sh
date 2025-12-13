#!/usr/bin/env bash

# runs the specified playbooks (refer to comments
# in runlist.sh for how args are parsed to create
# the runlist)

# shellcheck disable=SC1091 # Not following: not input file
# shellcheck disable=SC2015 # A && B || C isn't if-then-else
# shellcheck disable=SC2207 # Prefer mapfile to split output
# shellcheck disable=SC2155 # Declare and assign separately
# shellcheck disable=SC2198 # Arrays don't work as operands

cd "$(dirname "$0")"
set -eo pipefail

# replace $@ with updated args list
args="$(./runlist.sh "$@")" || exit
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

echo -e "\nActivating Python virtual environment..."
[ "$use_uv" ] && uv venv --allow-existing || python3 -m venv .venv
. .venv/bin/activate

echo -e "Installing Ansible from requirements...\n"
[ "$use_uv" ] || pip install -U pip
[ "$use_uv" ] && uv sync || pip3 install -r requirements.txt

# get playbooks that will be run
get_playbooks() {
  local str list=($(
    for arg in "$@"; do
      if [ "$arg" == temp.yml ]; then
        yq 'map(.tags)[]' temp.yml
      elif [[ $arg == *.yml ]]; then
        echo "${arg%.yml}"
      fi
    done
  ))
  str="${list[*]}"
  echo "${str// /,}"
}

# get tags specified by -t|--tags
get_tags() {
  local str list=($(
    for i in $(seq $#); do
      if [[ ${!i} == -t || \
            ${!i} == --tags ]]; then
        ((++i)); echo "${!i}"
      elif [[ ${!i} == -t=* || \
              ${!i} == --tags=* ]]; then
        echo "${!i#*=}"
      fi
    done
  ))
  str="${list[*]}"
  echo "${str// /,}"
}

# strip ANSI color codes
no_color() {
  sed -E 's/(\x1B|\\x1B|\033|\\033)\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g'
}

# inject global vars to indicate playbooks that will
# be run and tags on which to filter plays and tasks
ansible-playbook                "$@"   \
  -e PLAYBOOKS="$(get_playbooks "$@")" \
  -e      TAGS="$(get_tags      "$@")" \
  2>&1 | tee >(no_color > ansible.log)
