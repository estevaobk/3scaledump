#!/bin/bash

curl -s https://access.redhat.com/sites/default/files/attachments/3scale-dump.sh > 3scale-dump.sh

chmod +x 3scale-dump.sh

./3scale-dump.sh ${1} ${2}
