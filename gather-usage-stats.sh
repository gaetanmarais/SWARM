#!/bin/bash

#Variables
############################
USER="dcsadmin@"
PASSWD="Mypassword"
GATEWAY="10.12.105.33"
ADMINPORT="91"


############################
CMD="curl -s -k -L -u ${USER}:${PASSWD}"
ADMINURL="https://${GATEWAY}:${ADMINPORT}"
NODESURL="/api/storage/nodes"
GB=1073741824
############################




#######  #     #  #     #   #####   #######  ###  #######  #     #
#        #     #  ##    #  #     #     #      #   #     #  ##    #
#        #     #  # #   #  #           #      #   #     #  # #   #
#####    #     #  #  #  #  #           #      #   #     #  #  #  #
#        #     #  #   # #  #           #      #   #     #  #   # #
#        #     #  #    ##  #     #     #      #   #     #  #    ##
#         #####   #     #   #####      #     ###  #######  #     #


function printtable {

        LINE=$(echo ${EXTLINE}|sed "s/___/ /g"|sed "s/},$/}/")
        if [[ "${LINE}" != "[" ]] && [[ "${LINE}" != "]" ]]; then
        if [[ "${LINE}" = "" ]] ;then
                echo "Domain empty or without protection (EC/RF/VERSIONING/LOCKING) customization"
        else
                NAME=$(echo ${LINE}|jq .name|sed "s/\"//g")
                EC=$(echo ${LINE}|jq .policy_ecencoding|sed "s/\"//g")
                RF=$(echo ${LINE}|jq .policy_replicas|sed "s/\"//g"|awk '{print $2}')
                LOCK=$(echo ${LINE}|jq .x_object_lock_meta_status|sed "s/\"//g")
                LOCKRET=$(echo ${LINE}|jq .x_object_lock_meta_default|sed "s/\"//g")
                VERSIONING=$(echo ${LINE}|jq .policy_versioning|sed "s/\"//g")
                QUOTABAND=$(echo ${LINE}|jq .x_caringo_meta_quota_bandwidth_limit|sed "s/\"//g")
                QUOTASTO=$(echo ${LINE}|jq .x_caringo_meta_quota_storage_limit|sed "s/\"//g")
                printf "%-35s %-10s %-15s %-10s %-10s %-25s %-25s %-25s\n" "   $NAME" "$EC" "$RF" "$VERSIONING" "$LOCK" "$LOCKRET" "$QUOTABAND" "$QUOTASTO"
         fi
         fi




}

 #####    #####   ######   ###  ######   #######
#     #  #     #  #     #   #   #     #     #
#        #        #     #   #   #     #     #
 #####   #        ######    #   ######      #
      #  #        #   #     #   #           #
#     #  #     #  #    #    #   #           #
 #####    #####   #     #  ###  #           #


clear

if [[ $(which banner) ]] ; then
        banner "Objects protections"
else
        echo "Object protections"
fi


#Collect tenants

