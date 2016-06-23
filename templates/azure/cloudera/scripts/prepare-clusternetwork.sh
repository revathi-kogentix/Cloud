#!/bin/bash

#Updates etc hosts based on predefined naming convention

HOSTIP=$1
WORKERIP=$2
NAMEPREFIX=$3
NAMESUFFIX=$4
NAMESUFFIX=`echo $NAMESUFFIX | sed 's/^[^.]*\.//'`

ADMINUSER=$5

execname=$0



function log {
  echo "$(date): [${execname}] $@" 
}

function updateEtcHosts {
    local LocalResolve=`host ${NAMEPREFIX}-mn0 | cut -d ' ' f1 | sed 's/^[^.]*\.//'`
    echo "$HOSTIP ${NAMEPREFIX}-mn0.$LocalResolve ${NAMEPREFIX}-mn0"
    local LocalResolveDataNode=`hostname -f | sed 's/^[^.]*\.//'`
    IFS=",";read -r -a ips <<< "$@"    
    i=0
    for ip in "${ips[@]}"
    do 
        echo  "$ip ${NAMEPREFIX}-dn$i.$LocalResolveDataNode ${NAMEPREFIX}-dn$i" 
        let "i = i + 1"
    done
}

function configureSSH {
    pFile='/var/lib/waagent/*.prv'
    mkdir /home/$ADMINUSER/.ssh
    chown $ADMINUSER /home/$ADMINUSER/.ssh
    chmod 700 /home/$ADMINUSER/.ssh

    ssh-keygen -y -f $pFile > /home/$ADMINUSER/.ssh/authorized_keys
    chown $ADMINUSER /home/$ADMINUSER/.ssh/authorized_keys
    chmod 600 /home/$ADMINUSER/.ssh/authorized_keys
    
    myhostname=`hostname`
    CheckMaster=`echo $myhostname | grep -o '^[^.]*-mn0\.' | grep -o '\-mn0.'`
    
    if [ "$CheckMaster" == "-mn0." ]
    then
        echo "# master configuration"
        openssl rsa -in $pFile -out /home/$ADMINUSER/.ssh/id_rsa
        chmod 600 /home/$ADMINUSER/.ssh/id_rsa
        chown $ADMINUSER /home/$ADMINUSER/.ssh/id_rsa
        
        fqdnstring=`python -c "import socket; print socket.getfqdn('$myhostname')"`
        sed -i "s/.*HOSTNAME.*/HOSTNAME=${fqdnstring}/g" /etc/sysconfig/network
    fi 
}

log "updating hosts with nodes ${WORKERIP}"
updateEtcHosts "${WORKERIP}" >> /etc/hosts

log "configuring SSH and setting fqdn on master"
configureSSH
#restart network

log "restarting network"
/etc/init.d/network restart
