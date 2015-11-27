#!/bin/bash
#Prepare kickstartfile to $dist-vm.ks and start install
if [ -z $5 ];
        then
                echo "Syntax:  ./virt-install-vm.sh disk_format size vcpu mem dist"
                echo "Syntax:  ./virt-install-vm.sh <qcow2/raw> 10G 2 1024 fedora22"
        exit 1
fi
vm=master
bridge=virbr0
disk_format=$1
size=$2
vcpu=$3
mem=$4
dist=$5

master_image=master.$disk_format
image_path=/var/lib/libvirt/images
yum install -y wget
wget $ks_file $dist-vm.ks
extra="ks=file:/$disk-vm.ks console=ttyS0,115200"
if ! rpm -qa | grep -qw virt-install; then
    yum install -y virt-install 
fi
if [ $dist == "fedora22" ]; then
	location="https://dl.fedoraproject.org/pub/fedora/linux/releases/22/Server/x86_64/os/"
fi

echo deleting master image
/bin/rm -f $image_path/$master_image
echo deleting vm image copies
for i in `seq 1 $nr_vms`; do
	set -x
	/bin/rm -f $image_path/vm*.qcow2
	set +x
done
echo creating new master image
qemu-img create -f $disk_format $image_path/$master_image $size
sync
echo undefining master xml
virsh list --all | grep master && virsh undefine master
echo calling virt-install
virt-install --name=$vm\
	 --virt-type=kvm\
	 --disk format=qcow2,path=$image_path/$master_image\
	 --vcpus=$vcpu\
	 --ram=$mem\
	 --network bridge=$bridge\
	 --os-type=linux\
	 --os-variant=$dist\
	 --graphics none\
	 --extra-args="$extra"\
	 --initrd-inject=$dist-vm.ks\
	 --serial pty\
	 --serial file,path=/tmp/$vm.console\
	 --location=$location\
	 --noreboot
	 #--cdrom=/root/Fedora-Server-DVD-x86_64-22.iso\
