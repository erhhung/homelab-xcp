#!/usr/bin/env bash

# creates playbook file temp.yml that is either
# all or a subset of main.yml depending on args,
# unless any arg is a *.yml file name, in which
# case temp.yml is NOT created; prints the args
# list for ansible-playbook unless error occurs
#
# args must be tag names in main.yml; the generated
# runlist will be ordered as in main.yml regardless
# of the order args are given; if only one arg is
# given, it can be suffixed or prefixed with dash
# to select all playbooks starting or ending with
# that tag; simply copies main.yml to temp.yml if
# no args are given

# shellcheck disable=SC2207 # Prefer mapfile to split output
# shellcheck disable=SC2016 # Expr won't expand in '' quotes
# shellcheck disable=SC2128 # Expanding array without index

cd "$(dirname "$0")"
set -eo pipefail

# require given commands
# to be $PATH accessible
_reqcmds() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" &> /dev/null && continue
    echo >&2 "Please install \"$cmd\" first!"
    return 1
  done
}

_reqcmds yq jo || exit $?

prettify() {
  # first sed adds newline between tasks
  # second removes trailing blank lines
  sed -E 's/^([[:space:]]+tags:.+)$/\1\n/' | \
  sed -e :a -e '/./,$!d;/^\n*$/{$d;N;};/\n$/ba'
}

rm -f temp.yml
opts=() tags=()

# first separate playbook tags
# from ansible-playbook options
re='^('
re+='--become-password-file(=.*)?|'
re+='--connection-password-file(=.*)?|'
re+='--skip-tags(=.*)?|'
re+='--start-at-task(=.*)?|'
re+='--vault-id(=.*)?|'
re+='--vault-password-file(=.*)?|'
re+='-M(=.*)?|--module-path(=.*)?|'
re+='-e(=.*)?|--extra-vars(=.*)?|'
re+='-f(=.*)?|--forks(=.*)?|'
re+='-i(=.*)?|--inventory(=.*)?|--inventory-file(=.*)?|'
re+='-l(=.*)?|--limit(=.*)?|'
re+='-t(=.*)?|--tags(=.*)?'
re+=')$'
while [ "$1" ]; do
  if [[ "$1" =~ $re ]]; then
    opts+=("$1") # value expected
    [[ "$1" == *=* ]] || {
      shift; opts+=("$1")
    }
  elif  [[ "$1" =~ ^(-.|--.+)$ ]]; then
    opts+=("$1") # simple flag
  else
    # tag/-tag/tag-
    tags+=("$1")
  fi
  shift
done

# shellcheck disable=SC2329 # Function never called
debug_args() {
  {
  printf "opts:"; printf " %q" "${opts[@]}"; echo
  printf "tags:"; printf " %q" "${tags[@]}"; echo
  } >&2
}
exit_opts() {
  str="$(printf " %q" "${opts[@]}" "$@")"
  echo "${str# }"
  exit 0
}

if [[ " ${tags[*]} " == *".yml "* ]]; then
  # playbook file name given; move
  # all tags back to opts and exit
  exit_opts "${tags[@]}"
fi

TAGS=($(yq '.[].tags' main.yml))

# ensure all tags valid
_tags=()
for tag in "${tags[@]}"; do
  t=${tag#-}; t=${t%-}

  if [[ " ${TAGS[*]} " == *" $t "* ]]; then
    _tags+=("$tag")
  else
    # unrecognized tag;
    # move back to opts
    opts+=("$tag")
  fi
done
tags=("${_tags[@]}")

last=$((${#tags[@]}-1))
[ $last -ge 0 ] || {
  # no tags == ALL tags
  cp main.yml temp.yml
  exit_opts   temp.yml
}

# if any tag is -tag/tag-,
# it must be the only tag
for i in seq 0 $last; do
  if [[ "${tags[$i]}" =~ ^-|-$ ]] && ((last)); then
    echo >&2 "Tag with '-' prefix/suffix cannot be mixed with other tags!"
    exit 1
  fi
done

# debug_args

if [[ "$tags" == -* ]]; then
  # create sliced version of main.yml
  T=${tags#-} yq '. as $d | .[] | select(.tags == env(T)) |
      path[0] as $i |  $d | .[: $i + 1]' main.yml | prettify > temp.yml

elif [[ "$tags" == *- ]]; then
  # create sliced version of main.yml
  T=${tags%-} yq '. as $d | .[] | select(.tags == env(T)) |
      path[0] as $i |  $d | .[$i :]'     main.yml | prettify > temp.yml

else
  # create picked version of main.yml
  picks="$(jo -a -- "${tags[@]}" <<< "")"
  yq -PM 'load("/dev/stdin") as $picks | map(
          select(.tags as $t |  $picks[] == $t))'  \
                  main.yml <<< "$picks" | prettify > temp.yml
fi
exit_opts temp.yml
