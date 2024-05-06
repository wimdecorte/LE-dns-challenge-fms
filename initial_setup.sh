#!/bin/bash -xe
# -e = exit if any command execution returns nonzero status except in a context that handles such: while until if && || !
# -x = print commands as they are executed

# setup
-----------------------------------------------------
# these are read from the .env-setup file in the same folder
export $(grep -v '^#' .env-setup | xargs)
# -----------------------------------------------------

sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-route53
sudo snap connect certbot:plugin certbot-dns-route53

# become root user
# sudo su
# for AWS
# see other places where the plugin can look for the AWS credentials
# https://certbot-dns-route53.readthedocs.io/en/stable/

# not needed because of export on line 8
export AWS_ACCESS_KEY_ID=$AWS_KEY
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET
# for FMS
export FAC_USERNAME=$FAC_USERNAME
export FAC_PASSWORD=$FAC_PASSWORD

# to make the environment variables available persistently
# (or consider adding them to the main .env file and not storing them in the environment)
echo "export "FAC_USERNAME"="$FAC_USERNAME >>~/.bashrc
echo "export "FAC_PASSWORD"="$FAC_PASSWORD >>~/.bashrc
echo "export "AWS_ACCESS_KEY_ID"="$AWS_ACCESS_KEY_ID >>~/.bashrc
echo "export "AWS_SECRET_ACCESS_KEY"="$AWS_SECRET_ACCESS_KEY >>~/.bashrc

# reload the environment variables
# so that you can use them immediately
source ~/.bashrc