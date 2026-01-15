# if cloud-init/autoinstall crashes,
# run at the installer shell prompt:

# scp admin@pacific:debug.sh .
# . debug.sh # this file!

putlog() {
  local file=$(basename ${2:-$1});    echo $file
  sshpass -p $SSHPASS scp $1 admin@pacific:$file
}

putlogs() {
  putlog /var/crash/*.crash crash.log
  putlog /var/log/syslog   syslog.log
  putlog /var/log/cloud-init.log
  putlog /var/log/cloud-init-output.log
  {      cloud-init status --long; echo
         cloud-init analyze  show
  } &>   cloud-init-status.log
  putlog cloud-init-status.log
  putlog /var/log/installer/subiquity-server-debug.log
  putlog /var/log/installer/subiquity-client-debug.log
  dpkg -l > dpkg-list.log
  putlog    dpkg-list.log
  ip a > networking.log
  putlog networking.log
}

command -v cloud-init &>/dev/null && {
  apt-get install -yqq sshpass
  SSHPASS=secret putlogs
}

# then run getlogs at the local IDE end:

getlog() { scp pacific:$1 .; ssh pacific rm $1; }

getlogs() {
  getlog crash.log
  getlog syslog.log
  getlog cloud-init.log
  getlog cloud-init-output.log
  getlog cloud-init-status.log
  getlog subiquity-server-debug.log
  getlog subiquity-client-debug.log
  getlog dpkg-list.log
  getlog networking.log
}
