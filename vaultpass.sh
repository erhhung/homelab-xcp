#!/usr/bin/env bash

# Vault password is stored in macOS "login" Keychain
# under account "ansible-vault" and service "XCP-ng"
exec security find-generic-password -a ansible-vault -s XCP-ng -w
