#!/bin/bash
firewall-cmd --zone=public --permanent --add-port=8443/tcp
firewall-cmd --reload
/usr/local/bin/send_dcvsessionready_notification.sh >/dev/null 2>&1 &
_username="$(aws secretsmanager get-secret-value --secret-id \
                   Run_DCV_in_Batch --query SecretString  --output text | \
                   jq -r  'keys[0]')"
adduser "${_username}" -G wheel \
 && echo "$(aws secretsmanager get-secret-value --secret-id \
                   Run_DCV_in_Batch --query SecretString --output text | \
          sed 's/\"//g' | sed 's/{//' | sed 's/}//')" | chpasswd
/bin/dcv create-session --owner "${_username}" --user "${_username}" "${_username}session"

