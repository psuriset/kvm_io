#!/bin/bash

PID=`pgrep qemu-kvm | tail -n 1`
echo `ps -aef| grep qemu-kvm`

# define client name here, ex: virbr0-xxx-xx
CLIENTS=''

user_interrupt(){
    echo -e "\n\nKeyboard Interrupt detected."
    echo -e "Stopping Task Manager..."
    exit
}

trap user_interrupt SIGINT
trap user_interrupt SIGTSTP

freshen_up="clear-tools && clear-results && kill-tools && echo 2 > /proc/sys/vm/drop_caches"

fio_cmd="pbench_fio --clients=$CLIENTS --test-types=write  --block-sizes=4 --targets=/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb --samples=1  --config=$num-vm-$fs-cache:none-io:native-disk:$disk-fs:$fs-iodepth-N-jobs-L-ioeng:sync-profile:some-run-name-description:$run"

cleanup(){
	echo "cleaning up.."
	rm -f perf.data output op_tmp 
}

start_test(){
	for i in $(seq 1 5)
	do 
		echo "**********  RUN $i  ***********"
			$freshen_up;
			echo "freshning up; clearing environment";
			$fio_cmd > op_tmp;
			echo "finished benchmark";
			tail -n 2 op_tmp > "results_"$i;
			echo "saving results to results_$i";
			echo
		echo
	done
}

start_test
cleanup
