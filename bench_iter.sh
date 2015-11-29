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

fio_cmd="pbench_fio --clients=$CLIENTS --test-types=write  --block-sizes=4 --targets=/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb,/dev/vdb  --samples=1  --config=$num-vm-$fs-cache:none-io:native-disk:$disk-fs:$fs-iodepth-N-jobs-L-ioeng:sync-profile:some-run-name-description:$run"

# track io_submit and sys_enter_io_getevents
perf_record_cmd="perf record -e syscalls:sys_enter_io_submit -e syscalls:sys_exit_io_submit -e syscalls:sys_enter_io_getevents -e syscalls:sys_exit_io_getevents -g --pid=$PID -o perf_record.data"
perf_trace_record_cmd="perf trace record -e syscalls:sys_enter_io_submit -e syscalls:sys_exit_io_submit -e syscalls:sys_enter_io_getevents -e syscalls:sys_exit_io_getevents -g --pid=$PID -o perf_trace_record.data"
strace_cmd="strace -e io_submit,io_getevents -o output_strace -p $PID"
perf_trace_cmd="perf trace -e io_submit,io_getevents -o output_perf_trace --pid=$PID"

declare -a debuggers

debuggers=("$perf_record_cmd" "$perf_trace_record_cmd" "$perf_trace_cmd" "$strace_cmd");

cleanup(){
	echo "cleaning up.."
	rm -rf perf.data output op_tmp results_* nohup.out test
}

start_test(){
	DIR=`date +"%m-%d-%y-%H-%M-%S"`
	mkdir $DIR && cd $DIR

	# N iterations
	for i in $(seq 1 5)
	do 
		mkdir $i && cd $i
		echo "**********  RUN $i  ***********"
		
		# run fio and save data
		for current in "${debuggers[@]}"
		do
			$freshen_up;
			echo "freshning up; clearing environment";
			nohup $current &
			sleep 5;
			echo "running debug tool now..";
			$fio_cmd > op_tmp;
			echo "finished benchmark";
			pkill strace;
			pkill perf;
			echo "killing debug tool..";
			result_name=$(echo $current | awk -F '-e' '{print $1}' | sed 's/ /_/g');
			tail -n 2 op_tmp > "results_"$i"_"$result_name;
			echo "saving results for $result_name";
			echo
		done
		cd ..
	done
}

generate_stats(){
	echo
	# calculate stats
	for current in "${debuggers[@]}"
	do
		result_name=$(echo $current | awk -F '-e' '{print $1}' | sed 's/ /_/g');
		echo "Saving stats for $result_name..";
		cat */results_*_$result_name | grep -v 'iteration' | awk -F' ' '{print $2}' | awk -F'[' '{print $1}' > tmp;
		# echo "Mean: $(echo `cat tmp | awk '{s+=$1} END {print s}'`/`wc -l tmp | awk -F' ' '{print $1'}` | bc)";
		# echo "Mean: $(awk '{a+=$1} END{print a/NR}' tmp)";
		echo "Min: $(sort -n tmp | head -n1)" >> $result_name".txt";
		echo "Max: $(sort -n tmp | tail -n1)" >> $result_name".txt";
		../avg-stddev $(cat tmp) >> $result_name".txt";
		echo;
	done
	# remove trash
	rm -f */op_tmp tmp
}

cleanup
start_test
generate_stats
