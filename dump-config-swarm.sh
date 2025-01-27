#!/bin/bash

RED="\e[31m"
GREEN="\e[32m"
PURPLE="\e[35m"
ENDCOLOR="\e[0m"


echo "Storage node: "
read STORAGE

CONFIG=$(/root/dist/swarmctl -d ${STORAGE} -Q healthreport | grep -Ev '^Node|^Consider' | jq -r '."SNMP tables"."Config Variables Table"')

INDEX=$(echo $CONFIG|jq '."1 - Index"|length')




for I in $(seq 0 $INDEX)
do
        NAME=$(echo $CONFIG|jq '."2 - Variable name"['$I']')
        SOURCE=$(echo $CONFIG|jq '."5 - Value source"['$I']')
        VALUE=$(echo $CONFIG|jq '."3 - Variable value"['$I']')
        DEFAULT=$(echo $CONFIG|jq '."4 - Default value"['$I']')

        echo -e "${GREEN}${NAME}"
        if [[ ${VALUE} != "$DEFAULT" ]] ; then
                COLOR=$RED
        else
                COLOR=$GREEN
        fi
        echo -e "\t{COLOR}Source  \t$$SOURCE"
        echo -e "\tValue   \t${VALUE}"
        echo -e "\tDefault \t${DEFAULT}"
echo -e "${PURPLE}-------------------------------------------------------------${ENDCOLOR}"
done
