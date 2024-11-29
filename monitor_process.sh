#!/bin/bash

# Check if the first argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: \$0 <process_name>"
    exit 1
fi

# The first argument is the name of the process to monitor
PROCESS_NAME=$1
GDB_CMD="../gdb_cmd.txt"

while true; do
    # Check if the specified process is running
    PID=$(pgrep "$PROCESS_NAME")

    if [ -z "$PID" ]; then
        # If the process is not running, sleep for 1 second
        sleep 1
    else
        # If the process is running, generate the core dump in the background
        echo "$PROCESS_NAME is running with PID: $PID"
	if [ ! -f $GDB_CMD ]; then
	    echo "gdb command not exist" && exit 1
	fi    

        gdb -p $PID -x $GDB_CMD

        # Sleep for 3 seconds before checking for the next launch
        echo "Core dump generated. Waiting for 3 seconds..."
        sleep 3
    fi
done
