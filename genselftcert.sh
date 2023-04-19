#! /bin/bash
#
# Self Signed certicat generation with the CA root
# Author : Gaetan MARAIS
# Date   : 2023/04/18
#################################################################


if [[  $((which dig  >/dev/null 2>&1);echo $?) -ne 0 ]] ; then
        echo " ERROR : dig is not installed on this system, please install bind-utils"
        exit 1
fi

if [[  $((which openssl  >/dev/null 2>&1);echo $?) -ne 0 ]] ; then
        echo " ERROR : openssl is not installed on this system, please install it"
        exit 1
fi




read -e -p "Domain name       : " DOMAIN
read -e -p "Company name      : " COMPANY
read -e -p "Country (FR/ES..) : " COUNTRY
read -e -p "City              : " CITY
read -e -p "State             : " STATE

DOMAIN=${DOMAIN,,}
COMPANY=${COMPANY^^}
COUNTRY=${COUNTRY^^}
CITY=${CITY^^}
STATE=${STATE^^}





IP1=$(dig +short "${DOMAIN}" 8.8.8.8)

if [[ "${IP1}" == ""  ]]; then
        echo "$DOMAIN is not known by Internet DNS server 8.8.8.8"
        echo "   possible error caused by backspace caracter :("
        exit 1
fi
clear
echo "Selfsigned certifiat will be created for"
echo "Domain name       : $DOMAIN"
echo "Internet IP       : $IP1"
echo "Company name      : $COMPANY"
echo "Country (FR/ES..) : $COUNTRY"
echo "City              : $CITY"
echo "State             : $STATE"



read

if [[ ! -r ./certs ]] ; then
        mkdir ./certs
fi

if [[ -r "./certs/${DOMAIN}" ]] ; then
        echo "Folder ./certs/${DOMAIN} already exist, you can brake now!    if not existing certificats will be replaced"
        rm -rf "./certs/${DOMAIN}"
        read
fi
mkdir "./certs/${DOMAIN}"


# Create root CA & Private key

openssl req -x509 \
            -sha256 -days 1825 \
            -nodes \
            -newkey rsa:2048 \
            -subj "/CN=${DOMAIN}/C=${COUNTRY}/L=${CITY}" \
            -keyout "./certs/${DOMAIN}/rootCA.key" -out "./certs/${DOMAIN}/rootCA.crt"

# Generate Private key

openssl genrsa -out "./certs/${DOMAIN}/${DOMAIN}.key" 2048

# Create csf conf

cat > ./certs/${DOMAIN}/csr.conf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = ${COUNTRY}
ST = ${STATE}
L = ${CITY}
O = ${COMPANY}
OU = ${COMPANY}
CN = ${DOMAIN}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
DNS.2 = s3.${DOMAIN}
IP.1 = $IP1

EOF

# create CSR request using private key

openssl req -new -key "./certs/${DOMAIN}/${DOMAIN}.key" -out "./certs/${DOMAIN}/${DOMAIN}.csr" -config "./certs/${DOMAIN}/csr.conf"

# Create a external config file for the certificate

cat > ./certs/${DOMAIN}/cert.conf <<EOF

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}

EOF

# Create SSl with self signed CA

openssl x509 -req \
    -in "./certs/${DOMAIN}/${DOMAIN}.csr" \
    -CA "./certs/${DOMAIN}/rootCA.crt" -CAkey "./certs/${DOMAIN}/rootCA.key" \
    -CAcreateserial -out "./certs/${DOMAIN}/${DOMAIN}.crt" \
    -days 1825 \
    -sha256 -extfile "./certs/${DOMAIN}/cert.conf"


cat "./certs/${DOMAIN}/rootCA.crt" "./certs/${DOMAIN}/rootCA.key" "./certs/${DOMAIN}/${DOMAIN}.crt" "./certs/${DOMAIN}/${DOMAIN}.key" > "./certs/${DOMAIN}/${DOMAIN}.pem"
