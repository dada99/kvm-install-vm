#!/bin/bash
# if ! [ $# -ge 1 ]; then
#     echo "Usage: $0 <node-name> [ipaddress]"
#     exit 1
# fi

if [ $# -eq 0 ]; then
    echo "Usage: $0 <node-name> [ipaddress]"
    exit 1
elif [ $# -eq 2 ]; then
    echo "Create VM with fixed IP: $2"
else
    echo "Create VM with DHCP IP"    
fi

if [ $# -eq 2 ]; then
    echo "local-hostname: $1 ;local-hostname: $1"
else
    echo "local-hostname: $2 ;local-hostname: $2"
fi    
#echo $#

# if [ $2 != '' ]; then
#    IP = '$2'
#    echo $IP
# fi   