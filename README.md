## Acknowledgements & Background:
----------------------------------
Prior to generating a certificate, Let's Encrypt (LE) requires users to validate the domain that the certificate will be issued to.

The original Claris scripts only supports Let's Encrypt validation through its HTTP-01 challenge, which will create a temporary directory and webpage to complete domain validation, and requires LE to be able to reach your FileMaker Server.

These are modified versions of the Let's Encrypt (LE) scripts provided by Claris Inc as part of Claris FileMaker Server 2024.
The original scripts use the LE http challenge, which can be tricky from a security point of view, requiring access to the FileMaker Server machine through port 80.

The scripts included here use the LE dns challenge which do not require access to the FileMaker Server at all.
See blog post <...> for more details.

This setup is for Claris FileMaker Server running on Ubuntu.

## Setup
---------------------------
Add a .env-setup file based on the example, you'll need to specify AWS credentials and the credentials for your FileMaker Server Admin Console.
Run the initial_setup.sh script and when done you can delete the .env-setup file

Add a .env file based on the example.  This holds your configuration options

Ideally you'll create an AWS IAM user with a strict policy to only be able to create the required TXT DNS record and not allowed to modify any other DNS records.  A sample policy is included.  In that policy change:
- line 21 by adding your hosted zone id
- line 26 by adding  your domain name

## To Do
-----------------------------
Just like the Claris example, allow for prompting for the AWS credentials.


## To note
------------------------------
- Root is required to run the request script. This is because Certbot creates temporary directories and sets the isssued certificate and private keys' read/write permissions to root only. 
  The script uses root for the following:
    - Temporarily stop the ufw service to allow incoming connections into port 80 for validation
    - Permit r/w access to the fmserver:fmsadmin usergroup so that generated certificates imported by FileMaker Server.
    - Generate logs in /CStore/Certbot
- A FileMaker Server restart is still needed to apply the certificate.