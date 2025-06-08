# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC1091 # Not following: not input file
# shellcheck disable=SC2086 # Double quote prevent globbing
# shellcheck disable=SC2089 # Quote and \ treated literally
# shellcheck disable=SC2155 # Declare and assign separately
# shellcheck disable=SC2128 # Expanding array without index
# shellcheck disable=SC2178 # Variable was used as an array
# shellcheck disable=SC2179 # Use array+=("item") to append
# shellcheck disable=SC2207 # Prefer mapfile to split output

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

# ip output in color
alias ip='ip -c=auto'

# parse_xe_output [--quote] [param1 param2 ...]
# e.g. xe vm-list | parse_xe_output uuid name-label
# param values of each object, each quoted if --quote specified,
# are output space-separated on the same line in specified order
parse_xe_output() {
  local line found params values i j q
  if [ "$1" == --quote ]; then
     q="'"
     shift
  fi
  # just return uuids if no
  # params explicitly given
  [ "$1" ] || set -- uuid

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*$ ]]; then
      found="" # end of item
      continue
    fi
    if [ ! "$found" ]; then
      # locate first param with no left padding
      [[ "$line" =~ ^[[:alnum:]] ]] || continue
      found=1 output="" params=() values=()
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

          # trim leading whitespace from value
          local str="${values[$j]%%[![:space:]]*}"
          str="${values[$j]#"$str"}"

          if [ "$q" ]; then
            # escape single quotes, then
            # single quote entire string
            str="'${str//\'/\'\"\'\"\'}'"
          fi
          output+=" $str"
          break
        fi
      done
    done

    # shellcheck disable=SC2090
    echo $output # no quotes to trim spaces
    found="" # skip remaining object params
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

