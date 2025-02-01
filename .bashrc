# source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

alias cdd='cd "$OLDPWD"'
alias ll='ls -alFG'
alias lt='ls -latr'
alias la='ls -AG'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias l='less -r'

# helper for _touch and touchall
__touch_date() {
  local d=$(date '+%Y%m%d%H%M.00')
  if [ "$1" != '-t' ]; then
    echo "$d"
    return
  fi
  local t=${2// /}; t=${t//-/} t=${t//:/}
  if [[ ! "$t" =~ ^[0-9]{0,12}$ ]]; then
    echo >&2 'Custom time must be all digits!'
    return 1
  fi
  if [ $((${#t} % 2)) -eq 1 ]; then
    echo >&2 'Even number of digits required!'
    return 1
  fi
  local n=$((12 - ${#t}))
  echo "${d:0:$n}$t.00"
}

# usage: _touch [-t time] <files...>
# -t: digits in multiples of 2 replacing right-most
#     digits of current time in yyyyMMddHHmm format
_touch() {
  local d; d=$(__touch_date "$@") || return
  [ "$1" == '-t' ] && shift 2
  touch -cht "$d" "$@"
}
alias t='_touch '
alias t0='t -t 00'

# recursively touch files & directories
# usage: touchall [-d] [-t time] [path]
# -d: touch directories only
# -t: digits in multiples of 2 replacing right-most
#     digits of current time in yyyyMMddHHmm format
touchall() {
  local d fargs=()
  if [ "$1" == '-d' ]; then
    fargs=(-type d); shift
  fi
  d=$(__touch_date "$@") || return
  [ "$d" ] && shift 2
  find "${@:-.}" "${fargs[@]}" -exec touch -cht "$d" "{}" \;
}
alias ta='touchall '
alias ta0='ta -t 00'
alias tad='ta -d '
alias tad0='tad -t 00'

syncdate() {
  local date=$(curl -sD - google.com|grep ^Date:|cut -d' ' -f3-6)
  date -s "${date}Z"
}

# parse_xe_output [--use-quotes] [param1 param2 ...]
# e.g. xe vm-list | parse_xe_output uuid name-label
# param values of each object, each quoted if --use-quotes specified,
# are output space-separated on the same line in the order specified
parse_xe_output() {
  local line found params values i j q
  if [ "$1" == --use-quotes ]; then
     q='"'
     shift
  fi
  # just return uuids if no
  # params explicitly given
  [ "$1" ] || set -- uuid

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*$ ]]; then
      found= # end of item
      continue
    fi
    if [ ! "$found" ]; then
      # locate first param with no left padding
      [[ "$line" =~ ^[[:alnum:]] ]] || continue
      found=1 output= params=() values=()
    fi
    # param name always in kebab case and value always after colon
    [[ "$line" =~ ^[[:space:]]*([-a-z]+)[^:]+:(.+)$ ]] || continue

    if [[ " $* " == *" ${BASH_REMATCH[1]} "* ]]; then
      # only collect wanted params
      params+=("${BASH_REMATCH[1]}")
      values+=("${BASH_REMATCH[2]}")
    fi
    # stop after wanted params collected
    [ ${#params[@]} -ge $# ] || continue

    # output values in given order
    for ((i = 1; i <= $#; i++)); do
      # find value in params in parsed order
      for ((j = 0; j < ${#params[@]}; j++)); do
        if [ "${params[$j]}" == "${!i}" ]; then
          output+=" $q$(echo ${values[$j]})$q"
          break
        fi
      done
    done
    echo $output # no quotes to trim spaces
    found= # skip remaining params of object
  done
}

# parses tags CSV into key value lines
# e.g. xe vm-list params=tags,uuid | parse_xe_output tags uuid
#      echo "greeting=hello world, foo-bar=baz" | parse_xe_tags
# greeting hello world
# foo-bar baz
parse_xe_tags() {
  sed -E 's/([^=]+)=([^,]+)(, )?/\1 \2\n/g'
}

# export_xe_vars "<xe-command>" <p:value-param|t:value-tag> <var-tag> <var-prefix>
# e.g. export_xe_vars "vm-list is-control-domain=false" p:name-label host-name name
#      export_xe_vars "vm-list is-control-domain=false" t:backup-dir host-name path
#      export NAME_XO="Xen Orchestra (xo)"
#      export PATH_XO="Xen Orchestra"
export_xe_vars() {
  local line tags var value
  while read -r line; do
    eval "line=($line)"

    # parse CSV into key value lines
    tags=$(parse_xe_tags <<< "$line")

    var=($(grep -P '^'${3,,}'\s' <<< "$tags"))
    [ "$var" ] || continue # ignore if untagged

    # sanitize tag and make it uppercase
    var="${var[@]:1}"; var="${var// /_}"

    if [[ "$2" == p:* ]]; then
      value="${line[1]}"
    else
      value=($(grep -P ${2/#t:/^}'\s' <<< "$tags"))
      value="${value[*]:1}"
    fi
    eval "export ${4:+${4^^}_}${var^^}=\"$value\""
  done < <( # outputs lines with quoted value(s) on each
    params=tags; [[ "$2" == p:* ]] && params+=${2/#p:/,}
    xe $1 params=$params | parse_xe_output --use-quotes ${params//,/ }
  )
}

# export UUID_* NAME_* PATH_* environment vars
# verify: env | sort | egrep '(UUID|NAME|PATH)_'
export_xe_vars "vm-list is-control-domain=false" t:backup-dir host-name path
export_xe_vars "vm-list is-control-domain=false" p:name-label host-name name
export_xe_vars "vm-list is-control-domain=false" p:uuid       host-name uuid
export_xe_vars "sr-list type=iso"                p:uuid       host uuid_isos

alias listvms='xe vm-list is-control-domain=false'
alias listsrs='xe sr-list'

refreshisos() {
  local uuid UUIDS=($(
    env | grep UUID_ISOS | \
      sed -E 's/^.+=//'
  ))
  for uuid in ${UUIDS[@]}; do
    xe sr-scan uuid=$uuid
  done
}

stopvm() {
  [ -n "$2" ] && echo "Stopping $2..."
  xe vm-shutdown uuid=$1
}
startvm() {
  [ -n "$2" ] && echo "Starting $2..."
  xe vm-start uuid=$1
}

suspendvm() {
  [ -n "$2" ] && echo "Suspending $2..."
  xe vm-suspend uuid=$1
}
resumevm() {
  [ -n "$2" ] && echo "Resuming $2..."
  xe vm-resume uuid=$1
}

# exportvm <uuid> <rel-path>
# e.g. exportvm $UUID_XO "$PATH_XO/$NAME_XO"
exportvm() {
  local path="/root/backups/$2 $(date "+%Y-%m-%d").xva"
  xe vm-export uuid=$1 filename="$path"
  chown 30002:30003 "$path"
  chmod 666         "$path"
}

alias        startxo='startvm $UUID_XO        "$NAME_XO"'
alias       startxoa='startvm $UUID_XOA       "$NAME_XOA"'
alias    startcosmos='startvm $UUID_COSMOS    "$NAME_COSMOS"'
alias   startrainier='startvm $UUID_RAINIER   "$NAME_RAINIER"'
alias startminecraft='startvm $UUID_MINECRAFT "$NAME_MINECRAFT"'
alias       startvms='startxo; startxoa; startrainier; startcosmos'
alias        backupxo='exportvm $UUID_XO        "$PATH_XO/$NAME_XO"'
alias       backupxoa='exportvm $UUID_XOA       "$PATH_XOA/$NAME_XOA"'
alias    backupcosmos='exportvm $UUID_COSMOS    "$PATH_COSMOS/$NAME_COSMOS"'
alias   backuprainier='exportvm $UUID_RAINIER   "$PATH_RAINIER/$NAME_RAINIER"'
alias backupminecraft='exportvm $UUID_MINECRAFT "$PATH_MINECRAFT/$NAME_MINECRAFT"'
alias        stopxo='stopvm $UUID_XO        "$NAME_XO"'
alias       stopxoa='stopvm $UUID_XOA       "$NAME_XOA"'
alias    stopcosmos='stopvm $UUID_COSMOS    "$NAME_COSMOS"'
alias   stoprainier='stopvm $UUID_RAINIER   "$NAME_RAINIER"'
alias stopminecraft='stopvm $UUID_MINECRAFT "$NAME_MINECRAFT"'
