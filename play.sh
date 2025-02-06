#!/usr/bin/env bash

# Run Ansible playbook "ansible/main.yml"

# shellcheck disable=SC2164 # Use cd ... || exit if cd fails
# shellcheck disable=SC1091 # Not following: not input file

cd "$(dirname "$0")/ansible"

echo -e "\nActivating Python virtual environment..."
python3 -m venv .venv
. .venv/bin/activate

echo -e "Installing Ansible from requirements...\n"
pip3 install -r requirements.txt

export ANSIBLE_CONFIG=./ansible.cfg
ansible-playbook main.yml
