#!/bin/bash

## Usage:
## ./bench_iter.sh <IP of client to run fio on> <
user_interrupt(){
    echo -e "\n\nKeyboard Interrupt detected."
    # echo -e "Cleaning up..."
    exit
}

trap user_interrupt SIGINT
trap user_interrupt SIGTSTP

while getopts "h?t:w:c:s:i:o:b:r:" opt; do
    case "$opt" in
	h|\?)
	    echo "Usage: # $0 [OPTIONS]"
	    echo "Following are optional args, defaults of which are present in script itself.."
	    echo "[-s skim for native/threads; 0/1 resp.]"
	    echo "[-w with/without debugging tools included 1/0 resp. ]"
	    echo "[-t targets (/dev/vdb,/dev/vdb, ...) ]"
	    echo "[-c config name for pbench_fio ]"
	    echo "[-i IP(s) of client to run benchmark on.. ]"
	    echo "[-o results_directory: to store benchmark results to.. ]"
	    echo "[-b bench_directory ..if supplied, overrides -o (/<results_dir>/<bench_dir(s)>).. ]"
	    echo "[-r # of iterations to run, to calculate std-dev.. (N iterations per each debugger; default: 5)"
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
	i)  CLIENTS=$OPTARG
	    ;;
	o)  DIR_SRC=$OPTARG
	    ;;	    
	b)  BENCH_DIR=$OPTARG
	    ;;	    
	r)  ITER=$OPTARG
	    ;;	    
    esac
done

if [[ -z $ITER ]]; then
	ITER=5
fi

if [[ -z $CLIENTS ]]; then
	CLIENTS=127.0.0.1
fi

if [[ -z $DIR_SRC ]]; then
	DIR_SRC="/latency_results"
fi

if [[ -z $skim_opt ]]; then
    # defaults to Native
    skim_opt=0
fi

if [[ -z $WITH_TOOL ]]; then
    # defaults to with debug tool enabled
    WITH_TOOL=1
fi

if [ $skim_opt -eq 0 ]; then
	# setup type: native
	echo "Running for type: native"
	sleep 1
	bench_ext="_native"
	pr_events="-e syscalls:sys_enter_io_submit -e syscalls:sys_exit_io_submit -e syscalls:sys_enter_io_getevents -e syscalls:sys_exit_io_getevents -e kvm:kvm_exit -e kvm:kvm_entry -e kvm:kvm_inj_virq -e syscalls:sys_exit_ppoll -e syscalls:sys_enter_ppoll"
	trace_events="-e io_submit,io_getevents,ppoll"
	if [[ -z $targets ]]; then
	    targets=/dev/vdb
	fi

	if [[ -z $config ]]; then
	    config="analyzer_iodepth:32_type:native_io:aio_run:"
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
	    config="analyzer_iodepth:32_type:threads_io:aio_run:"
	fi

else
	echo "wrong type chosen. Choose either native(0) or threads(1) type with -t option"
	exit 0
fi

if [[ -z $BENCH_DIR ]]; then
	DIR_TAG="`date +"%m-%d-%y-%H-%M-%S"`$bench_ext"
	BENCH_DIR=${DIR_SRC%/}/$DIR_TAG
fi


PID=`pgrep 'qemu-kvm|qemu-system-x86' | tail -n 1`
# TODO: add option to get multiple args as clients (virbr0-xx-xx, virbr0-xx-yy, virbr0-xx-zz, ..)
echo -e ".....\nqemu-process details:\n`ps -aef| egrep 'qemu-kvm|qemu-system-x86_64'`\n....."

ORIG_PATH=$PWD

# define fio commands
freshen_up="clear-tools && clear-results && kill-tools && echo 2 > /proc/sys/vm/drop_caches"

# track io_submit and sys_enter_io_getevents
perf_record_cmd="perf record $pr_events -g --pid=$PID -o perf_record.data"
#perf_trace_record_cmd="perf trace record $pr_events -g --pid=$PID -o perf_trace_record.data"
perf_kvm_record_cmd="perf kvm record $pr_events -g --pid=$PID -o perf_kvm_record.data"
strace_cmd="strace $trace_events -o output_strace -p $PID"
perf_trace_cmd="perf trace $trace_events -o output_perf_trace --pid=$PID"

declare -a debuggers

debuggers=("$perf_record_cmd" "$perf_kvm_record_cmd" "$perf_trace_cmd" "$strace_cmd"); 
# EXTRA: $perf_trace_record_cmd --> doesn't trace kvm events. 

cleanup(){
	echo "cleaning up.."
	rm -f ${DIR_SRC%/}/{perf.data,output,op_tmp,results_*,nohup.out} &>/dev/null
}

start_test(){
	mkdir -p $BENCH_DIR && cd $BENCH_DIR
	echo "Saving results to $BENCH_DIR.."
	echo "registering pbench tool set.."
	register-tool-set &>/dev/null

	# N iterations
	for i in $(seq 1 $ITER)
	do 
		mkdir -p $i && cd $i
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

			result_name=$(echo $current | awk -F '-e' '{print $1}' | sed 's/ /_/g');

			echo "running benchmark now..";
			test_type=write
			fio_cmd="pbench_fio --clients=$CLIENTS --test-types=$test_type  --block-sizes=4 --targets=$targets  --samples=1  --config=$config$i-IOPS:$test_type-debugger:$result_name"
			$fio_cmd > op_tmp;
			echo "finished benchmark";
			
			if [ $WITH_TOOL -eq 1 ]; then
				echo "killing debug tool..";
				pkill strace;
				pkill perf;
			fi

			tail -n 2 op_tmp > "results_"$i"_$result_name";
			echo -e "saving results for $result_name\n";
		done
		# back up one dir for new iteration (1/ 2/ 3/ 4/ ..)
		cd ..
	done
}

generate_stats(){
	echo
	cd $BENCH_DIR
	# calculate stats
	for current in "${debuggers[@]}"
	do
		# echo $PWD
		result_name=$(echo $current | awk -F '-e' '{print $1}' | sed 's/ /_/g');
		echo "Saving stats for $result_name..";
		cat */results_*_$result_name | grep -v 'iteration' | awk -F' ' '{print $2}' | awk -F'[' '{print $1}' > tmp;
		# echo "Mean: $(echo `cat tmp | awk '{s+=$1} END {print s}'`/`wc -l tmp | awk -F' ' '{print $1'}` | bc)";
		# echo "Mean: $(awk '{a+=$1} END{print a/NR}' tmp)";
		echo "Min: $(sort -n tmp | head -n1)" >> "$result_name.txt";
		echo "Max: $(sort -n tmp | tail -n1)" >> "$result_name.txt";
		/usr/local/bin/avg-stddev $(cat tmp) >> "$result_name.txt";
		echo;
	done
	# remove trash
	rm -f */op_tmp tmp
}


cleanup
start_test
generate_stats
