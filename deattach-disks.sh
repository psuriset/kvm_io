#!/bin/bash
# Detach vdb, vdc virtual disks from VM. 
# Syntax: ./deattach-disks.sh <number_of_vm> <disks with space> 
# Syntax: ./deattach-disks.sh 16 vdb vdc 

nr_vms=$1
disks=`echo $disks | sed -e s/","/" "/g`
for i in `seq 1 $nr_vms`
do
    for j in $disks 
    do
      virsh detach-disk vm$i $j --persistent
    done
done
