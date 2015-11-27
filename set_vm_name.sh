nr_vms=$1
#vms=`echo $vms | sed -e s/","/" "/g`; 
for vmnum in `seq 1 $nr_vms` 
do
  mac_eth0=`virsh dumpxml vm$vmnum | grep '<mac' | grep -o '\([0-9a-f][0-9a-f]:\)\+[0-9a-f][0-9a-f]' | sed -n 1p`
  vm_eth0_ip=`arp -an |grep $mac_eth0 | awk '{print $2;}' | tr -d "()"`
  ssh -o StrictHostKeyChecking=no root@$vm_eth0_ip "echo vm$vmnum > /etc/hostname"
  echo $vm_eth0_ip vm$vmnum >> /etc/hosts
done
