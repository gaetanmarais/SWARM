#! /bin/bash
#
# Self Signed certicat generation with the CA root
# Author : Gaetan MARAIS
# Date   : 2023/04/18
#################################################################

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

if [[ -r ${DOMAIN} ]] ; then
        echo "Folder ${DOMAIN} already exist, you can brake now!    if not existing certificats will be replaced"
        rm -rf ${DOMAIN}
        read
fi
mkdir ${DOMAIN}


# Create root CA & Private key

openssl req -x509 \
            -sha256 -days 1825 \
            -nodes \
            -newkey rsa:2048 \
            -subj "/CN=${DOMAIN}/C=${COUNTRY}/L=${CITY}" \
            -keyout ${DOMAIN}/rootCA.key -out ${DOMAIN}/rootCA.crt

# Generate Private key

openssl genrsa -out ${DOMAIN}/${DOMAIN}.key 2048

# Create csf conf

cat > ${DOMAIN}/csr.conf <<EOF
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

openssl req -new -key ${DOMAIN}/${DOMAIN}.key -out ${DOMAIN}/${DOMAIN}.csr -config ${DOMAIN}/csr.conf

# Create a external config file for the certificate

cat > ${DOMAIN}/cert.conf <<EOF

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}

EOF

# Create SSl with self signed CA

openssl x509 -req \
    -in ${DOMAIN}/${DOMAIN}.csr \
    -CA ${DOMAIN}/rootCA.crt -CAkey ${DOMAIN}/rootCA.key \
    -CAcreateserial -out ${DOMAIN}/${DOMAIN}.crt \
    -days 1825 \
    -sha256 -extfile ${DOMAIN}/cert.conf
