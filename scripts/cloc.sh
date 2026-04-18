#!/usr/bin/env bash

# shellcheck disable=SC2178 # Variable was used as an array
# shellcheck disable=SC2128 # Expanding array without index

# copies relevant project files (filtered `git ls-files` list)
# into temporary subdirectory "cloc/", then decrypts encrypted
# Ansible Vault files, decompresses .gz and unpacks .tar files,
# before running `cloc` to produce the most accurate stats

# usage: cloc.sh [cloc-opts...]
#   e.g. cloc.sh --csv | csvlens

# INSTALL REQUIRED TOOLS
# https://github.com/AlDanial/cloc
# https://github.com/BurntSushi/ripgrep
# brew install cloc coreutils ripgrep

# run from project root
cd "$(dirname "$0")/.."
set -eo pipefail

# `grep -vE` patterns
EXCLUSIONS=(
  '^playbooks/vars'
)

# all args to this script will
# be included as extra options
CLOC_OPTS=(
   --quiet
  '--force-lang=Bourne Again Shell,sh'
)

export ANSIBLE_CONFIG="./ansible.cfg"

# require given commands
# to be $PATH accessible
# example: reqcmds age || return
reqcmds() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" &> /dev/null && continue
    echo >&2 "Please install \"$cmd\" first!"
    return 1
  done
}

# ensure required tools installed
reqcmds cloc rg gzip ansible-vault age || exit

# return first command found
altcmd() {
  local cmd
  for cmd in "$@"; do
    command -v  "$cmd" &> /dev/null || continue
    printf "%s" "$cmd"
    return 0
  done
  cmd="$*"
  echo >&2 "Please install \"${cmd// /\" or \"}\"."
  return 1
}

# use GNU versions of Linux utils on macOS
GREP=$(altcmd ggrep grep) || exit
FIND=$(altcmd gfind find) || exit
  CP=$(altcmd gcp   cp)   || exit

TEMP="cloc"
cleanup() {
  rm -rf "$TEMP"
}
cleanup
mkdir -p "$TEMP"
trap cleanup EXIT

# get list of project files
# with $EXCLUSIONS applied
project_files() {
  local files pat
  files="$(git ls-files)"
  for pat in "${EXCLUSIONS[@]}"; do
    files="$($GREP -vE "$pat" <<< "$files")"
  done
  echo "$files"
}

# duplicate files into temp dir
duplicate_files() {
  local path
  while read -r path; do
    # --parents requires GNU cp
    $CP --parents "$path" "$TEMP"
  done <<< "$(project_files)"
}

# get list of project files that
# are encrypted by Ansible Vault
vault_files() {
  rg -lU --sort=path --color=never \
    '\A\$ANSIBLE_VAULT;' "$TEMP"
}

# decrypt one or more Vault files
unvault_files() {
  local files
  mapfile -t files < <(vault_files)
  ansible-vault decrypt "${files[@]}" 2> /dev/null
}

# find files for special handling
special_files() {
  $FIND "$TEMP" -type f \
    \(  -name '*.gz'  \
    -or -name '*.tar' \)
}

# unpack one or more files for cloc
unpack_files() {
  local path dir
  while read -r path; do
    dir=$(dirname "$path")

    case "$path" in
      *.gz)
        # *.gz will become file
        # without .gz extension
        gzip -d "$path"
        ;;
      *.tar)
        # unpack *.tar file into same
        # dir and delete if successful
        tar -C "$dir" -xf "$path" && rm -f "$path"
        ;;
    esac
  done
}

duplicate_files
unvault_files

while files="$(special_files)" && [ "$files" ]; do
  unpack_files <<< "$files"
done

# suppress cloc version and timing stats
cloc "${CLOC_OPTS[@]}" "$@" "$TEMP" | \
  sed -E 's/(^|,")github.com.+cloc.+$//'
