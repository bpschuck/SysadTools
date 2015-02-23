#!/bin/bash
# $Id$
#
# vim: shiftwidth=4 ts=4
# check-p12-exp.sh
# Script to find PKCS12 files to parse and check expiration dates.
# date -f "%b %d %T %Y %Z" "Nov  7 23:59:59 2020 GMT" "+%s"
# NOTE: 02/23/2015 - Script currently assumes all PKCS12 files
#  have the same password protecting the key (sling123)

pkcs12file=

usage () {

	echo "Usage: ${0##*/} [-p Pathname] [-s] [-d] [-t n]"
	echo -e "-p\t\tPath to find PKCS12 (.p12) files. Default /data/config/."
	echo -e "-s\t\tShow warning for all expiring/expired certificates."
	echo -e "\t\tNormally just indicates which HOST:PORT chain contains"
	echo -e "\t\texpiring/expired certficates."
	echo -e "-d\t\tDebug mode."
	echo -e "\t\tExtra output and does not remove files in /tmp."
	echo -e "-t\t\tCheck for expiration within n number of days."
	echo -e "\t\tIf no -t option given, default is 30 days."
	exit 1
}

parse-certs () {
# parse-certs will use openssl x509 to grab information
# from file created in get-certs
rval=0

[ "$DEBUG" ] && echo -e "Current Epoch: $currepoch"
parsefile=$1
startline=$(grep -n 'BEGIN CERTIFICATE' $parsefile | awk -F: '{print $1}')
for lineno in $startline
do
	certsub=$(tail -n +${lineno} ${parsefile} | openssl x509 -noout -subject)
	certedate=$(tail -n +${lineno} ${parsefile} | openssl x509 -noout -enddate | sed -e s/notAfter=//)
	certepoch=$(date -d "$certedate" "+%s")
	if [ "$DEBUG" ]; then
		echo -e "Certificate subject: ${certsub}"
		echo -e "Certificate expiration date: ${certedate}"
		echo -e "Expiration date as epoch: ${certepoch}"
	fi
# Check that expiration date of certificate is not less then 30 days
# (2592000 seconds) from current time. Or DAYS if the -t option was supplied.
	if [ $((certepoch-currepoch)) -le $SECONDS ]; then
		rval=$((rval+1))
		[ "$SHOWCERTS" ] && echo -e "WARNING: Certificate with CN \"${certsub##*/CN=}\" ($pkcs12file) will expire within ${DAYS} days."
	fi
done

return $rval

} # end parse-certs

get-certs () {
# get-certs does a find down the supplied PATHNAME
# Looks for PKCS12 (.p12) files.
# into /tmp/sslcerts-HOST-PORT for further processing

local pathname=$1
local certfile
rv=0

for pkcs12file in $(find $pathname -type f -name '*.p12')
do
	certfile=$(echo $pkcs12file | sed -e 's/^\///' -e 's/\//:/g')
	openssl pkcs12 -in $pkcs12file -clcerts -nokeys -passin pass:sling123 \
	-out /tmp/sslcerts-$certfile 2>/dev/null
#	Check to see if the output has certificates.
#	If not, print out a warning
	numcerts=$(grep -c 'BEGIN CERTIFICATE' "/tmp/sslcerts-$certfile")
	if [ "$numcerts" -eq 0 ]; then
		echo -e "WARNING: No Certificates Found for $pkcs12file."
	else
		parse-certs "/tmp/sslcerts-${certfile}"
		rv=$((rv+$?))
	fi
	[ "$DEBUG" ] || rm -f "/tmp/sslcerts-${certfile}"
done

return $rv

} # end get-certs

### Main Script Starts Here ###

# One argument, filename/path of file containing addresses and ports
# to pull certificates from.

if [ $# -gt 6 ]; then
	usage
fi

SHOWCERTS=
DEBUG=
PATHNAME="/data/config"
DAYS=30

while getopts p:dsht:\? opt
do
	case "$opt" in
		d) DEBUG=1;;
		s) SHOWCERTS=1;;
		p) PATHNAME=$OPTARG;;
		h|\?) usage;;
		t) DAYS=$OPTARG;;
		*) usage;;
	esac
done

# Check to see if pathname exists
if [ ! -d ${PATHNAME} ]; then
	echo -e "Error: ${PATHNAME} does not exist or is not readable." \
	> /dev/stderr
	exit 2
fi

# Check that openssl exists
if [ ! -x "/usr/bin/openssl" ]; then
	echo "Error: /usr/bin/openssl does not exist." > /dev/stderr
	exit 3
fi

# Get the current time as epoch
currepoch=$(date +%s)

# Set SECONDS to number of seconds in DAYS
SECONDS=$((3600*24*DAYS))

# Set ERROR to 0
# If we find expiring certificates we set it to one as the exit code
ERROR=0

# Do a find down the PATHNAME directory tree looking for PKCS12
# files.

get-certs "${PATHNAME}"
if [ $? -ne 0 ]; then
	echo -e "WARNING: Certificates in ${PATHNAME} are due to expire."
	ERROR=99
fi

exit $ERROR
