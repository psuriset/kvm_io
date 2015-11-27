#!/bin/bash
rm -rf *
config=$1
sample=$2
testtype=$3
block_size=$4
source /opt/pbench-agent/profile
clear-results
kill-tools
clear-tools 
source /opt/pbench-agent/profile 
register-tool-set
unregister-tool --name perf

#Register other tools. 
#register-tool --name blktrace  -- --devices=/dev/nvme1n1p1
#register-tool --name kvmstat
#register-tool --name tcpdump

#Trace example events using perf
#register-tool --name=perf -- --record-opts="record -g --pid=14355 -e kvm:kvm_inj_virq -e kvm:kvm_entry \
# -e kvm:kvm_exit  -e syscalls:sys_enter_ppoll -e syscalls:sys_exit_ppoll  -e syscalls:sys_enter_pread64 \
#-e syscalls:sys_exit_pread64  -e syscalls:sys_enter_preadv -e syscalls:sys_exit_preadv \
#-e syscalls:sys_enter_io_submit -e syscalls:sys_exit_io_submit -e syscalls:sys_enter_io_getevents \
#-e syscalls:sys_exit_io_getevents -e syscalls:sys_enter_pwritev -e syscalls:sys_exit_pwritev \
#-e syscalls:sys_enter_pwrite64 -e syscalls:sys_exit_pwrite64" 

#register-tool --name=perf -- --record-opts="record -g --pid=`pgrep qemu-kvm`  -e syscalls:sys_enter_io_submit \
# -e syscalls:sys_exit_io_submit -e syscalls:sys_enter_io_getevents -e syscalls:sys_exit_io_getevents"

chmod 655 get-vm-hostnames
clients=""; for client in `./get-vm-hostnames | awk '{print $2}'`; do clients="$clients,$client"; done; clients=`echo $clients | sed -e s/^,//`
 
#Register blktrace 
#register-tool --remote=$i --label=kvmguest --name=blktrace -- --devices=/dev/vdb,/dev/vdc ; done
 
for i in `echo $clients | sed -e s/,/" "/g`; do ssh -l $i  'clear-results; kill-tools; clear-tools; source /etc/profile.d/pbench-agent.sh'; done
 
pbench_fio --clients=$clients --test-types=$testtypes  --block-sizes=$block_size --targets=/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb  --samples=$sample  --config=$config

move-results
sleep 10
clear-results
kill-tools
clear-tools 
