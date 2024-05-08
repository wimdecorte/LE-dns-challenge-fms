#!/bin/bash -xe
# -e = exit if any command execution returns nonzero status except in a context that handles such: while until if && || !
# -x = print commands as they are executed

sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-route53
sudo snap connect certbot:plugin certbot-dns-route53

exit 0