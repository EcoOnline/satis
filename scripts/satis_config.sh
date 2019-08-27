#!/usr/bin/env bash

. /local/basefarm/cd_utils.sh
APP_NAME=$(get_name)

add_logstream(){
  cat <<EOF >/etc/awslogs/config/$APP_NAME.conf
[/var/log/app/$APP_NAME.log]
file = /var/log/app/satis.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = /var/log/app/$APP_NAME.log
EOF

  systemctl restart awslogsd
}

add_logrotate(){
  cat <<EOF > /etc/logrotate.d/"$APP_NAME"-logrotate
/var/log/app/*.log {
  copytruncate
  size 10M
  rotate 10
  missingok
  notifempty
  compress
}
EOF
}

add_key(){
  key=$(get_ssm_param "/service/$APP_NAME/key")
  echo "$key" > /root/.ssh/id_rsa_"$APP_NAME"
  chmod 400 /root/.ssh/id_rsa_"$APP_NAME"

  cat <<EOF > /root/.ssh/config
Host github.com
   HostName github.com
   User git
   Port 22
   IdentityFile /root/.ssh/id_rsa_$APP_NAME
   StrictHostKeyChecking no
EOF
}

add_cron(){
  cat <<EOF > /etc/cron.d/"$APP_NAME"
*/5 * * * * root /usr/bin/flock -w 0 /local/app/satis_build.lock sh /local/app/satis_build.sh
EOF
}

add_logstream
add_logrotate
add_key
add_cron
