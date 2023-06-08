# aws-sso-temp-credentials

## Install

```shell
    git clone git@github.com:FelipeSouzaF/aws-sso-temp-credentials.git && \
    cd aws-sso-temp-credentials && \
    cp aws-temp-credential.sh /usr/local/bin/
    chmod +x /usr/local/bin/aws-temp-credential.sh
```

## Usage

```shell
    # configure your $HOME/.aws/config file with your profile
    # example
    cat <<EOF >> $HOME/.aws/config
[profile my-awesome-profile]
sso_start_url = https://your-aws-sso-domain.awsapps.com/start#/
sso_region = us-east-1
sso_account_id = 000000000001
sso_role_name = AdministratorAccess
region = us-east-1
output = json
EOF

    # Set your aws profile as an environment variable
    export AWS_PROFILE="my-awesome-profile"

    # login into aws using cli
    aws sso login

    # Get your awesome credential and have fun
    aws-temp-credential.sh
```
