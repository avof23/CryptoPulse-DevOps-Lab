# envsetup.sh
export AWS_PROFILE="default"
export AWS_CONFIG_FILE="$HOME/.aws/config"
export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/credentials"
export TF_BACKEND_CONFIG="$(git rev-parse --show-toplevel)/terraform/backend-global.tfvars"