for TENANT in $(${CMD} http://${GATEWAY}/_admin/manage/tenants/?format=json |jq .[].name|sed "s/\"//g")
do
        printf "#%.0s" {1..155}
        echo -e "\n# ${TENANT}"
        TENANTURL="/_admin/manage/tenants/${TENANT}/"

        for EXTLINE in $(${CMD} "http://${GATEWAY}/_admin/manage/tenants/${TENANT}?format=json&fields=name,policy_ecencoding,policy_replicas,policy_versioning,x_object_lock_meta_status,x_object_lock_meta_default,x_caringo_meta_quota_bandwidth_limit,x_caringo_meta_quota_storage_limit"|sed "s/ /___/g")
        do
                type="TENANT"
                printtable
                let SIZEGB=$(curl -s -L -u ${USER}:${PASSWD} http://${GATEWAY}${TENANTURL}meter/usage/bytesSize/current?format=json|jq .[].bytesSize)/${GB}
                let STOREGB=$(curl -s -L -u ${USER}:${PASSWD} http://${GATEWAY}${TENANTURL}meter/usage/bytesStored/current?format=json|jq .[].bytesStored)/${GB}
                echo "Storage usage : ${SIZEGB}GB / ${STOREGB}GB"

        done



#browse all domain for this tenant
        for DOMAIN in $(${CMD} http://${GATEWAY}/_admin/manage/tenants/${TENANT}/domains/?format=json |jq .[].name|sed "s/\"//g"| sort)
        do
                echo -e "\n"
                printf "%-35s %-10s %-15s %-10s %-10s %-25s %-25s %-25s\n" "Domain" "EC.Factor" "R.Factor" "Versioning" "S3Locking" "LockingRetention" "QuotaBandwidth" "QuotaStorage"




                LINE=$(${CMD} "http://${GATEWAY}?domains&format=json&fields=name,policy_ecencoding,policy_replicas,policy_versioning,x_object_lock_meta_status,x_object_lock_meta_default,x_caringo_meta_quota_bandwidth_limit,x_caringo_meta_quota_storage_limit"|jq '.[]|select(.name == '\"${DOMAIN}\"') | . ')

                NAME=$(echo ${LINE}|jq .name|sed "s/\"//g")
                EC=$(echo ${LINE}|jq .policy_ecencoding|sed "s/\"//g")
                RF=$(echo ${LINE}|jq .policy_replicas|sed "s/\"//g"|awk '{print $2}')
                LOCK=$(echo ${LINE}|jq .x_object_lock_meta_status|sed "s/\"//g")
                LOCKRET=$(echo ${LINE}|jq .x_object_lock_meta_default|sed "s/\"//g")
                VERSIONING=$(echo ${LINE}|jq .policy_versioning|sed "s/\"//g")
                QUOTABAND=$(echo ${LINE}|jq .x_caringo_meta_quota_bandwidth_limit|sed "s/\"//g")
                QUOTASTO=$(echo ${LINE}|jq .x_caringo_meta_quota_storage_limit|sed "s/\"//g")

                let SIZEGB=$(curl -s -L -u ${USER}:${PASSWD} http://${GATEWAY}${TENANTURL}domains/${DOMAIN}/meter/usage/bytesSize/current?format=json|jq .[].bytesSize)/${GB}
                let STOREGB=$(curl -s -L -u ${USER}:${PASSWD} http://${GATEWAY}${TENANTURL}domains/${DOMAIN}/meter/usage/bytesStored/current?format=json|jq .[].bytesStored)/${GB}

                printf "%-35s %-10s %-15s %-10s %-10s %-25s %-25s %-25s\n" "$NAME" "$EC" "$RF" "$VERSIONING" "$LOCK" "$LOCKRET" "$QUOTABAND" "$QUOTASTO"
                echo "Storage usage : ${SIZEGB}GB / ${STOREGB}GB"

                for EXTLINE in $(${CMD} "http://${DOMAIN}?format=json&fields=name,policy_ecencoding,policy_replicas,policy_versioning,x_object_lock_meta_status,x_object_lock_meta_default,x_caringo_meta_quota_bandwidth_limit,x_caringo_meta_quota_storage_limit"|sed "s/ /___/g")
                do
                        type="BUCKET"
                        printtable
                done
                printf "=%.0s" {1..150}
        done

done
echo -e "\n"





#     #  #######     #     #######  #     #   #####   #     #  #######   #####   #    #
#     #  #          # #       #     #     #  #     #  #     #  #        #     #  #   #
#     #  #         #   #      #     #     #  #        #     #  #        #        #  #
#######  #####    #     #     #     #######  #        #######  #####    #        ###
#     #  #        #######     #     #     #  #        #     #  #        #        #  #
#     #  #        #     #     #     #     #  #     #  #     #  #        #     #  #   #
#     #  #######  #     #     #     #     #   #####   #     #  #######   #####   #    #



if [[ $(which banner) ]] ; then
        banner "Storage Nodes"
else
        echo "Storage Nodes"
fi


for NODE in $(${CMD} "${ADMINURL}${NODESURL}"| jq "._embedded.nodes[].id"|sed "s/\"//g")
do
        printf "#%.0s" {1..155}
        echo -e "\n# ${NODE}"

        NODESTATUS=$(${CMD} "${ADMINURL}${NODESURL}"| jq '._embedded.nodes[]|select(.id == '\"${NODE}\"' )|._links.self.href'|sed "s/\"//g")
        STATUS=$(${CMD} "${ADMINURL}${NODESTATUS}")

        declare -a ARRAY=("status" "errCount" "timestamp" "lastHPCycleTm" "volErrs" "streamCount" "maxSpace" "usedSpace" "availSpace" "swVer" "upTime" "outofsyncCount" "availPercent" )
        for VAL in ${ARRAY[@]}; do
                echo "# .${VAL} = $(echo ${STATUS}|jq .${VAL})"
        done

        HEALTHREPORT=$(echo ${STATUS}|jq '._links."waggle:healthreport".href'|sed "s/\"//g")
        HEALTHSTATS=$(${CMD} "${ADMINURL}${HEALTHREPORT}")
        STATS=$(echo ${HEALTHSTATS} |jq '.healthreport."SNMP tables"."HP last cycle: Stream stats"')

        printf "%6s %40s %15s %10s %20s\n" "INDEX|" "STREAM TYPE|" "SIZE|" "COUNT|" "ENCODING"
        printf "_%.0s" {1..150}
        echo ""
        for ((i=0; i<=$(echo ${STATS} |jq '.Index | length'); i++));
        do
                INDEX=$(echo $STATS |jq '."Index"['$i']')
                STREAM=$(echo $STATS |jq '."Stream Type"['$i']'|sed "s/\"//g")
                SIZE=$(echo $STATS |jq '."Size Bound"['$i']')
                COUNT=$(echo $STATS |jq '."Count"['$i']')
                ENCODING=$(echo $STATS |jq '."Encoding"['$i']'|sed "s/\"//g")
        printf "%6s %40s %15s %10s %20s\n" "$INDEX|" "$STREAM|" "$SIZE|" "$COUNT|" "$ENCODING"

        done


done
