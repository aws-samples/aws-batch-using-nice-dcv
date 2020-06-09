#!/bin/bash

### Setup User
adduser user001 -u 1001
echo "user001:user001" | chpasswd
#echo "user001:$(aws secretsmanager get-secret-value --secret-id \
#                    Run_DCV_in_Batch --query SecretString  --output text | \
#                    jq -r .user001)" | chpasswd
##-> This needs more review. 
# * ideally get users from somewhere else?
# * parse the secret and find the username instead of hardcoding it?
### 

systemctl disable auditd.service
/bin/nvidia-xconfig --enable-all-gpus  --use-display-device="None"  --preserve-busid
systemctl enable dcvserver
systemctl start dcvserver
systemctl enable dcvcreatesessions
exec /usr/sbin/init 5
