# shellcheck disable=SC1091
# shellcheck disable=SC2148
# shellcheck disable=SC2207

source /etc/profile
source "$HOME/.bash_profile"

export ANSIBLE_CONFIG="./ansible.cfg"
export VAULTFILE="group_vars/all/vault.yml"

alias ev='ansible-vault edit $VAULTFILE'
alias vv='ansible-vault view $VAULTFILE'
alias ap='ansible-playbook'
alias al='ansible-lint'

# run play.sh from any project subdirectory
# and allow tab completion of playbook tags
play() {
  local root
  root=$(git rev-parse --show-toplevel 2> /dev/null)

  [ $? -eq 128 ] && {
    echo >&2 "Not in a Git repository!"
    return 128
  }
  "$root/play.sh" "$@"
}

# enable tab completion if yq is installed
command -v yq &> /dev/null && {
  _complete_play() {

    local root main args cur tag tags=()
    root=$(git rev-parse --show-toplevel 2> /dev/null)
    main="$root/main.yml"

    [ -f "$main" ] || {
      COMPREPLY=()
      return
    }
    args=" ${COMP_WORDS[*]:1} "
      cur="${COMP_WORDS[COMP_CWORD]}"

    # offer tags that are not already in args
    for tag in $(yq 'map(.tags)[]' "$main"); do
      [[ "$args" != *" $tag "* ]] && tags+=("$tag")
    done
    COMPREPLY=($(compgen -W "${tags[*]}" -- "$cur"))
  }
  complete -F _complete_play play
}
