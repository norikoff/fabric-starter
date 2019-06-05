#!/usr/bin/env bash
source ./container-lib.sh 2>/dev/null # for IDE code completion
source $(dirname "$0")/container-lib.sh

tree crypto-config

if [ ! -d "crypto-config/peerOrganizations/$ORG.$DOMAIN/peers/peer0.$ORG.$DOMAIN/msp" ]; then
    echo "Generation $ORG peer MSP."

    IFS='.' read -r -a subDomains <<< ${DOMAIN}

    echo $DOMAIN
    if [ -z "$LDAP_BASE_DN" ]; then
        for subDomain in ${subDomains[@]}; do
            [ -n "${LDAP_BASE_DN}" ] && COMMA=,
            LDAP_BASE_DN="${LDAP_BASE_DN}${COMMA}dc=$subDomain"
        done
        export LDAP_BASE_DN
    fi

    [ -n "$LDAP_ENABLED" ] && echo "LDAP Url used: $LDAP_BASE_DN"

    envsubst < "templates/cryptogen-peer-template.yaml" > "crypto-config/cryptogen-$ORG.yaml"
    envsubst < "templates/fabric-ca-server-template.yaml" > "crypto-config/fabric-ca-server-config-$ORG.yaml"
    cryptogen generate --config=crypto-config/cryptogen-$ORG.yaml
    mv crypto-config/peerOrganizations/$ORG.$DOMAIN/ca/*_sk crypto-config/peerOrganizations/$ORG.$DOMAIN/ca/sk.pem
    mv crypto-config/peerOrganizations/$ORG.$DOMAIN/users/Admin@$ORG.$DOMAIN/msp/keystore/*_sk crypto-config/peerOrganizations/$ORG.$DOMAIN/users/Admin@$ORG.$DOMAIN/msp/keystore/sk.pem
    cp -r crypto-config/ordererOrganizations/$DOMAIN/msp/* crypto-config/peerOrganizations/$ORG.$DOMAIN/msp 2>/dev/null

    mkdir -p crypto-config/peerOrganizations/$ORG.$DOMAIN/msp/well-known
    cp crypto-config/peerOrganizations/$ORG.$DOMAIN/msp/tlscacerts/tlsca.$ORG.$DOMAIN-cert.pem crypto-config/peerOrganizations/$ORG.$DOMAIN/msp/well-known/msp-admin.pem 2>/dev/null
    cp crypto-config/peerOrganizations/$ORG.$DOMAIN/msp/tlscacerts/tlsca.$ORG.$DOMAIN-cert.pem crypto-config/peerOrganizations/$ORG.$DOMAIN/msp/well-known/tlsca-cert.pem 2>/dev/null
else
    echo "$ORG MSP exists. Generation skipped."
fi

if [ ! -f "crypto-config/hosts_$ORG" ]; then
    if [ -n "$BOOTSTRAP_IP" ]; then
        echo "Generating crypto-config/hosts_$ORG"
        echo -e "#generated at bootstrap as part of crypto- and meta-information generation\n${BOOTSTRAP_IP}\torderer.${DOMAIN} www.${DOMAIN} api.${DOMAIN} ${DOMAIN}" > crypto-config/hosts_$ORG
        echo "\n\nDownload orderer MSP envsfrom $BOOTSTRAP_IP\n\n"
        downloadOrdererMSP
    else
        echo -e "#generated empty at bootstrap as part of crypto- and meta-information generation" > crypto-config/hosts_$ORG
    fi
else
    echo "crypto-config/hosts_$ORG file exists. Generation skipped."
fi
    cat crypto-config/hosts_$ORG
