#!/bin/bash -xe
# -e = exit if any command execution returns nonzero status except in a context that handles such: while until if && || !
# -x = print commands as they are executed

# setup
# -----------------------------------------------------
# these are read from the .env-setup file in the same folder
export $(grep -v '^#' .env-setup | xargs)
# -----------------------------------------------------

sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-route53
sudo snap connect certbot:plugin certbot-dns-route53

# become root user
sudo su
# for AWS
# see other places where the plugin can look for the AWS credentials
# https://certbot-dns-route53.readthedocs.io/en/stable/
export AWS_ACCESS_KEY_ID=$AWS_KEY
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET
# for FMS
export FAC_USERNAME=$FAC_USERNAME
export FAC_PASSWORD=$FAC_PASSWORD