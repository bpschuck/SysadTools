#!/bin/bash
#
# $Id: addcuser.sh,v 1.4 2014/10/26 21:40:29 bschuck Exp $
# Script to add Conetic Software user
# vim: set ts=4 sw=4:
#

HOMEDIR=
# NFSMOUNT will be set to 1 if we mount /mnthome
NFSMOUNT=0

usage () {

echo -e "Usage: $0 -u UID -l Login -c \"Full Name\" [-d HomeDir]"
echo -e "\t-u\tUID is the numeric userid in the range 1000-1999"
echo -e "\t-l\tLogin to be assigned."
echo -e "\t-c\tUser's full name."
echo -e "\t-d\tHomeDir is the user Home Directory, default is /home/<Login>."

exit 1

}

### Main Script ###

# Script must be executed as root.
if [ "$LOGNAME" != "root" ]; then
	echo -e "ERROR: Script must be executed as root." >&2
	exit 1
fi

while getopts u:l:c:d:h opt
do
	case "$opt" in
		u) USERID=$OPTARG;;
		l) LOGIN=$OPTARG;;
		c) FULLNAME="$OPTARG";;
		d) HOMEDIR=$OPTARG;;
		h) usage;;
		*) usage;;
	esac
done

# Check that USERID and LOGIN are set
if [ -z "$USERID" -o -z "$LOGIN" ]; then
	usage
fi

# Check that USERID is in the required range
if [ $USERID -lt 1000 -o $USERID -ge 2000 ]; then
	usage
fi

# Set HOMEDIR based on -d or default
# Also set temporary NFS mount name since useradd will not automount /home
if [ -z "$HOMEDIR" ]; then
	HOMEDIR="/home/$LOGIN"
	TMPHDIR="/mnthome/$LOGIN"
else
	TMPHDIR="/mnthome/${HOMEDIR##*/}"
fi

# Check that UID is not already in /etc/passwd
if awk -F: '{print $3}' /etc/passwd | grep -wq $USERID ; then
	echo -e "ERROR: User with UID $USERID already in /etc/passwd." >&2
	exit 1
fi

# Check that Login is not already in /etc/passwd
if awk -F: '{print $1}' /etc/passwd | grep -wq $LOGIN ; then
	echo -e "ERROR: User with Login $LOGIN already in /etc/passwd." >&2
	exit 1
fi

# Check that HomeDir is not already another user's $HOME
if awk -F: '{print $6}' /etc/passwd | grep -wq $HOMEDIR ; then
	echo -e "ERROR: User with Home Directory $HOMEDIR already exists." >&2
	exit 1
fi

# All checks passed. Now temporarily mount Autohome NAS
# only if $HOMEDIR does not exist
if [ ! -d "$HOMEDIR" ]; then
	echo -e "Mounting: px12-450r-01.steelrule.com:/nfs/AutoHome /mnthome"
	mount -t nfs -o rw,sync,vers=3,hard,fg,lock,proto=tcp,rsize=32768,wsize=32768 px12-450r-01.steelrule.com:/nfs/AutoHome /mnthome
	if [ $? -ne 0 ]; then
		echo -e "ERROR: Could not mount NFS." >&2
		exit 1
	else
		NFSMOUNT=1
	fi
fi

sleep 1

# Run useradd command
# If $HOMEDIR exists we assume the account was added on the other server
# and there is no need to create the directory.
if [ -d "$HOMEDIR" ]; then
	echo -e "$HOMEDIR exists, useradd will not create."
	MAKEDIR="-M"
else
	echo -e "$HOMEDIR does not exist, useradd will create."
	MAKEDIR="-m -k /etc/skel"
fi
echo -e "Executing: useradd -u $USERID -g conetic -c \"$FULLNAME\" -d \"$TMPHDIR\" $MAKEDIR -s /bin/bash $LOGIN"
useradd -u $USERID -g conetic -c "$FULLNAME" -d "$TMPHDIR" \
 $MAKEDIR -s /bin/bash $LOGIN
if [ $? -ne 0 ]; then
	echo -e "ERROR: Useradd failed." >&2
	[ "$NFSMOUNT" -eq 1 ] && umount /mnthome
	exit 1
fi

sleep 1

# Now change Home Directory
usermod -d "$HOMEDIR" $LOGIN
if [ $? -ne 0 ]; then
	echo "ERROR: Could not change Home Directory for $LOGIN" >&2
	[ "$NFSMOUNT" -eq 1 ] && umount /mnthome
	exit 1
fi

sleep 1

# Unmount temporary NFS mount
echo -e "Unmounting /mnthome"
[ "$NFSMOUNT" -eq 1 ] && umount /mnthome

echo -e "Please wait 10 seconds..."
sync;sync
sleep 10

# Just a quick check of the new user directory
echo -e "Confirming user's $HOME"
ls -ld "$HOMEDIR"
if [ $? -ne 0 ]; then
	echo -e "** NOTICE ** Please reconfirm that $HOME exists."
fi

echo -e "Setting Password for user $LOGIN:"
passwd $LOGIN

exit 0
