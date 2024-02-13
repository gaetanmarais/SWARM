#!/bin/bash
#
#
# Author  : G. MARAIS (DataCore)
# Date    : 22/05/03
# Version : 1.0
#
# Description  : This script is used to create a new domain is an existing SWARM Tenant, creating a PAM USER in all Gateway, associating Token to this user and adding FULL access policy to this user
#
# Prerequisite : All GW need to have SSH keys shared   (e.g: https://www.redhat.com/sysadmin/configure-ssh-keygen)



########
#
# PARAMETERS
#


#SWARM UI Administrator's credentials
USER="dcsadmin@"
PASSWD="Mypassword"

# List Gateways IP@ with space   "10.12.105.33 10.12.105.34"
GATEWAYS="10.12.105.33 10.12.105.34"

DOMAINSUFFIX="swarm.datacore.paris"



########
#
# SCRIPT
#



clear

read -p "Enter username : " USERNAME
PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 40 ; echo '')

if [[ $(grep -c "^${USERNAME}:" /etc/passwd) -ne 0 ]] ; then

        echo "User already exist"
        read -p "Reset password for \"${USERNAME}\" [${PASSWORD}]: " NEWPASSWORD
        if [[ "${NEWPASSWORD}" == "" ]]; then NEWPASSWORD=${PASSWORD}; fi
else
        read -p "Enter password for \"${USERNAME}\" [${PASSWORD}]: " NEWPASSWORD
        if [[ "${NEWPASSWORD}" == "" ]]; then NEWPASSWORD=${PASSWORD}; fi
fi

echo "Adding user..."

for GATEWAY in ${GATEWAYS}
do
echo ""
        ssh ${GATEWAY} "/usr/sbin/useradd ${USERNAME} -s /sbin/nologin -M"
        ssh ${GATEWAY} "echo ${USERNAME}:${NEWPASSWORD} | /usr/sbin/chpasswd"
done

echo ""
echo "List Tenant(s)"

while read TT
do
        Tenant=${TT}
        echo " - ${Tenant}"
done <<< $(curl -s -L -u ${USER}:${PASSWD} http://${GATEWAY}/_admin/manage/tenants/?format=json |jq .[].name|sed "s/\"//g"|sort)

read -p "Enter tenant name [${Tenant}] : " TENANT
if [[ "${TENANT}" -eq "" ]]; then TENANT=${Tenant}; fi


echo ""
echo "List existing domains in \"${TENANT}\""
curl -s -L -u ${USER}:${PASSWD} http://${GATEWAY}/_admin/manage/tenants/${TENANT}/domains/?format=json |jq .[].name|sed "s/\"//g"|sort| while read DOMAIN
do
echo " * ${DOMAIN}"
done

read -p "Enter NEW domain name to create (IANA compliant) [${USERNAME}.${DOMAINSUFFIX}]: " DOMAIN
if [[ "${DOMAIN}" -eq "" ]]; then DOMAIN="${USERNAME}.${DOMAINSUFFIX}"; fi


echo ""
echo "Creating new domaine \"${DOMAIN}\""
RESULTDOMAIN=$(curl -s -X PUT "http://${GATEWAY}/_admin/manage/tenants/${TENANT}/domains/${DOMAIN}" -H "Accept: application/json, text/plain, */*" --user ${USER}:${PASSWD})


echo "Create Token"
TOKEN=$(curl -s -X POST "http://${GATEWAY}/.TOKEN/?domain=${DOMAIN}&setcookie=false"  -H "x-owner-meta: ${USERNAME}" -H "x-custom-meta-source: ${NEWPASSWORD}" -H "x-user-secret-key-meta: ${NEWPASSWORD}" -H "x-user-token-expires-meta: 2025-01-01T00:00:00.000Z" --user ${USER}:${PASSWD}|awk '{print $2}')


echo "Adding Policy"
RESULTPOLICY=$(curl -s -X PUT "http://${GATEWAY}/_admin/manage/tenants/${TENANT}/domains/${DOMAIN}/etc/policy.json" --data '{"Version":"2008-10-17","Id":"Full Access to '${USERNAME}'","Statement":[{"Sid":"1: Full access for Users","Effect":"Allow","Principal":{"user":["'${USERNAME}'"],"group":[]},"Action":["*"],"Resource":"*"}]}'  --user ${USER}:${PASSWD})


echo "Adding Quota"
RESULTQUOTA=$(curl -s -X PUT "http://${GATEWAY}/_admin/manage/tenants/${TENANT}/domains/${DOMAIN}/quota/email?addresses=gaetan.marais@datacore.com" --user ${USER}:${PASSWD})
RESULTQUOTA=$(curl -s -X PUT "http://${GATEWAY}/_admin/manage/tenants/${TENANT}/domains/${DOMAIN}/rsw?state=disabled" --user ${USER}:${PASSWD})
RESULTQUOTA=$(curl -s -X PUT "http://${GATEWAY}/_admin/manage/tenants/${TENANT}/domains/${DOMAIN}/quota/storage/limit?limit=250000000000&state=nowrite" --user ${USER}:${PASSWD})



echo "


WEB UI    : https://${DOMAIN}/_admin/portal
USERNAME  : ${USERNAME}
PASSWORD  : ${NEWPASSWORD}

ENDPOINT  : https://${DOMAIN}
TOKEN     : ${TOKEN}
SECRETKEY : ${NEWPASSWORD}"|tee NEWDOMAINS/${DOMAIN}.txt
