#!/usr/bin/env bash

# shellcheck disable=SC2164 # Use cd ... || exit if cd fails

if command -v security &> /dev/null; then
  # Vault password is stored in macOS "login" Keychain
  # under account "ansible-vault" and service "XCP-ng"
  exec security find-generic-password -a ansible-vault -s XCP-ng -w

elif [ -f /var/lib/awx/.vaultpass ]; then
  cd /var/lib/awx # no ./ansible.cfg here
  # pass encrypted using `awx_secret_key`
  cat <<'EOT' | exec ansible-vault decrypt --vault-password-file .vaultpass 2> /dev/null
$ANSIBLE_VAULT;1.1;AES256
62356262333563656636323935663236316563396235656462643930306666353237626464356265
6233626434386534633962653130663237376238333134630a393066643539323332633666663036
30383435623739613937323032323264353862363064643264383835636338633065343630323034
3739323264346637330a313733623831303062366663373866653564663034363139326166653165
6161
EOT
else
  echo >&2 "No vault password available!"
  exit 1
fi
