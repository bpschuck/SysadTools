#!/bin/bash
#
# $Id$
# check_rcs.sh
# vi: set ts=4 sw=4 ai:	#
# Script to check for locked RCS files older than x number of days

DAYS=14

### Main Script Starts Here ###

# Current time EPOCH
TODAY=$(date +%s)

MAXTIME=$((DAYS*86400))

for rcsfile in $(find . -type f -name '*,v')
do
	LOCKER=$(rlog -L $rcsfile | grep -i "locked by")
	rv=$?
	if [ $rv -eq 0 ]; then
		CHANGED=$(stat -f %m -t %s)
		TIMELOCKED=$((TODAY-CHANGED))
		DAYSLOCKED=$((TIMELOCKED/86400))
		if [ "$TIMELOCKED" -gt "$MAXTIME" ]; then
			echo "RCS File $rcsfile locked for $DAYSLOCKED days."
		fi
	fi
done

