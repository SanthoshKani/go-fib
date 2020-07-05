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

DOCKER_SYSCONFIG="/etc/sysconfig/docker"
if [ ! -f $DOCKER_SYSCONFIG ]; then
  logger -t oes-insights "Docker not configured. Exiting...\n"
  exit 1;
fi

DOC_OPTS=`grep "^DOCKER_OPTS" $DOCKER_SYSCONFIG`
if [ $? -ne 0 ]; then
  echo "DOCKER_OPTS=\"--iptables=false\"" >> $DOCKER_SYSCONFIG
  logger -t oes-insights "DOCKER_OPTS iptables entry not found, added iptables entry."
else
  #DOCKER_OPTS found. checking for iptables options
  echo $DOC_OPTS | grep '\-\-iptables=' > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    #iptables option not found so append to the existing options."
    NEW_DOC_OPTS=`echo $DOC_OPTS | sed  's/\(.*\)"$/\1 --iptables=false"/'`
  fi

  echo $DOC_OPTS | grep "\-\-iptables=false" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    #Already false. No change required.
    exit 0;
  fi
  echo $DOC_OPTS | grep "\-\-iptables=true" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    #iptables option was true. changinf it to false.
    NEW_DOC_OPTS=`echo $DOC_OPTS | sed  's/\(--iptables=\)true/\1false/'`
  fi
  #Updating the options to config file
  sed -i "s/\(^DOCKER_OPTS=\).*$/$NEW_DOC_OPTS/" $DOCKER_SYSCONFIG
  if [ $? -ne 0 ]; then
    logger -t oes-insights "Failed to update docker options."
    exit 1;
  fi
fi

systemctl restart docker > /dev/null 2>&1
if [ $? -ne 0 ]; then
  logger -t oes-insights "Failed to restart docker daemon."
  exit 1;
fi

systemctl status docker > /dev/null 2>&1
if [ $? -ne 0 ]; then
  systemctl start docker > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    logger -t oes-insights "Failed to start docker daemon."
    exit 1
  fi
fi

docker network inspect -f "{{(index (.IPAM.Config) 0).Subnet}}" oes-net > /dev/null 2>&1
if [ $? -ne 0 ]; then
  docker network create --driver=bridge --subnet=192.168.0.0/16 --gateway=192.168.0.1 --opt "com.docker.network.bridge.enable_icc=true" --opt "com.docker.network.bridge.enable_ip_masquerade=false" --opt "com.docker.network.bridge.name=oes0" --opt "com.docker.network.bridge.enable_ip_masquerade=false" --opt "com.docker.network.bridge.host_binding_ipv4=192.168.0.1" oes-net
  if [ $? -ne 0 ]; then
    logger -t oes-insights "Docker network create failed.\n"
    exit 1
  fi
fi

