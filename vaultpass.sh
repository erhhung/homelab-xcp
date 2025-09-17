#!/usr/bin/env bash

# vault password stored in macOS "login" Keychain
# under name "XCP-ng" for account "ansible-vault"
exec security find-generic-password -l XCP-ng -w
