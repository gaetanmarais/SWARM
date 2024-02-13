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

STORAGENODE="172.20.3.1"

#######################################
OLDSEGMENT="set:-"
RED='\033[0;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color



clear
read -p "IP d'un Storage node [${STORAGENODE}]? " SWARM
if [[ "${SWARM}" == "" ]]; then SWARM="${STORAGENODE}";fi


read -p "ETAG? " ETAG

rm -f /tmp/headers.* >/dev/null
rm -f /tmp/checkintegrity.* >/dev/null


curl -s -LI "http://${SWARM}/${ETAG}?countreps&verbose">/tmp/headers.$$



cat /tmp/headers.$$|egrep -E "Policy|MD5|Overlay|Content-Length|X-Object-Lock|Lifepoint|Castor-System-Path|Castor-System-Created|Castor-System-Previous-Version"|awk -v OFMT="%5.2f%%" -F":" '{
        if ($1=="Content-Length") {
                if ($2>1000000000) {print $1":"($2/1000/1000/1000)"Gb"}
                else if ($2>1000000) {print $1":"($2/1000/1000)"Mb"}
                else if ($2>1000) {print $1":"($2/1000)"kb"}
                else {print $1":"$2"b"}
        }
        else
                {print $0}
}'
NBSEG=$(cat /tmp/headers.$$|awk -F":" '/Policy-ECEncoding-Evaluated:/ {print $2+$3}')


if [[ $(cat /tmp/headers.$$|grep -c "Manifest: ec") -eq 1 ]]; then
curl -s -X GET -L "http://${SWARM}/${ETAG}?etag&checkintegrity">/tmp/checkintegrity.$$

echo "============================================================================================"
echo "Check Integrity"
i=0
j=$(cat /tmp/checkintegrity.$$|wc -l)


cat /tmp/checkintegrity.$$|while read LINE
do
i=$((i+1))

SEGMENT=$(echo ${LINE} |awk '{print $1}')
if [[ "${OLDSEGMENT}" != "${SEGMENT}" ]] ; then
        if [[ "${OLDSEGMENT}" != "set:-" ]]; then

        #       echo "${OLDSEGMENT} : ${SIZE} : ${NODES}"; fi
                SEGCOUNT=$(echo ${NODES}|wc -w)
                if [[ "${SEGCOUNT}" == "${NBSEG}" ]] ; then
                        echo -e "${GREEN}${OLDSEGMENT} : ${SIZE} : ${NODES}${NC}"
                else
                        echo -e "${RED}${OLDSEGMENT} : ${SIZE} : ${NODES}     segment(s) missing (${SEGCOUNT}/${NBSEG}) ${NC}"
                fi;

        fi;

        NODES=$(echo ${LINE} |awk '{print $5}'|awk -F":" '{print $2}')
        SIZE=$(echo ${LINE} |awk '{print $3}'|awk -F":" '{print $2}'|numfmt --to=si)
        OLDSEGMENT=${SEGMENT}
else
        NODES="${NODES} $(echo ${LINE} |awk '{print $5}'|awk -F":" '{print $2}')"
fi


if [[ "$i" == "$j" ]]; then
        SEGCOUNT=$(echo ${NODES}|wc -w)
        if [[ "${SEGCOUNT}" == "${NBSEG}" ]] ; then
                echo -e "${GREEN}${OLDSEGMENT} : ${SIZE} : ${NODES}${NC}"
        else
                echo -e "${RED}${OLDSEGMENT} : ${SIZE} : ${NODES}     segment(s) missing (${SEGCOUNT}/${NBSEG}) ${NC}"
        fi;
fi;
done


fi
