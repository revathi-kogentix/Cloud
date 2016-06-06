#!/bin/bash
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# 
# See the License for the specific language governing permissions and
# limitations under the License.
# Usage: bootstrap-cloudera-1.0.sh {clusterName} {managment_node} {cluster_nodes} {isHA} {sshUserName} [{sshPassword}]

# Put the command line parameters into named variables
MASTERIP=$1
WORKERIP=$2
NAMEPREFIX=$3
NAMESUFFIX=$4
MASTERNODES=$5
DATANODES=$6
ADMINUSER=$7
HA=$8
PASSWORD=${9}
CMUSER=${10}
CMPASSWORD=${11}
EMAILADDRESS=${12}
BUSINESSPHONE=${13}
FIRSTNAME=${14}
LASTNAME=${15}
JOBROLE=${16}
JOBFUNCTION=${17}
COMPANY=${18}
INSTALLCDH=${19}
VMSIZE=${20}

CLUSTERNAME=$NAMEPREFIX

execname=$0


log() {
  echo "$(date): [${execname}] $@" 
}

log "my vmsize: $VMSIZE"
# Converts a domain like machine.domain.com to domain.com by removing the machine name
NAMESUFFIX=`echo $NAMESUFFIX | sed 's/^[^.]*\.//'`

log "master ip: $MASTERIP"
HOSTIP=${MASTERIP}
ManagementNode="$HOSTIP:${NAMEPREFIX}-mn0.$NAMESUFFIX:${NAMEPREFIX}-mn0"

mip=${MASTERIP}

log "set private key"
#use the key from the key vault as the SSH private key
openssl rsa -in /var/lib/waagent/*.prv -out /home/$ADMINUSER/.ssh/id_rsa
chmod 600 /home/$ADMINUSER/.ssh/id_rsa
chown $ADMINUSER /home/$ADMINUSER/.ssh/id_rsa

file="/home/$ADMINUSER/.ssh/id_rsa"
key="/tmp/id_rsa.pem"
openssl rsa -in $file -outform PEM > $key

#Set etc hosts for each IP address
#updateEtcHosts "${MASTERIP}"
IFS=",";read -r -a ips <<< "${WORKERIP}"
echo "$HOSTIP ${NAMEPREFIX}-mn0.$NAMESUFFIX ${NAMEPREFIX}-mn0" >> /etc/hosts
let "dataNodesCount = ${#ips[@]} - 1"
for i in (seq 0 ${dataNodesCount}){
            echo "${ips[$i]} ${NAMEPREFIX}-dn$i.$NAMESUFFIX ${NAMEPREFIX}-dn$i" >> /etc/hosts
}

function updateEtcHosts { 
    IFS=",";read -r -a ips <<< "$@"
    for ip in "${ips[@]}"
    do
        ssh "$ip" << 'ENDSSH'
        echo "$HOSTIP ${NAMEPREFIX}-mn0.$NAMESUFFIX ${NAMEPREFIX}-mn0" >> /etc/hosts
        let "dataNodesCount = ${#ips[@]} - 1"
        for i in (seq 0 ${dataNodesCount}){
            echo "${ips[$i]} ${NAMEPREFIX}-dn$i.$NAMESUFFIX ${NAMEPREFIX}-dn$i" >> /etc/hosts
        }
        ENDSSH
    done
}

updateEtcHosts "${WORKERIP}"


#Use IP Addresses for the cloudera setup, as porvided via input parameter
worker_ip=${WORKERIP}
log "Worker ip to be supplied to next script: $worker_ip"
log "BEGIN: Starting detached script to finalize initialization"
if [ "$INSTALLCDH" == "True" ]
then
  sh initialize-cloudera-server.sh "$CLUSTERNAME" "$key" "$mip" "$worker_ip" "$HA" "$ADMINUSER" "$PASSWORD" "$CMUSER" "$CMPASSWORD" "$EMAILADDRESS" "$BUSINESSPHONE" "$FIRSTNAME" "$LASTNAME" "$JOBROLE" "$JOBFUNCTION" "$COMPANY" "$VMSIZE">/dev/null 2>&1
fi
log "END: Detached script to finalize initialization running. PID: $!"

