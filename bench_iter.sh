#!/bin/bash

user_interrupt(){
    echo -e "\n\nKeyboard Interrupt detected."
    # echo -e "Cleaning up..."
    exit
}

trap user_interrupt SIGINT
trap user_interrupt SIGTSTP

while getopts "h?t:w:c:s:" opt; do
    case "$opt" in
	h|\?)
	    echo "Usage: # $0 [OPTIONS]"
	    echo "Following are optional args, defaults of which are present in script itself.."
	    echo "[-s skim for native/threads; 0/1 resp.]"
	    echo "[-w with/without debugging tools included 1/0 resp. ]"
	    echo "[-t targets (/dev/vdb,/dev/vdb, ...) ]"
	    echo "[-c config name for pbench_fio ]"
	    echo
	    exit 0
	    ;;
	s)  skim_opt=$OPTARG
	    ;;
	t)  targets=$OPTARG
	    ;;
	w)  WITH_TOOL=$OPTARG
	    ;;
	c)  config=$OPTARG
	    ;;	    
    esac
done

if [[ -z $skim_opt ]]; then
    # defaults to Native
    skim_opt=0
fi

if [[ -z $WITH_TOOL ]]; then
    # defaults to Native
    WITH_TOOL=1
fi

if [ $skim_opt -eq 0 ]; then
	# setup type: native
	echo "Running for type: native"
	sleep 1
	bench_ext="_native"
	pr_events="-e syscalls:sys_enter_io_submit -e syscalls:sys_exit_io_submit -e syscalls:sys_enter_io_getevents -e syscalls:sys_exit_io_getevents"
	trace_events="-e io_submit,io_getevents"
	if [[ -z $targets ]]; then
	    targets="/dev/vdb,/dev/vdb"
	fi

	if [[ -z $config ]]; then
	    config="fio_run_native"
	fi

elif [ $skim_opt -eq 1 ]; then
	# setup type: threads (write only)
	echo "Running for type: threads"
	sleep 1
	bench_ext="_threads"
	pr_events="-e syscalls:sys_enter_pwrite64 -e syscalls:sys_exit_pwrite64"
	trace_events="-e pwrite64"
	if [[ -z $targets ]]; then
		targets="/dev/vdc,/dev/vdc"
	fi

	if [[ -z $config ]]; then
	    config="fio_run_native"
	fi

else
	echo "wrong type chosen. Choose either native(0) or threads(1) type with -t option"
	exit 0
fi

BENCH_DIR="`date +"%m-%d-%y-%H-%M-%S"`$bench_ext"
PID=`pgrep qemu-kvm | tail -n 1`
CLIENTS='virbr0-122-84'
echo -e ".....\nqemu-process details:\n`ps -aef| grep qemu-kvm`\n....."

# define fio commands
freshen_up="clear-tools && clear-results && kill-tools && echo 2 > /proc/sys/vm/drop_caches"
fio_cmd="pbench_fio --clients=$CLIENTS --test-types=write  --block-sizes=4 --targets=$targets  --samples=1  --config=$config"

# track io_submit and sys_enter_io_getevents
perf_record_cmd="perf record $pr_events -g --pid=$PID -o perf_record.data"
perf_trace_record_cmd="perf trace record $pr_events -g --pid=$PID -o perf_trace_record.data"
strace_cmd="strace $trace_events -o output_strace -p $PID"
perf_trace_cmd="perf trace $trace_events -o output_perf_trace --pid=$PID"

declare -a debuggers

debuggers=("$perf_record_cmd" "$perf_trace_record_cmd" "$perf_trace_cmd" "$strace_cmd");

cleanup(){
	echo "cleaning up.."
	rm -rf perf.data output op_tmp results_* nohup.out test &>/dev/null
}

start_test(){
	mkdir $BENCH_DIR && cd $BENCH_DIR
	
	echo "registering pbench tool set.."
	register-tool-set &>/dev/null

	# N iterations
	for i in $(seq 1 5)
	do 
		mkdir $i && cd $i
		echo "**********  RUN $i  ***********"
		
		# run fio and save data
		for current in "${debuggers[@]}"
		do
			echo "freshning up; clearing environment";
			$freshen_up &>/dev/null

			if [ $WITH_TOOL -eq 1 ]; then
				echo "Running debugger: $current"
				nohup $current &
				sleep 5;
			fi

			echo "running benchmark now..";
			$fio_cmd > op_tmp;
			echo "finished benchmark";
			
			if [ $WITH_TOOL -eq 1 ]; then
				echo "killing debug tool..";
				pkill strace;
				pkill perf;
			fi

			result_name=$(echo $current | awk -F '-e' '{print $1}' | sed 's/ /_/g');
			tail -n 2 op_tmp > "results_$i_$result_name";
			echo -e "saving results for $result_name\n";
		done
		# back up one BENCH_DIR for new iteration
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
		echo "Min: $(sort -n tmp | head -n1)" >> "$result_name.txt";
		echo "Max: $(sort -n tmp | tail -n1)" >> "$result_name.txt";
		../avg-stddev $(cat tmp) >> "$result_name.txt";
		echo;
	done
	# remove trash
	rm -f */op_tmp tmp
}


cleanup
start_test
generate_stats
