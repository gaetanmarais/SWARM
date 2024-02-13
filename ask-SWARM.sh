#!/bin/bash
##
##  Author  : Gaetan MARAIS - DataCore
##  Date    : April 6th 2022
##  Version : 1.0
##
##  Subject : This script will be used to understand how an object is stored in SWARM object storage
##            Need to be executed from server that is connected to storage node internal network
##
##
##############################################################################################################
##############################################################################################################




##############################################################################################################
##############################################################################################################
##
##    VARIABLES


OLDSEGMENT="set:-"

##
##
##############################################################################################################
##############################################################################################################
clear
read -p "IP d'un Storage node [172.20.3.1]? " SWARM
if [[ "${SWARM}" == "" ]]; then SWARM="172.20.3.1";fi

read -p "Nom du domaine [production.swarm.datacore.paris]? " DOMAIN
if [[ "${DOMAIN}" == "" ]]; then DOMAIN="production.swarm.datacore.paris";fi


read -p "Nom du bucket [gmarais]? " BUCKET
if [[ "${BUCKET}" == "" ]]; then BUCKET="gmarais";fi


read -p "Nom de l'objet? " OBJECT

rm -f /tmp/headers.* >/dev/null
rm -f /tmp/checkintegrity.* >/dev/null


###echo "curl -LI ""http://${SWARM}/${BUCKET}/${OBJECT}?domain=${DOMAIN}&countreps&verbose"""
curl -s -LI "http://${SWARM}/${BUCKET}/${OBJECT}?domain=${DOMAIN}&countreps&verbose">/tmp/headers.$$
cat /tmp/headers.$$|egrep -E "Policy|MD5|Overlay|Content-Length|X-Object-Lock|Lifepoint"|awk -F":" '{
        if ($1=="Content-Length") {
                if ($2>1000000000) {print $1":"int($2/1000/1000/1000)"Gb"}
                else if ($2>1000000) {print $1":"int($2/1000/1000)"Mb"}
                else if ($2>1000) {print $1":"int($2/1000)"kb"}
                else {print $1":"$2"b"}
        }
        else
                {print $0}
}'



if [[ $(cat /tmp/headers.$$|grep -c "Manifest: ec") -eq 1 ]]; then
###echo "curl -s -X GET -L ""http://${SWARM}/${BUCKET}/${OBJECT}?domain=${DOMAIN}&checkintegrity"""
curl -s -X GET -L "http://${SWARM}/${BUCKET}/${OBJECT}?domain=${DOMAIN}&checkintegrity">/tmp/checkintegrity.$$

echo "Check Integrity"
i=0
j=$(cat /tmp/checkintegrity.$$|wc -l)


cat /tmp/checkintegrity.$$|while read LINE
do
i=$((i+1))

SEGMENT=$(echo ${LINE} |awk '{print $1}')
if [[ "${OLDSEGMENT}" != "${SEGMENT}" ]] ; then
        if [[ "${OLDSEGMENT}" != "set:-" ]]; then echo "${OLDSEGMENT} : ${SIZE} : ${NODES}"; fi
        NODES=$(echo ${LINE} |awk '{print $5}'|awk -F":" '{print $2}')
        SIZE=$(echo ${LINE} |awk '{print $3}'|awk -F":" '{print $2}'|numfmt --to=si)
        OLDSEGMENT=${SEGMENT}
else
        NODES="${NODES} $(echo ${LINE} |awk '{print $5}'|awk -F":" '{print $2}')"
fi
if [[ "$i" == "$j" ]]; then echo "${OLDSEGMENT} : ${SIZE} : ${NODES}"; fi
done


fi
