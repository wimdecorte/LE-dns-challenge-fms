#!/bin/bash -e
# -e = exit if any command execution returns nonzero status except in a context that handles such: while until if && || !
# -x = print commands as they are executed

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

# Check if 01-fms-certbot.conf exists
if [ ! -f "01-fms-certbot.conf" ]; then
    echo "Error: 01-fms-certbot.conf not found"
    echo "Please copy 01-fms-certbot.conf.example to 01-fms-certbot.conf and configure it first"
    exit 1
fi

# Load configuration variables
while read -r LINE; do
    # Remove leading and trailing whitespaces, and carriage return
    CLEANED_LINE=$(echo "$LINE" | awk '{$1=$1};1' | tr -d '\r')

    if [[ $CLEANED_LINE != '#'* ]] && [[ $CLEANED_LINE == *'='* ]]; then
        export "$CLEANED_LINE"
    fi
done < "01-fms-certbot.conf"

# Check if DNS_PROVIDER is set
if [[ -z "${DNS_PROVIDER}" ]]; then
    echo "Error: DNS_PROVIDER not configured in 01-fms-certbot.conf"
    echo "Please set DNS_PROVIDER to either 'aws' or 'digitalocean'"
    exit 1
fi

# Determine DNS provider from configuration
echo "DNS Provider configured: $DNS_PROVIDER"

case $DNS_PROVIDER in
    aws)
        # Check AWS credentials are set
        if [[ -z "${AWS_ACCESS_KEY_ID}" ]] || [[ -z "${AWS_SECRET_ACCESS_KEY}" ]] || [[ -z "${AWS_REGION}" ]]; then
            echo "Error: AWS credentials not configured in 01-fms-certbot.conf"
            echo "Please set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION"
            exit 1
        fi
        
        echo "Installing certbot and AWS Route53 plugin..."
        sudo snap install --classic certbot 2>/dev/null || echo "Certbot already installed"
        sudo ln -sf /snap/bin/certbot /usr/bin/certbot
        sudo snap set certbot trust-plugin-with-root=ok
        sudo snap install certbot-dns-route53 2>/dev/null || echo "Route53 plugin already installed"
        sudo snap connect certbot:plugin certbot-dns-route53 2>/dev/null || true
        echo "AWS Route53 configured. AWS credentials validated."
        ;;
    digitalocean)
        # Check Digital Ocean token is set
        if [[ -z "${DO_TOKEN}" ]]; then
            echo "Error: Digital Ocean token not configured in 01-fms-certbot.conf"
            echo "Please set DO_TOKEN"
            exit 1
        fi
        
        echo "Installing certbot and Digital Ocean DNS plugin..."
        sudo snap install --classic certbot 2>/dev/null || echo "Certbot already installed"
        sudo ln -sf /snap/bin/certbot /usr/bin/certbot
        sudo snap set certbot trust-plugin-with-root=ok
        sudo snap install certbot-dns-digitalocean 2>/dev/null || echo "DigitalOcean plugin already installed"
        sudo snap connect certbot:plugin certbot-dns-digitalocean 2>/dev/null || true
        
        # Create/update the digitalocean.ini file with the token from config
        sudo mkdir -p /etc/certbot
        echo "dns_digitalocean_token = $DO_TOKEN" | sudo tee /etc/certbot/digitalocean.ini > /dev/null
        sudo chmod 600 /etc/certbot/digitalocean.ini
        echo "Digital Ocean DNS configured."
        echo "The token has been saved/updated at /etc/certbot/digitalocean.ini"
        echo "You can remove the DO_TOKEN value from your 01-fms-certbot.conf file if you wish, as it is no longer needed."
  
        ;;
    *)
        echo "Error: Invalid DNS_PROVIDER setting: $DNS_PROVIDER"
        echo "Please set DNS_PROVIDER to either 'aws' or 'digitalocean' in 01-fms-certbot.conf"
        exit 1
        ;;
esac

echo "Setup completed successfully!"
        echo "Please follow the instructions in the README to proceed. A single script will handle both DNS types depending on the credentials you provided."

exit 0