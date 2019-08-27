#!/usr/bin/env bash

# Author: Basefarm
# Purpose: Utility functions for CodeDeploy scripts

# Wait for yum
function yum_wait() {
  while [ -f /var/run/yum.pid ]
  do
    sleep 2
  done
}

# https://github.com/awslabs/aws-codedeploy-samples/blob/master/load-balancing/elb-v2/common_functions.sh
get_instance_region() {
  if [ -z "$AWS_REGION" ]; then
    AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
      | grep -i region \
      | awk -F\" '{print $4}')
  fi
  echo "$AWS_REGION"
}

get_instance_az() {
  local az=$(/opt/aws/bin/ec2-metadata -z | awk '{print $2}')
  echo "$az"
}

get_fqdn() {
  local hn=$(/opt/aws/bin/ec2-metadata -h | awk '{print $2}')
  echo "$hn"
}

get_hostname() {
  local fqdn=$(get_fqdn)
  local hn=$(echo "$fqdn" | awk --field-separator \. '{ print $1 }')
  echo "$hn"
}

get_instance_id() {
  local id=$(/opt/aws/bin/ec2-metadata -i | awk '{print $2}')
  echo "$id"
}

get_local_ip() {
  local ip=$(/opt/aws/bin/ec2-metadata -o | awk '{print $2}')
  echo "$ip"
}

get_instance_type() {
  local type=$(/opt/aws/bin/ec2-metadata -t | awk '{print $2}')
  echo "$type"
}

# Get all interfaces matching input tag/value
get_tagged_nic_ips() {
  local reg=$(get_instance_region)
  local ips=$(aws ec2 describe-network-interfaces \
    --region "$reg" \
    --filters "Name=tag:$1,Values=$2" \
    --output json --query "NetworkInterfaces[].PrivateIpAddress" |
  python -c 'import json,sys;obj=json.load(sys.stdin);print(";".join(obj))' )
  echo "$ips"
}

# Get value of tag on instance
get_instance_tag_value() {
  local reg=$(get_instance_region)
  local id=$(get_instance_id)
  local val=$(aws ec2 describe-tags --output json --region "$reg" \
    --filters "Name=resource-id,Values=$id" "Name=key,Values=$1" \
    --query "Tags[0].Value" | sed -e 's/"//g')
  echo "$val"
}

# returns ENI ID for available ENI in same AZ matching input tag/value
get_available_eni() {
  local reg=$(get_instance_region)
  local az=$(get_instance_az)
  local id=$(aws ec2 describe-network-interfaces \
    --region "$reg" \
    --filters "Name=status,Values=available" "Name=tag:$1,Values=$2" "Name=availability-zone,Values=$az" \
    --output json --query "NetworkInterfaces[0].NetworkInterfaceId" | grep -o 'eni-[a-z0-9]*')
  echo "$id"
}

# Fetch encrypted SSM param
get_ssm_param() {
  local region=$(get_instance_region)
  local param=$(aws ssm get-parameters --region "$region" --name "$1" --with-decryption --output text \
    --query Parameters[0].Value | sed -e 's/^"//' -e 's/"$//')
  echo "$param"
}

# Get environment name from local file or tag
function get_environment() {

  # Parse local file
  if [ -f /local/basefarm/envir_conf ]; then
    local environment=$(grep ENVIRONMENT /local/basefarm/envir_conf | awk -F= '{print $2}')
  fi

  # Fail over to reading tag
  if [[ -z "${environment// }" ]]; then
    local id=$(/opt/aws/bin/ec2-metadata -i | awk '{print $2}')
    local region=$(get_instance_region)
    local tag=$(aws ec2 describe-tags --output json --region "$region" \
      --filters "Name=resource-id,Values=$id" "Name=key,Values=Environment" \
    --query "Tags[0].Value" | sed -e 's/"//g')
    echo "$tag"
  else
    echo "$environment"
  fi
}

# Get name from local file or tag
function get_name() {

  # Parse local file
  if [ -f /local/basefarm/envir_conf ]; then
    local name=$(grep NAME /local/basefarm/envir_conf | awk -F= '{print $2}')
  fi

  # Fail over to reading tag
  if [[ -z "${name// }" ]]; then
    local id=$(/opt/aws/bin/ec2-metadata -i | awk '{print $2}')
    local region=$(get_instance_region)
    local tag=$(aws ec2 describe-tags --output json --region "$region" \
      --filters "Name=resource-id,Values=$id" "Name=key,Values=Name" \
    --query "Tags[0].Value" | sed -e 's/"//g')
    echo "$tag"
  else
    echo "$name"
  fi
}

# Download artifact from S3 for deployment
function get_artifact() {
  local filepath=$1
  local destination=$2

  # Downloads and overwrites existing file
  aws s3 cp "s3://$CD_BUCKET/$filepath" "$destination"
  if [ $? != 0 ]; then
    echo "Error reading bucket: $CD_BUCKET/$filepath"
    exit 1
  fi
}

# Get right bucket for the environment
function get_bucket() {
  if [ -z "$CD_BUCKET" ]; then
    local bucket=$(get_ssm_param /codedeploy/artifact/bucket)
    CD_BUCKET=$bucket
  fi
  echo "$CD_BUCKET"
}

# backup existing and restore originals from previous backups
backup_config() {
  TIMESTAMP=$(date '+%Y%m%d%H%M%S')
  if [ -f "${1}.backup" ]; then
    mv "$1" "$1-$TIMESTAMP"
    cp "$1.backup" "$1"
  else
    cp "$1" "$1.backup"
  fi
}

AWS_REGION=$(get_instance_region)
CD_BUCKET=$(get_bucket)
