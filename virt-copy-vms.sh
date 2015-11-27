#!/bin/bash
#Number of VM's to copy nr_vms
vm=master
bridge=virbr0
master_image=master.qcow2
image_path=/var/lib/libvirt/images
nr_vms=$1

for i in `seq $start $nr_vms`; do qemu-img create -b $image_path/$master_image -f qcow2 $image_path/vm$i.qcow2; done

vms=""
for i in `seq 1 $nr_vms`; do
	vm="vm$i"
	virsh dumpxml master | sed -e s/"$master_image"/"$vm.qcow2"/ | sed s/master/$vm/g | grep -v "mac address" | grep -v "uuid" >$vm.xml
	virsh list | grep "$vm " | grep -q running && virsh destroy $vm
	virsh list --all | grep -q "$vm " && virsh undefine $vm
	virsh define $vm.xml
	vms="$vms,$vm"
done
vms=`echo $vms | sed -e s/^,//`
echo vms: $vms
export vms=$vms
