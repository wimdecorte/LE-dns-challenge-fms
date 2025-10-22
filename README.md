## Acknowledgements & Background:

Prior to generating a certificate, Let's Encrypt (LE) requires users to validate the domain that the certificate will be issued to.

The original Claris scripts only supports Let's Encrypt validation through its HTTP-01 challenge, which will create a temporary directory and webpage to complete domain validation, and requires LE to be able to reach your FileMaker Server.

These are modified versions of the Let's Encrypt (LE) scripts provided by Claris Inc as part of Claris FileMaker Server 2024.
The original scripts use the LE http challenge, which can be tricky from a security point of view, requiring access to the FileMaker Server machine through port 80.

The scripts included here use the LE dns challenge which do not require access to the FileMaker Server at all.
See blog post <https://www.soliantconsulting.com/blog/filemaker-lets-encrypt-ssl-certificates-dns/> for more details.
This example supports both Route53 and Digital Ocean as DNS providers. The Certbot agent has support for many more:
https://community.letsencrypt.org/t/dns-providers-who-easily-integrate-with-lets-encrypt-dns-validation/86438

Just to name a few: cloudflare, google, ovh, linode, dnsimple, dnsmadeeasy, gehirn, luadns, nsone, rfc2136, sakuracloud...

This setup is for Claris FileMaker Server running on Ubuntu.

## Setup

### For AWS:
Add a file named 01-fms-certbot.conf based on the example, you'll need to specify your DNS provider (AWS or Digital Ocean), credentials, and the credentials for your FileMaker Server Admin Console, and set the options for the script
Run the initial_setup.sh script to install certbot and the appropriate dns plugin.

For AWS Route53:
Ideally, you'll create an AWS IAM user with a strict policy to only be able to create the required TXT DNS record and not be allowed to modify any other DNS records. A sample policy is included. In that policy, change:
- line 21 by adding your hosted zone id
- line 26 by adding your domain name

### For Digital Ocean:
Create a Digital Ocean Token with the following permissions:

Required scopes:
- `domain:read` - Read domain and DNS record information
- `domain:create` - Create DNS records (for ACME challenge)
- `domain:delete` - Delete DNS records (cleanup after validation)

**Do NOT select:**
- Droplet permissions
- Load balancer permissions
- Any other non-domain permissions

The token will be stored securely in `/etc/certbot/digitalocean.ini` with 600 permissions (readable only by root).

See Digital Ocean's documentation: https://docs.digitalocean.com/reference/api/create-personal-access-token/

## Scripts

The scripts will use sudo where appropriate.  For the renewal script, if you want to schedule that as a FileMaker Server script with the default fmserver account, you will have to set the NOPASSWD option in the sudoers file (see the blog post for more details).

## To Do

- Email me your suggestions or add them as an issue on this repo.
- Consider rewriting an alternative version that combines both the initial request and renewal scripts into a single script. This script should accept `--params` options. The idea is to have one script file where all settings, domain names, keys, and other variables are set using the FileMaker external script schedule parameters. This approach would ensure that filemaker server settings backups and restores contain all the required information to continue cerbot operating without any user intervention.


## To note

- Root is required throughout the request and renewal scripts. This is because Certbot creates temporary directories and sets the isssued certificate and private keys' read/write permissions to root only. 
  The script uses root for the following:
    - Temporarily stop the ufw service to allow incoming connections into port 80 for validation
    - Permit r/w access to the fmserver:fmsadmin usergroup so that generated certificates imported by FileMaker Server.
    - Generate logs in /CStore/Certbot
- A FileMaker Server restart is still needed to apply the certificate.
