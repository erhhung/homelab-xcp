#!/usr/bin/env bash

# the vault password is stored in macOS Keychain
# under item "XCP-ng" for account "ansible-vault"
exec security find-generic-password -l XCP-ng -w
