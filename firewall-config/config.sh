#!/bin/bash
# © Copyright [2020] Micro Focus or one of its affiliates.
#
# The only warranties for products and services of Micro Focus and its affiliates and licensors
# (“Micro Focus”) are as may be set forth in the express warranty statements accompanying such
# products and services. Nothing herein should be construed as constituting an additional
# warranty. Micro Focus shall not be liable for technical or editorial errors or omissions
# contained herein. The information contained herein is subject to change without notice.
#
# Except as specifically indicated otherwise, this document contains confidential information
# and a valid license is required for possession, use or copying. If this work is provided to the
# U.S. Government, consistent with FAR 12.211 and 12.212, Commercial Computer Software,
# Computer Software Documentation, and Technical Data for Commercial Items are licensed
# to the U.S. Government under vendor's standard commercial license.

usage(){
cat << EOF
firewall config utility

Usage: firewall_config.sh [OPTIONS] 

GENERAL OPTIONS (OPTIONS):
  -i, --init            Initialize the firewall configuration.
  -o, --open <port>     Opens the port in firewall.
  -c, --close <port>    Closes the port in firewall.
  -h, --help            Displays the help information.

EOF
}

precheck(){

  systemctl status SuSEfirewall2 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    systemctl start SuSEfirewall2 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      logger -t oes-insights "Failed to start SuSEfirewall2 daemon."
      exit 1
    fi
  fi
}

prepare(){
  # perform pre-checks  
  precheck

  # prepare the firewall configurations
  RESTART_REQUIRED="no"

  grep "^FW_ROUTE=\"yes\"" /etc/sysconfig/SuSEfirewall2
  if [ $? -ne 0 ]; then
    sed -i -e"s/^FW_ROUTE=.*/FW_ROUTE=\"yes\"/" /etc/sysconfig/SuSEfirewall2
    RESTART_REQUIRED="yes"
  fi

  grep "^FW_MASQUERADE=\"yes\"" /etc/sysconfig/SuSEfirewall2
  if [ $? -ne 0 ]; then
    sed -i -e"s/^FW_MASQUERADE=.*/FW_MASQUERADE=\"yes\"/" /etc/sysconfig/SuSEfirewall2
    RESTART_REQUIRED="yes"
  fi
  
  #grep "^FW_DEV_INT=" /etc/sysconfig/SuSEfirewall2 | cut -d'=' -f2 | xargs
  grep "^FW_DEV_INT=" /etc/sysconfig/SuSEfirewall2
  if [ $? -eq 0 ]; then
    FW_DEV_INT_STR=$(grep "^FW_DEV_INT=" /etc/sysconfig/SuSEfirewall2 | cut -d'=' -f2 | xargs)
    if [ "$FW_DEV_INT_STR" == "" ]; then
      sed -i -e"s/^FW_DEV_INT=.*/FW_DEV_INT=\"docker0 oes0\"/" /etc/sysconfig/SuSEfirewall2
      RESTART_REQUIRED="yes"
    fi
  fi

  if { [ "$RESTART_REQUIRED" == "yes" ]; };then
    systemctl restart SuSEfirewall2 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      logger -t oes-insights "Failed to start SuSEfirewall2 daemon."
      exit 1
    fi
  fi
}

open_port(){
  # perform pre-checks  
  precheck
  
  # open the port
  yast2 firewall services add tcpport=$1 zone=EXT
}

close_port(){
  # perform pre-checks  
  precheck

  # open the port
  yast2 firewall services remove tcpport=$1 zone=EXT
}

# Entry Point
if [ "$1" == "" ]; then
  usage
  exit 1
fi

while [ "$1" != "" ]; do
  case $1 in
    --help )  usage
              exit 0
              ;;
    --init)   prepare
              exit $?
              ;;
    --open)   shift   
              open_port $1
              exit $?
              ;;
    --close)  shift
              close_port $1
              exit $?
              ;;
    * )       usage
              exit 1
              ;;
  esac
  shift
done