# export_xe_vars "<xe-command>" <p:value-param|t:value-tag> <p:var-param|t:var-tag> <var-prefix>
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

    # ignore duplicated VMs tagged by continuous replication
    grep -qi 'Continuous Replication' <<< "$tags" && continue

    if [[ "$3" == p:* ]]; then
      # variable name from param
      # line[0] contains all tags
      # name is always the last
      var="${line[-1]}"
      var="${var//-/_}"

    else # variable name from tag
      var=($(grep -Pi ${3/#t:/^}'\s' <<< "$tags"))
      [ "$var" ] || continue # ignore if untagged
      var="${var[*]:1}" # sanitize
      var="${var// /_}"
    fi

    if [[ "$2" == p:* ]]; then
      # variabe value from param
      # line[0] contains all tags
      # value is always the second
      value="${line[1]}"

    else # variabe value from tag
      value=($(grep -Pi ${2/#t:/^}'\s' <<< "$tags"))
      value="${value[*]:1}"
    fi

    eval "export ${4:+${4^^}_}${var^^}=\"$value\""
  done < <(
    params=tags
    [[ "$2" == p:* ]] && params+=${2/#p:/,} #    value param
    [[ "$3" == p:* ]] && params+=${3/#p:/,} # variable param
    # outputs lines with quoted values
    xe $1 params=$params | \
      parse_xe_output --quote ${params//,/ }
  )
}

# since it's not so easy from the CLI to determine
# which host a VM is running on, export HOST_* vars
# for all VMs set to the names of the XCP-ng hosts
export_host_vars() {
  local uuids
  # lines with VM/host name (in lower case) and UUID
  uuids=$(env | grep -E '^UUID_' | grep -v _ISOS_ | \
    sed -En 's/^UUID_(HOST_)?(.+)=(.+)$/\L\2 \3/p')

  local vm_uuid host_uuid
  local vm_name host_name
  while read -r vm_uuid host_uuid; do
      vm_name=($(grep   $vm_uuid <<< "$uuids"))
    host_name=($(grep $host_uuid <<< "$uuids"))

    eval "export HOST_${vm_name^^}=$host_name"
  done < <(
    xe vm-list is-control-domain=false power-state=running \
       params=uuid,resident-on | parse_xe_output uuid resident-on
  )
}

# NOTE: "host-name" and "backup-dir" are
# CUSTOM TAGS manually added to all VMs

# export UUID_* NAME_* PATH_* HOST_* environment vars
# verify: env | sort | grep -E '^(UUID|NAME|PATH|HOST)_'
export_xe_vars host-list                                              p:uuid       p:name-label UUID_HOST
export_xe_vars  "sr-list type=iso   shared=false"                     p:uuid       p:host       UUID_ISOS
export_xe_vars  "vm-list is-control-domain=false is-a-snapshot=false" p:uuid       t:host-name  UUID
export_xe_vars  "vm-list is-control-domain=false is-a-snapshot=false" p:name-label t:host-name  NAME
export_xe_vars  "vm-list is-control-domain=false is-a-snapshot=false" t:backup-dir t:host-name  PATH
export_host_vars # requires vars exported above

alias listvms='xe vm-list is-control-domain=false is-a-snapshot=false'
alias listsrs='xe sr-list'

refreshisos() {
  local uuid UUIDS=($(
    env | grep UUID_ISOS | \
      sed -E 's/^.+=//'
  ))
  for uuid in "${UUIDS[@]}"; do
    xe sr-scan uuid="$uuid"
  done
}

# _snapshots [--delim='char'] [vm-uuid]
# e.g. _snapshots --delim='|' $UUID_XO
# outputs each snapshot containing
# space-separated fields in order:
# ISO date, SS UUID, VM UUID, host, description
_snapshots() {
  local params d=' ' line tags vmid uuid desc host date
  params="tags,uuid,name-description,snapshot-of,snapshot-time"

  if [[ "$1" == --delim=* ]]; then
    # use specified delimiter
    d="${1#--delim=}"; shift
  fi
  while read -r line; do
    eval "line=($line)"

    uuid="${line[1]}"
    desc="${line[2]}"
    vmid="${line[3]}"
    date="${line[4]}"

    # parse CSV into key value lines
    tags=$(parse_xe_tags <<< "$line")

    [[ "$vmid" == *"not in"* ]] && \
      vmid='00000000-0000-0000-0000-000000000000'
    host=($(grep -P '^host-name\s' <<< "$tags"))
    host="${host[*]:1}"
    host="${host:-_NA_}"
    # reformat raw date in "YYYYmmddTHH:MM:SSZ" format
    date="${date:0:4}-${date:4:2}-${date:6:2}${date:8}"

    echo "$date$d$uuid$d$vmid$d$host$d$desc"
  done < <( # outputs lines with quoted values
    [ "$1" ] && args="snapshot-of=$1"
    xe snapshot-list $args params=$params | \
      parse_xe_output --quote ${params//,/ }
  ) | sort
}

vmstate() {
  xe vm-list --minimal uuid="$1" params=power-state
}

stopvm() {
  [ -n "$2" ] && echo "Stopping $2..."
  xe vm-shutdown uuid="$1" "${@:3}" # --force
}
startvm() {
  [ -n "$2" ] && echo "Starting $2..."
  xe vm-start uuid="$1" "${@:3}"
}

suspendvm() {
  [ -n "$2" ] && echo "Suspending $2..."
  xe vm-suspend uuid="$1"
}
resumevm() {
  [ -n "$2" ] && echo "Resuming $2..."
  xe vm-resume uuid="$1"
}

# backupvm <uuid> <rel-path>
# e.g. backupvm $UUID_XO "$PATH_XO/$NAME_XO"
backupvm() {
  [ -L "$HOME/backups" ] || {
    echo >&2 'Path ~/backups/ not found!'
    return 1
  }
  local file="$HOME/backups/${2:-$1} $(date "+%Y-%m-%d").xva"
  local dir="$(dirname "$file")"
  [ -d "$dir" ] || {
    mkdir -p "$dir"
    _touch -t 00      "$dir/.."
    chown 30002:30003 "$dir"
    chmod 777         "$dir"
  }

  echo "Exporting: ${file/#$HOME/~}"
  xe vm-export uuid="$1" filename="$file"

  # UID 30002: FOURTEENERS\Erhhung
  # GID 30003: FOURTEENERS\Domain Users
  _touch -t 00      "$file" "$dir"
  chown 30002:30003 "$file"
  chmod 666         "$file"
}

_names() {
  xe vm-list is-control-domain=false \
             is-a-snapshot=false \
             params=tags | \
    sed -En 's/^.*host-name=([^,]+).*$/\1/p' | \
    sort | \
    uniq
}
make_aliases() {
  local name
  for name in $(_names); do
    eval "alias    stop$name='stopvm    \$UUID_${name^^} \"\$NAME_${name^^}\"'"
    eval "alias   start$name='startvm   \$UUID_${name^^} \"\$NAME_${name^^}\"'"
    eval "alias suspend$name='suspendvm \$UUID_${name^^} \"\$NAME_${name^^}\"'"
    eval "alias  resume$name='resumevm  \$UUID_${name^^} \"\$NAME_${name^^}\"'"
    eval "alias  backup$name='backupvm  \$UUID_${name^^} \"\$PATH_${name^^}/\$NAME_${name^^}\"'"
  done
}

make_aliases
alias startvms='startxoa; startxo; startrainier; startcosmos; startrancher'
