#!/bin/bash

. /local/basefarm/cd_utils.sh
LOGFILE="/var/log/app/satis.log"
S3_NAME=$(get_ssm_param "/service/repo/s3_name")

print_log(){
  information=$1
  echo "$(date +'%Y-%m-%d %H:%M:%S') $information" >> "$LOGFILE"
}

print_log "INFO Starting satis build"
if /usr/bin/php /local/app/satis/bin/satis -n build /local/app/packages/satis.json /local/app/packages >> "$LOGFILE" 2>&1; then
  print_log "INFO satis build succeeded"
  print_log "INFO Starting S3 sync"
  if aws s3 sync --quiet --delete /local/app/packages s3://$S3_NAME/ >> "$LOGFILE" 2>&1; then
    print_log "INFO S3 sync succeeded"
  else
    print_log "ERROR s3 sync failed"
  fi
else
  print_log "ERROR satis build failed"
fi
