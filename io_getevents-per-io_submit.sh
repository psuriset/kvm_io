#!/bin/bash

perf script -i perf_trace_record.data  > perf_trace_record.txt

cat perf_trace_record.txt | grep qemu-kvm | grep " syscalls:" | awk -F' ' '{print $5}' | sed 's/syscalls://g' | sed 's/://g' | grep -v exit | sed 's/sys_enter_io_submit//' > pattern.txt

./extract_pattern.py pattern.txt
