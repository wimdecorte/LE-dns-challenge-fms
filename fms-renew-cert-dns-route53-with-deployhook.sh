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


# This script runs the certbot renewal and imports the certificate into FileMaker Server.

# Usage:
# ./fms-renew-cert-dns-route53.sh
# the relevant commands that need to run as sudo have the -E flag to preserve the environment variables

# Detects if FileMaker Server is still running
isServerRunning()
{
    fmserver=$(ps axc | sed "s/.*:..... /\"/" | sed s/$/\"/ | grep fmserver)
    if [[ -z $fmserver ]] ; then
        return 0    # fmserver is not running
    fi
    return 1        # fmserver is running
}

# Used to redirect errors to stderr
err()
{
    echo "$*" >&2
}

# Test to see if Certbot is installed
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Ubuntu
    if [[ ! -e "/snap/bin/certbot" ]] ; then
        err "[ERROR] Certbot not installed. Please install Certbot and run fm_request_cert.sh prior to running this script. Exiting..." 
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # MacOS
    if [[ ! -e "/opt/homebrew/bin/certbot" ]] ; then
        err "[ERROR] Certbot not installed. Please install Certbot and run fm_request_cert.sh prior to running this script. Exiting..." 
        exit 1
    fi
fi


if [ $PROMPT == 0 ] ; then
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
else
    # Prompt user for values
    echo " Enter the domain used to generate the certificate. If multiple domains were used, enter the name of the folder that the certificates should be found in."
    read -p "   > Domain: " DOMAIN

    echo " To import the certificates and restart FileMaker Server, enter the FileMaker Admin Console credentials:"
    read -s -p "   > Username: " FAC_USER
    echo ""

    read -s -p "   > Password: " FAC_PASS
    echo ""

    echo " Do you want to restart FileMaker Server after the certificate is generated?"
    read -p "   > Restart (0 for no, 1 for yes): " RESTART_SERVER

    echo " Do you want to generate a test certificate?"
    read -p "   > Test Validation (0 for no, 1 for yes): " TEST_CERTIFICATE

    echo " Enter the AWS Access Key for AWS user account."
    read -p "   > AWS key: " AWS_KEY

        echo " Enter the AWS Access Secret for AWS user account."
    read -p "   > AWS secret: " AWS_SECRET

    if [[ $TEST_CERTIFICATE -eq 0 ]] ; then
        echo " Do you want to force renew the certificate?"
        read -p "   > Force Renew (0 for no, 1 for yes): " FORCE_RENEW
    fi
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

# run the certbot command
if [[ $TEST_CERTIFICATE -eq 1 ]] ; then
    echo "Generating test certificate request." 
    sudo -E certbot renew --dns-route53 --dry-run --cert-name $DOMAIN  --config-dir "$CERTBOTPATH" --work-dir "$CERTBOTPATH" --logs-dir "$CERTBOTPATH"
else
    echo "Generating certificate request." 
    if [[ $FORCE_RENEW -eq 1 ]] ; then
        sudo -E certbot renew --dns-route53 --cert-name $DOMAIN --force-renew --config-dir "$CERTBOTPATH" --work-dir "$CERTBOTPATH" --logs-dir "$CERTBOTPATH" --deploy-hook "./fms-import-cert.sh"
    else
        sudo -E certbot renew --dns-route53 --cert-name $DOMAIN --config-dir "$CERTBOTPATH" --work-dir "$CERTBOTPATH" --logs-dir "$CERTBOTPATH" --deploy-hook "./fms-import-cert.sh"
    fi
fi

# capture return code for running certbot command
RETVAL=$?

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"

if [[ $RETVAL != 0 ]] ; then
    err "[ERROR]: Certbot returned with a nonzero failure code. Check $CERTBOTPATH/letsencrypt.log for more information."
    exit 1
fi


exit 0