#!/bin/bash
# create VM's using create_vm.sh and copy VM's with virt-copy.sh
# Create file systems (ext4, xfs) and mount to respective folders
# /home/ext4, /home/xfs. if disk volume will be attached, create 
# vg using vgcreate disk vg_hdd. 
# For ex: vgcreate /dev/sdc vg_hdd
# ./virt-attach-disk.sh <number of VM's> <fs> <prealloc> <image_format>
# For lvm: image_format not needed. 
# For raw: prealloc=full
# For qcow: prealloc=off/metadata/falloc/full
#./virt-attach-disk.sh 16 ext4 full qcow2

nr_vms=$1
fs=$2
prealloc=$3
img=$4
BASE="/home/$fs"
size=5G

for i in `seq 1 $nr_vms`
do 
    for aio in native threads 
    do
      if [ "$aio" = "native" ]
      then
        vdisk="vdb"
        #cleanup previous disk
        virsh detach-disk vm$i vdb --persistent 
      else
        vdisk="vdc"
        #cleanup previous disk
        virsh detach-disk vm$i vdc --persistent
      fi

      if [ "$fs" = "lvm" ]
      then
         lvcreate -L $size -n lv$i-$aio vg_hdd
         lvpath="/dev/vg_hdd/lv$i-$aio"

         if [ "$prealloc" = "full" ]
         then
            dd if=/dev/zero of=/dev/vg_hdd/lv$i-$aio bs=1024k count=5000
         fi

         #disk xml file
         echo "<disk type='block' device='disk'>" >> $BASE/$aio-disk.xml
         echo "  <driver name='qemu' type='raw' cache='none' io='$aio'/>" >> $BASE/$aio-disk.xml
         echo "  <source dev='$lvpath'/>" >> $BASE/$aio-disk.xml
         echo "  <target dev='$vdisk' bus='virtio'/>" >> $BASE/$aio-disk.xml
         echo "</disk>" >> $BASE/$aio-disk.xml
      else
         if [ "$img" = "qcow2" ]
         then
            imgpath="$BASE/vm$i-$aio.qcow2"
            qemu-img create -f qcow2 $imgpath -o preallocation=$prealloc 5G  

            #disk xml file
            echo "<disk type='file' device='disk'>" >> $BASE/$aio-disk.xml
            echo "  <driver name='qemu' type='qcow2' cache='none' io='$aio'/>" >> $BASE/$aio-disk.xml
            echo "  <source file='$imgpath'/>" >> $BASE/$aio-disk.xml
            echo "  <target dev='$vdisk' bus='virtio'/>" >> $BASE/$aio-disk.xml
            echo "</disk>" >> $BASE/$aio-disk.xml

         else
            imgpath="$BASE/vm$i-$aio.raw"   
            qemu-img create -f raw $imgpath 5G

            if [ "$prealloc" = "full" ]
            then
               dd if=/dev/zero of=$imgpath bs=1024k count=5000
            fi

            #disk xml file
            echo "<disk type='file' device='disk'>" >> $BASE/$aio-disk.xml
            echo "  <driver name='qemu' type='raw' cache='none' io='$aio'/>" >> $BASE/$aio-disk.xml
            echo "  <source file='$imgpath'/>" >> $BASE/$aio-disk.xml
            echo "  <target dev='$vdisk' bus='virtio'/>" >> $BASE/$aio-disk.xml
            echo "</disk>" >> $BASE/$aio-disk.xml
         fi
      fi

    #attach disk
    virsh attach-device vm$i $BASE/$aio-disk.xml --persistent
    rm -rf $BASE/$aio-disk.xml
    done
done
