#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"

# Check for required dependencies
command -v jq >/dev/null 2>&1 || { echo -e "\033[31mError: 'jq' is required but not installed. Install it with: sudo apt-get install jq\033[0m" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "\033[31mError: 'aws' CLI is required but not installed. Visit: https://aws.amazon.com/cli/\033[0m" >&2; exit 1; }

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

# Validate AWS_PROFILE is set
if [[ -z "${AWS_PROFILE:-}" ]]; then
  echo_red "Error: AWS_PROFILE environment variable is not set."
  echo_white "Usage: export AWS_PROFILE='your-profile-name'"
  exit 1
fi

# Check if AWS config file exists
if [[ ! -f "$AWS_CONFIG_FILE" ]]; then
  echo_red "Error: AWS config file not found at: $AWS_CONFIG_FILE"
  exit 1
fi

AWS_CONFIG_VALUES=($(retrieve_aws_config_values "$AWS_PROFILE"))

AWS_SSO_START_URL=${AWS_CONFIG_VALUES[0]}
AWS_REGION=${AWS_CONFIG_VALUES[1]}
AWS_ACCOUNT_ID=${AWS_CONFIG_VALUES[2]}
AWS_ROLE_NAME=${AWS_CONFIG_VALUES[3]}

# Validate that all required config values were found
if [[ -z "$AWS_SSO_START_URL" ]] || [[ -z "$AWS_REGION" ]] || [[ -z "$AWS_ACCOUNT_ID" ]] || [[ -z "$AWS_ROLE_NAME" ]]; then
  echo_red "Error: Could not retrieve all required values from AWS config for profile: $AWS_PROFILE"
  echo_white "Make sure your profile has: sso_start_url, sso_region, sso_account_id, and sso_role_name"
  exit 1
fi

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

	# Extract access token from the SSO cache file
	AWS_SSO_ACCESS_TOKEN=$(jq -r '.accessToken' "$NEWEST_FILE" 2>/dev/null)
	
	if [[ -z "$AWS_SSO_ACCESS_TOKEN" ]] || [[ "$AWS_SSO_ACCESS_TOKEN" == "null" ]]; then
		echo_red "Error: Could not extract access token from SSO cache file."
		echo_white "Try running: aws sso login --profile $AWS_PROFILE"
		exit 1
	fi
	
	# Get temporary credentials from AWS SSO
	if ! AWS_TEMP_CREDENTIAL=$(aws sso get-role-credentials --account-id "$AWS_ACCOUNT_ID" --role-name "$AWS_ROLE_NAME" --access-token "$AWS_SSO_ACCESS_TOKEN" --region "$AWS_REGION" 2>&1); then
		echo_red "Error: Failed to retrieve AWS credentials."
		echo_white "$AWS_TEMP_CREDENTIAL"
		echo_white "Try running: aws sso login --profile $AWS_PROFILE"
		exit 1
	fi

	AWS_ACCESS_KEY_ID=$(echo "$AWS_TEMP_CREDENTIAL" | jq -r '.roleCredentials.accessKeyId')
	AWS_SECRET_ACCESS_KEY=$(echo "$AWS_TEMP_CREDENTIAL" | jq -r '.roleCredentials.secretAccessKey')
	AWS_SESSION_TOKEN=$(echo "$AWS_TEMP_CREDENTIAL" | jq -r '.roleCredentials.sessionToken')
	
	# Validate credentials were extracted successfully
	if [[ -z "$AWS_ACCESS_KEY_ID" ]] || [[ "$AWS_ACCESS_KEY_ID" == "null" ]] || \
	   [[ -z "$AWS_SECRET_ACCESS_KEY" ]] || [[ "$AWS_SECRET_ACCESS_KEY" == "null" ]] || \
	   [[ -z "$AWS_SESSION_TOKEN" ]] || [[ "$AWS_SESSION_TOKEN" == "null" ]]; then
		echo_red "Error: Failed to extract valid credentials from AWS response."
		exit 1
	fi

	echo_green "✓ AWS credentials retrieved successfully"
	echo_white "Access Key ID: ${AWS_ACCESS_KEY_ID:0:20}..." # Show only first 20 chars for security

	ENV_FILE="${ENV_FILE:-.env}"

	# Check if the .env file exists
	if [[ -f "$ENV_FILE" ]]; then
		# Check file permissions
		if [[ ! -w "$ENV_FILE" ]]; then
			echo_red "Error: .env file is not writable: $ENV_FILE"
			exit 1
		fi
		
		# Create backup
		cp "$ENV_FILE" "${ENV_FILE}.backup" || {
			echo_red "Error: Failed to create backup of .env file"
			exit 1
		}

		# Update the .env file with new credentials
		sed -i "s|^AWS_ACCESS_KEY_ID=.*|AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID|" "$ENV_FILE"
		sed -i "s|^AWS_SECRET_ACCESS_KEY=.*|AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY|" "$ENV_FILE"
		sed -i "s|^AWS_SESSION_TOKEN=.*|AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN|" "$ENV_FILE"

		echo_green "✓ $ENV_FILE updated successfully! (backup saved as ${ENV_FILE}.backup)"
	else
		echo_red "Error: .env file does not exist at: $ENV_FILE"
		echo_white "Create a .env file with the following keys:"
		echo_white "  AWS_ACCESS_KEY_ID="
		echo_white "  AWS_SECRET_ACCESS_KEY="
		echo_white "  AWS_SESSION_TOKEN="
		exit 1
	fi
else
	echo_red "Error: No matching SSO cache file found."
	echo_white "This usually means you need to login first."
	echo_white "Run: aws sso login --profile $AWS_PROFILE"
	exit 1
fi
