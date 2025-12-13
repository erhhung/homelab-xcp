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
[ "$use_uv" ] || pip3 install --no-cache-dir --upgrade pip
[ "$use_uv" ] && uv   sync    --no-cache     --no-dev  \
              || pip3 install --no-cache-dir -r requirements.txt

# get playbooks that will be run
get_playbooks() {
  jo PLAYBOOKS="$(jo -a \
    $(for arg in "$@"; do
        if [ "$arg" == temp.yml ]; then
          yq 'map(.tags)[]' temp.yml
        elif [[ $arg == *.yml ]]; then
          basename "${arg%.yml}"
        fi
      done
    ))"
}
# pass extra var to indicate
# playbooks that will be run
extra_vars="$(get_playbooks "$@")"

# strip ANSI color codes
no_color() {
  sed -E 's/(\x1B|\\x1B|\033|\\033)\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g'
}

ansible-playbook "$@" -e "$extra_vars" \
  2>&1 | tee >(no_color > ansible.log)
