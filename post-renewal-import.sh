#!/bin/bash

# exit when a variable isn't set
set -u
# prevents errors in a pipeline from being masked.
set -o pipefail


# setup
# -----------------------------------------------------
# load the variables from the conf file
# assumes that the conf file is in the same folder as this script
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"
filePath="01-fms-certbot.conf"

if [ ! -f "$filePath" ]; then
    echo "missing ${filePath}"
    exit 1
fi

while read -r LINE; do
    # Remove leading and trailing whitespaces, and carriage return
    CLEANED_LINE=$(echo "$LINE" | awk '{$1=$1};1' | tr -d '\r')

    if [[ $CLEANED_LINE != '#'* ]] && [[ $CLEANED_LINE == *'='* ]]; then
        export "$CLEANED_LINE"
    fi
done < "$filePath"
# -----------------------------------------------------


# This script imports the certificate into FileMaker Server.

# Usage:
# runs automatically as part of the Certbot renewal process, with the --deploy-hook option
# the relevant commands that need to run as sudo have the -E flag to preserve the environment variables


# Used to redirect errors to stderr
err()
{
    echo "$*" >&2
}


# FileMaker Admin Console Login Information
if [[ -n "${FAC_USERNAME}" ]]; then
    FAC_USER="${FAC_USERNAME}"
else
    err "[ERROR]: The FileMaker Server Admin Console Credentials was not set. Set FAC_USERNAME as an environment variable using export FAC_USERNAME="
    err " If FAC_USERNAME and FAC_PASSWORD have been set, make sure to run the script using sudo -E ./fm_request_cert.sh"
    err " Additionally, make sure that to set FAC_PASSWORD as an environment variable using export FAC_PASSWORD="
    exit 1
fi

if [[ -n "${FAC_PASSWORD}" ]]; then
    FAC_PASS="${FAC_PASSWORD}"
else
    err "[ERROR]: The FileMaker Server Admin Console Credentials was not set. Set FAC_PASSWORD as an environment variable using export FAC_PASSWORD="
    exit 1
fi


# DO NOT EDIT - FileMaker Directories
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CERTBOTPATH="/opt/FileMaker/FileMaker Server/CStore/Certbot"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    CERTBOTPATH="/Library/FileMaker Server/CStore/Certbot"
fi

# Set up paths for necessary directories
if [[ ! -e "$CERTBOTPATH" ]] ; then
    err "[WARNING] $CERTBOTPATH not found. Certificate likely does not exist." 
    exit 1
fi

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"

CERTFILEPATH=$(sudo -E realpath "$CERTBOTPATH/live/$DOMAIN/fullchain.pem")
PRIVKEYPATH=$(sudo -E realpath "$CERTBOTPATH/live/$DOMAIN/privkey.pem")

# grant fmserver:fmsadmin group ownership
if sudo -E test -f "$PRIVKEYPATH"; then
    sudo -E chown -R fmserver:fmsadmin "$CERTFILEPATH"
else
    err "[ERROR]: An error occurred with certificate renewal. No private key found."
    exit 1
fi

if sudo -E test -f "$CERTFILEPATH"; then
    sudo -E chown -R fmserver:fmsadmin "$PRIVKEYPATH"
else
    err "[ERROR]: An error occurred with certificate renewal. No certificate found."
    exit 1
fi

# run fmsadmin import certificate
echo "Importing Certificates:"
echo "Certificate: $CERTFILEPATH"
echo "Private key: $PRIVKEYPATH"

sudo -E fmsadmin certificate import "$CERTFILEPATH" --keyfile "$PRIVKEYPATH" -y -u $FAC_USER -p $FAC_PASS

# Capture return code for running fmsadmin command
RETVAL=$?
if [ $RETVAL != 0 ] ; then
    err "[ERROR]: FileMaker Server was unable to import the generated certificate."
    exit 1
fi

# check if user wants to restart server
if [[ $RESTART_SERVER == 1 ]] ; then
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "Restarting FileMaker Server."
    isServerRunning
    serverIsRunning=$?
    if [ $serverIsRunning -eq 1 ] ; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo service fmshelper stop
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            sudo launchctl stop com.filemaker.fms
        fi
    fi

    waitCounter=0
    while [[ $waitCounter -lt $MAX_WAIT_AMOUNT ]] && [[ $serverIsRunning -eq 1 ]]
    do
        sleep 10
        isServerRunning
        serverIsRunning=$?
        echo "Waiting for FileMaker Server process to terminate..."

        waitCounter=$((waitCounter++))
    done

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo service fmshelper start
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        sudo launchctl start com.filemaker.fms
    fi
fi

echo "Lets Encrypt certificate renew script completed without any errors."

exit 0