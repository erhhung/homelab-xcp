# shellcheck disable=SC1091
# shellcheck disable=SC2148
# shellcheck disable=SC2155
# shellcheck disable=SC2207

# load ~/.bash_profile only if not
# done so because it takes a while
alias omp &> /dev/null || {
  source         /etc/profile
  source "$HOME/.bash_profile"
}

git_root() {
  local root
  root=$(git rev-parse --show-toplevel 2> /dev/null)

  [ $? -eq 128 ] && {
    echo >&2 "Not in a Git repository!"
    return 128
  }
  echo "$root"
}

export ANSIBLE_CONFIG="./ansible.cfg"
VAULTFILE="inventory/group_vars/all/vault.yml"

alias al='ansible-lint'
alias ap='ansible-playbook'
alias av='ansible-vault'

__av() (
  cmd="$1" file=$(realpath "$2")
  cd "$(git_root)" || exit
  export EDITOR=$(which emacs)
  ansible-vault "$cmd" "$file"
)
ev() { __av edit    "${1:-$VAULTFILE}"; }
vv() { __av view    "${1:-$VAULTFILE}"; }
ve() { __av encrypt "$1"; }
vd() { __av decrypt "$1"; }

debug() {
  local args root
  root=$(git_root) || return $?

  args=("$root/playbooks/debug.yml")
  [ "$1" ] && args+=(-t "$@")
  "$root/scripts/play.sh" "${args[@]}"
}

# run play.sh from any project subdirectory
# and allow tab completion of playbook tags
play() {
  local root
  root=$(git_root) || return $?
  "$root/scripts/play.sh" "$@"
}

plays() {
  local root
  root=$(git_root) || return $?
  yq '.[].tags | select(.)' "$root/main.yml"
}

# use latest version of GNU Make
command -v gmake &> /dev/null && {
  alias make='gmake'
}

# enable completions if yq is installed
command -v yq &> /dev/null && {
  _complete_play()  { _complete_tags main;  }
  _complete_debug() { _complete_tags playbooks/debug; }
  _complete_tags()  {

    local root book="$1" args cur tag tags=()
    root=$(git rev-parse --show-toplevel 2> /dev/null)
    book="$root/$book.yml"

    [ -f "$book" ] || {
      COMPREPLY=()
      return
    }
    args=" ${COMP_WORDS[*]:1} "
      cur="${COMP_WORDS[COMP_CWORD]}"

    # only show tags not already in args
    for tag in $(yq '.[].tags | select(.)' "$book"); do
      [[ "$args" != *" $tag "* ]] && tags+=("$tag")
    done
    COMPREPLY=($(compgen -W "${tags[*]}" -- "$cur"))
  }
  complete -F _complete_play  play
  complete -F _complete_debug debug
}
