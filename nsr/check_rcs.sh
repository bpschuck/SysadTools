#!/bin/bash
#
# $Id$
# check_rcs.sh
# vi: set ts=4 sw=4 ai:	#
# Script to check for locked RCS files older than x number of days

DAYS=14
DIRS="/"

usage () {

echo -e "Usage: $0 [-o num] [-d directory]"
echo -e "\t-o num\t\tReport on locked RCS files older than num days old"
echo -e "\t-d directory\tSearch directory instead of /."
echo -e "\t\t\tEnclose multiple directories in quotes."

exit 1

}

### Main Script Starts Here ###

# Options:
# -d	Alternate directories. Default is /
# -o	Report on locked RCS files older than this many days.

while getopts d:o:h opt
do
	case "$opt" in 
		d) DIRS=$OPTARG;;
		o) DAYS=$OPTARG;;
		h) usage;;
		*) usage;;
	esac
done

# Current time EPOCH
TODAY=$(date +%s)

MAXTIME=$((DAYS*86400))

for rcsfile in $(find $DIRS -xdev -type f -name '*,v' 2>/dev/null)
do
	LOCKER=$(rlog -L $rcsfile | grep -i "locked by")
	rv=$?
	if [ $rv -eq 0 ]; then
#		CHANGED=$(stat -f %m -t %s)
		CHANGED=$(stat --printf=%Y $rcsfile)
		TIMELOCKED=$((TODAY-CHANGED))
		DAYSLOCKED=$((TIMELOCKED/86400))
		if [ "$TIMELOCKED" -gt "$MAXTIME" ]; then
			echo "RCS File $rcsfile locked for $DAYSLOCKED days."
		fi
	fi
done

