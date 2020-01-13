#!/usr/bin/env bash

# Author: Basefarm
# Purpose: Install DataDog Agent
# https://docs.datadoghq.com/agent/versions/upgrade_to_agent_v6/?tab=linux#amazon-linux

. /local/basefarm/cd_utils.sh

DD_API_KEY=$(get_ssm_param "/integration/datadog/apikey")

cat <<EOF > /etc/yum.repos.d/datadog.repo
[datadog]
name=Datadog, Inc.
baseurl=https://yum.datadoghq.com/stable/6/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://yum.datadoghq.com/DATADOG_RPM_KEY.public
       https://yum.datadoghq.com/DATADOG_RPM_KEY_E09422B3.public
EOF

while [ -f /var/run/yum.pid ]; do
  sleep 2
done

yum -y install deltarpm
yum -y install datadog-agent

sed "s/api_key:.*/api_key: $DD_API_KEY/" /etc/datadog-agent/datadog.yaml.example >/etc/datadog-agent/datadog.yaml

systemctl restart datadog-agent.service
