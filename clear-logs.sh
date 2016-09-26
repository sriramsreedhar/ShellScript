#!/bin/bash
#This script copes copies /var/log contents and clears current contents of the file
#Usage : ./clear-logs.sh

cp /var/log/messages /var/log/messages.old

cat /dev/null > /var/log/messages

echo log files copied and cleaned up


exit 0
