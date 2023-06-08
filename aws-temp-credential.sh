#!/bin/bash

AWS_CONFIG_FILE="$HOME/.aws/config"

echo_green() {
  local message=$1
  echo -e "\033[32m$message\033[0m"
}

echo_white() {
  local message=$1
  echo -e "\033[37m$message\033[0m"
}

echo_red() {
  local message=$1
  echo -e "\033[31m$message\033[0m"
}

# Function to retrieve values from AWS config file
retrieve_aws_config_values() {
  local profile_name=$1
  local start_url
  local region
  local account_id
  local role_name

  # Retrieve the values using grep and awk
  start_url=$(grep -A4 -E "^\[profile $profile_name\]" "$AWS_CONFIG_FILE" | awk -F'=' '/sso_start_url/ {print $2}' | tr -d ' ')
  region=$(grep -A4 -E "^\[profile $profile_name\]" "$AWS_CONFIG_FILE" | awk -F'=' '/sso_region/ {print $2}' | tr -d ' ')
  account_id=$(grep -A4 -E "^\[profile $profile_name\]" "$AWS_CONFIG_FILE" | awk -F'=' '/sso_account_id/ {print $2}' | tr -d ' ')
  role_name=$(grep -A4 -E "^\[profile $profile_name\]" "$AWS_CONFIG_FILE" | awk -F'=' '/sso_role_name/ {print $2}' | tr -d ' ')

  # Return the retrieved values
  echo "$start_url"
  echo "$region"
  echo "$account_id"
  echo "$role_name"
}

AWS_CONFIG_VALUES=($(retrieve_aws_config_values "$AWS_PROFILE"))

AWS_SSO_START_URL=${AWS_CONFIG_VALUES[0]}
AWS_REGION=${AWS_CONFIG_VALUES[1]}
AWS_ACCOUNT_ID=${AWS_CONFIG_VALUES[2]}
AWS_ROLE_NAME=${AWS_CONFIG_VALUES[3]}
ENV_PATH='.env'

# Print the retrieved values
echo_green "AWS PROFILE INFO"
echo_white "Start URL: ${AWS_CONFIG_VALUES[0]}"
echo_white "Region: ${AWS_CONFIG_VALUES[1]}"
echo_white "Account ID: ${AWS_CONFIG_VALUES[2]}"
echo_white "Role Name: ${AWS_CONFIG_VALUES[3]}"

AWS_SSO_CREDENCIAL_PATH="$HOME/.aws/sso/cache/"
SEARCH_PROPERTY=".startUrl"
SEARCH_VALUE="$AWS_SSO_START_URL"
NEWEST_FILE=""

for file in "$AWS_SSO_CREDENCIAL_PATH"*.json; do

	value=$(jq -r "$SEARCH_PROPERTY" "$file")

	if [[ "$value" == "$SEARCH_VALUE" ]]; then
		if [[ -z "$NEWEST_FILE" || "$file" -nt "$NEWEST_FILE" ]]; then
			NEWEST_FILE="$file"
		fi
	fi
done

if [[ -n "$NEWEST_FILE" ]]; then

	echo_white "SSO FILE: $NEWEST_FILE"
	# Add your additional logic here

	NEWEST_FILE=$(ls -t "$AWS_SSO_CREDENCIAL_PATH" | head -n 1)
	AWS_SSO_ACCESS_TOKEN=$(jq -r '.accessToken' "$AWS_SSO_CREDENCIAL_PATH$NEWEST_FILE")
	AWS_TEMP_CREDENTIAL=$(aws sso get-role-credentials --account-id "$AWS_ACCOUNT_ID" --role-name "$AWS_ROLE_NAME" --access-token "$AWS_SSO_ACCESS_TOKEN" --region "$AWS_REGION")

	AWS_ACCESS_KEY_ID=$(echo $AWS_TEMP_CREDENTIAL | jq -r '.roleCredentials.accessKeyId')
	AWS_SECRET_ACCESS_KEY=$(echo $AWS_TEMP_CREDENTIAL | jq -r '.roleCredentials.secretAccessKey')
	AWS_SESSION_TOKEN=$(echo $AWS_TEMP_CREDENTIAL | jq -r '.roleCredentials.sessionToken')

	echo_green "AWS_ACCESS_KEY_ID:"
	echo_white $AWS_ACCESS_KEY_ID
	echo_green "AWS_SECRET_ACCESS_KEY:"
	echo_white $AWS_SECRET_ACCESS_KEY
	echo_green "AWS_SESSION_TOKEN:"
	echo_white $AWS_SESSION_TOKEN

	ENV_FILE=".env"

	# Check if the .env file exists
	if [ -f "$ENV_FILE" ]; then

		# Define the key-value pairs to replace
		declare -A replacements=(
			["AWS_ACCESS_KEY_ID"]="$AWS_ACCESS_KEY_ID"
			["AWS_SECRET_ACCESS_KEY"]="$AWS_SECRET_ACCESS_KEY"
			["AWS_SESSION_TOKEN"]="$AWS_SESSION_TOKEN"
		)

		# Iterate over the key-value pairs
		for key in "${!replacements[@]}"; do
			value=${replacements[$key]}
			sed -i "s|^$key=.*|$key=$value|" "$ENV_FILE"
		done

		echo_green "$ENV_FILE values updated!"
	else
		echo_red "The .env file does not exist."
	fi
else
  echo_red "No matching file found. check if your AWS_PROFILE variable is defined."
fi
