#!/usr/bin/env bash
set -u
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



# This script runs the certbot generation and imports the certificate into FileMaker Server.
# Please ensure that FileMaker Server is running prior to running this script.

# Usage:
# ./fms-request-cert-dns-route53.sh
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
        err "[ERROR] Certbot not installed. Exiting..." 
        # Install Certbot Package
        # snap install --classic certbot
        # Prepare Certbot Command
        # ln -s /snap/bin/certbot /usr/bin/certbot
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # MacOS
    if [[ ! -e "/opt/homebrew/bin/certbot" ]] ; then
        err "[ERROR] Certbot not installed. Exiting..." 
        # Install Homebrew
        # /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Prepare Homebrew
        # (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/$USER/.zprofile
        # zsh
        # eval "$(/opt/homebrew/bin/brew shellenv)"
        # Install Certbot
        # brew install certbot
        exit 1
    fi
fi

# FileMaker Admin Console Login Information
if [ $PROMPT == 0 ] ; then
    if [[ -n "${FAC_USERNAME}" ]]; then
        FAC_USER="${FAC_USERNAME}"
    else
        err " [ERROR]: The FileMaker Server Admin Console Credentials was not set. Set FAC_USERNAME as an environment variable using export FAC_USERNAME="
        err " If FAC_USERNAME and FAC_PASSWORD have been set, make sure to run the script using sudo -E ./fm_request_cert.sh"
        err " Additionally, make sure that to set FAC_PASSWORD as an environment variable using export FAC_PASSWORD="
        exit 1
    fi

    if [[ -n "${FAC_PASSWORD}" ]]; then
        FAC_PASS="${FAC_PASSWORD}"
    else
        err " [ERROR]: The FileMaker Server Admin Console Credentials was not set. Set FAC_PASSWORD as an environment variable using export FAC_PASSWORD="
        exit 1
    fi
else
    # Prompt user for values
    echo " Enter email for Let's Encrypt Notifications."
    read -p "   > Email: " EMAIL

    echo " Enter the domain for Certificate Generation. Note: Wildcards are not supported."
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
fi

# DO NOT EDIT - FileMaker Directories
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CERTBOTPATH="/opt/FileMaker/FileMaker Server/CStore/Certbot"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    CERTBOTPATH="/Library/FileMaker Server/CStore/Certbot"
fi

# Set up paths for necessary directories
if [[ ! -e "$CERTBOTPATH" ]] ; then
    echo "[WARNING]: $CERTBOTPATH not found. Creating necessary directories." 
    sudo -E mkdir -p "$CERTBOTPATH"
fi

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"

# Disggregate domain list into arguments
DOMAIN+=","
DOMAINLIST=""
IFS=',' read -ra ADDR <<< "$DOMAIN"
FIRST_DOMAIN=""
for CUR_DOMAIN in "${ADDR[@]}"; do
    if [[ -z "${FIRST_DOMAIN}" ]] ; then
        # First domain in list will be used for the name of the folder
        FIRST_DOMAIN=${CUR_DOMAIN}
    fi
    DOMAINLIST+="-d ${CUR_DOMAIN} "
done

# Check to see if a directory already exists for the domain
if [[ -e "$CERTBOTPATH/live/$FIRST_DOMAIN" ]] ; then 
    err "[ERROR]: A directory with the domain $FIRST_DOMAIN already exists. Please backup and remove the folder \"$CERTBOTPATH/live/$FIRST_DOMAIN/\""
    exit 1
fi 

# If updating current certificate (UPDATE_EXISTING_CERT) is set to 1
EXPAND_PARAM=""
if [[ $UPDATE_EXISTING_CERT -eq 1 ]] ; then
    EXPAND_PARAM=" --expand"
fi

# Test Parameter
TEST_CERT_PARAM=""
if [[ $TEST_CERTIFICATE -eq 1 ]] ; then
    TEST_CERT_PARAM=" --dry-run"
fi

if [[ $TEST_CERTIFICATE -eq 1 ]] ; then
    echo "Generating test certificate request." 
else
    echo "Generating certificate request." 
fi

# Run the certbot certificate generation command
sudo -E certbot certonly --dns-route53 $TEST_CERT_PARAM $DOMAINLIST --agree-tos --non-interactive -m $EMAIL --config-dir "$CERTBOTPATH" --work-dir "$CERTBOTPATH" --logs-dir "$CERTBOTPATH" $EXPAND_PARAM --deploy-hook "./post-renewal-import.sh"

# Capture return code for running certbot command
RETVAL=$?

if [ $RETVAL != 0 ] ; then
    err "[ERROR]: Certbot returned with a nonzero failure code. Check $CERTBOTPATH/letsencrypt.log for more information."
    exit 1
fi


exit 0