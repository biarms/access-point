#!/usr/bin/env sh
# Inspired from https://gitlab.com/hartek/autowlan/-/blob/master/confs/start.sh

NOCOLOR='\033[0m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'

sigterm_handler () {
  echo -e "${CYAN}[*] Caught SIGTERM/SIGINT!${NOCOLOR}"
  pkill hostapd
  cleanup
  exit 0
}

cleanup () {
  echo -e "${CYAN}[*] Deleting iptables rules...${NOCOLOR}"
  sh /scripts/iptables_off.sh || echo -e "${RED}[-] Error deleting iptables rules${NOCOLOR}"
  echo -e "${CYAN}[*] Restarting network interface...${NOCOLOR}"
  ifdown wlan0
  ifup wlan0
  echo -e "${GREEN}[+] Successfully exited, bye! ${NOCOLOR}"
}

start () {
  echo -e "${CYAN}[*] Setting wlan0 settings${NOCOLOR}"
  ifdown wlan0 || true
  ifup wlan0 || true

  trap 'sigterm_handler' TERM INT
  echo -e "${CYAN}[*] Creating iptables rules${NOCOLOR}"
  sh /scripts/iptables_on.sh || echo -e "${RED}[-] Error creating iptables rules${NOCOLOR}"

  echo -e "${CYAN}[+] Configuration successful! Services will start now${NOCOLOR}"
  dhcpd -4 -f -d wlan0 &
  hostapd /etc/hostapd/hostapd.conf &
  pid=$!
  wait $pid

  cleanup
}

function main () {
    # From https://github.com/progrium/bashstyle
    set -eo pipefail
    [[ "$TRACE" ]] && set -x
    if [[ "$1" == "" ]]; then
      start
    else
      $@
    fi
}

main "$@"
