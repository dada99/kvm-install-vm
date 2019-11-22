#!/bin/bash

## **Updates to this file are now at https://github.com/giovtorres/kvm-install-vm.**
## **This updated version has more options and less hardcoded variables.**

# Define some constants

# Directory to store images
DIR=`pwd`

# Location of cloud image
IMAGE=$DIR/base_image/xenial-server-cloudimg-amd64-disk1-5G.img

# Amount of RAM in MB
MEM=2048

# Number of virtual CPUs
CPUS=1

# Cloud init files
USER_DATA=user-data
META_DATA=meta-data
CI_ISO=$1-cidata.iso
DISK=$1.qcow2
#SECOND_DISK_SIZE=20G

# Bridge for VMs (default on Fedora is virbr0)
BRIDGE=virbr0

#SSH Public key file used to inject into VM
SSH_PUB_KEY_FILE="$DIR/ssh_keys/id_rsa.pub"
DIR=`pwd`
SSH_PUB_KEY_FILE="$DIR/ssh_keys/id_rsa.pub"
while IFS= read -r line
do
  #echo "$line"
  SSH_PUB_KEY="$line"
done < "$SSH_PUB_KEY_FILE"
#echo $SSH_PUB_KEY

# Take one argument from the commandline: VM name
# Take second argment for IP address
# Take third argment for second disk
if [ $# -eq 0 ]; then
    echo "Usage: $0 <node-name> [ipaddress] [second_disk_size]"
    exit 1
elif [ $# -eq 2 ]; then
    echo "Create VM with fixed IP: $2"
elif [ $# -eq 3 ]; then
    echo "Create VM with second disk is size of $3"        
else
    echo "Create VM with DHCP IP on Bridge $BRIDGE"    
fi


# Check if domain already exists
virsh dominfo $1 > /dev/null 2>&1
if [ "$?" -eq 0 ]; then
    echo -n "[WARNING] $1 already exists.  "
    read -p "Do you want to overwrite $1 (y/[N])? " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        virsh destroy $1 > /dev/null
        virsh undefine $1 > /dev/null
    else
        echo -e "\nNot overwriting $1. Exiting..."
        exit 1
    fi
fi

echo $2

# Start clean
rm -rf $DIR/tmp/$1
mkdir -p $DIR/tmp/$1

pushd $DIR/tmp/$1 > /dev/null

    # Create log file
    touch $1.log

    echo "$(date -R) Destroying the $1 domain (if it exists)..."

    # Remove domain with the same name
    virsh destroy $1 >> $1.log 2>&1
    virsh undefine $1 >> $1.log 2>&1

    # cloud-init config: set hostname, remove cloud-init package,
    # and add ssh-key 
    cat > $USER_DATA << _EOF_
#cloud-config

# Hostname management
preserve_hostname: False
hostname: $1
#fqdn: .example.local

# Remove cloud-init when finished with it
#runcmd:
#  - [ apt, -y, remove, cloud-init ]

# Configure where output will go
output: 
  all: ">> /var/log/cloud-init.log"

# configure interaction with ssh server
ssh_svcname: ssh
ssh_deletekeys: True
#ssh_genkeytypes: ['rsa', 'ecdsa']
ssh_genkeytypes: ['rsa']

# Install my public ssh key to the first user-defined user configured 
# in cloud.cfg in the template (which is centos for CentOS cloud images)
ssh_authorized_keys:
  - "$SSH_PUB_KEY"
ssh_pwauth: True
users: 
  - default  #If not set, default user(ubuntu) will not be created
  - name: dada99
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    ssh_authorized_keys:
      - "$SSH_PUB_KEY"
chpasswd:  # If not set, the system will ask you to setup password for default user
  list: |
    ubuntu:passw0rd
  expire: False
bootcmd:
  - ifup ens3  # Bring up ens3 interface manually
  - echo "nameserver 223.5.5.5" >> /etc/resolv.conf
  - echo "$1       $2" >> /etc/hosts
_EOF_


if [ $# -eq 1 ]; then
    echo "local-hostname: $1;local-hostname: $1" > $META_DATA
else
    cat > $META_DATA << _EOF_
instance-id: $1
local-hostname: $1
network-interfaces: |
  iface ens3 inet static
  address $2
  netmask 255.255.255.0
  broadcast 192.168.122.255
  gateway 192.168.122.1
_EOF_

fi   

    

    
    echo "$(date -R) Copying template image..."
    cp $IMAGE $DISK
    

    # Create CD-ROM ISO with cloud-init config
    echo "$(date -R) Generating ISO for cloud-init..."
    genisoimage -output $CI_ISO -volid cidata -joliet -r $USER_DATA $META_DATA &>> $1.log

    echo "$(date -R) Installing the domain and adjusting the configuration..."
    echo "[INFO] Installing with the following parameters:"
    if [ "$3" = "" ]; then
    echo "virt-install --import --name $1 --ram $MEM --vcpus $CPUS --disk     
    $DISK,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom,size=1M--network
    bridge=$BRIDGE,model=virtio --os-type=linux --os-variant=ubuntu16.04 --noautoconsole"
    virt-install --import --name $1 --ram $MEM --vcpus $CPUS --disk \
    $DISK,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom --network \
    bridge=$BRIDGE,model=virtio --os-type=linux --os-variant=ubuntu16.04 --noautoconsole
    else 
      echo "Create second disk for $1"
      qemu-img create -f qcow2 $1-2.qcow2 $3
      echo "virt-install --import --name $1 --ram $MEM --vcpus $CPUS --disk     
      $DISK,format=qcow2,bus=virtio --disk     
      $1-2.qcow2,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom,size=1M--network
      bridge=$BRIDGE,model=virtio --os-type=linux --os-variant=ubuntu16.04 --noautoconsole"
      virt-install --import --name $1 --ram $MEM --vcpus $CPUS --disk \
      $DISK,format=qcow2,bus=virtio --disk \
      $1-2.qcow2,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom --network \
      bridge=$BRIDGE,model=virtio --os-type=linux --os-variant=ubuntu16.04 --noautoconsole
    fi
       

if [ $# -eq 1 ]; then
    echo "Get DHCP IP"
    MAC=$(virsh dumpxml $1 | awk -F\' '/mac address/ {print $2}')
    while true
    do
        IP=$(grep -B1 $MAC /var/lib/libvirt/dnsmasq/$BRIDGE.status | head \
             -n 1 | awk '{print $2}' | sed -e s/\"//g -e s/,//)
        if [ "$IP" = "" ]
        then
            sleep 1
        else
            break
        fi
    done
else
    IP=$2
fi
    # Eject cdrom
    #echo "$(date -R) Cleaning up cloud-init..."
    #virsh change-media $1 hda --eject --config >> $1.log

    # Remove the unnecessary cloud init files
    #rm $USER_DATA $CI_ISO

    echo "$(date -R) DONE. SSH to $1 using $IP with  username 'ubuntu'."

popd > /dev/null
