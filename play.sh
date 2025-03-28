#!/usr/bin/env bash

# Runs Ansible playbook "ansible/main.yml"
# Passes provided args to ansible-playbook

# shellcheck disable=SC2015 # A && B || C is not if-then-else
# shellcheck disable=SC2164 # Use cd ... || exit if cd fails
# shellcheck disable=SC1091 # Not following: not input file

cd "$(dirname "$0")"

# https://docs.astral.sh/uv/
use_uv=$(command -v uv 2> /dev/null)

echo -e "\nActivating Python virtual environment..."
[ "$use_uv" ] && uv venv --allow-existing || python3 -m venv .venv
. .venv/bin/activate

echo -e "Installing Ansible from requirements...\n"
[ "$use_uv" ] || pip install -U pip
[ "$use_uv" ] && uv sync || pip3 install -r requirements.txt

export ANSIBLE_CONFIG=./ansible.cfg
export ANSIBLE_FORCE_COLOR=true

ansible-playbook "$@" main.yml 2>&1 | tee ansible.log
