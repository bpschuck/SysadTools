#!/bin/bash
#
# create_java_alt.sh
# After setting $JDIR
# will create and execute the update-alternatives command
# that includes any program in .../$JDIR/bin as slaves
# vi: set ts=4 sw=4 ai ic:   

# Example:
# Convert jdk1.8.0_92 to 1080092
# 1 = digit
# .8. = 2 digits with leading zero for 0-9
# .0_ = 1 digit
# 92  = 3 digits with leading zero padding

ALT_COMMAND=
BDIR="/usr/java"
RELMAJ=
RELMIN=
RELUPDATE=
RELBUILD=
PRIORITY=

#### Functions ####

rel_2_priority () {

RELSTRING=$1

RELMAJ=$(echo "${RELSTRING}" | sed -r -e "s/^jdk([0-9])+\..+/\1/")

RELMIN=$(printf "%02d" $(echo "${RELSTRING}" | sed -r -e "s/^jdk[0-9]+\.([0-9]+)\..+/\1/"))

RELUPDATE=\
$(echo "${RELSTRING}" | sed -r -e "s/^jdk[0-9]+\.[0-9]+\.([0-9])_.+/\1/")

RELBUILD=$(printf "%03d" \
$(echo "${RELSTRING}" | sed -r -e "s/^jdk[0-9]+\.[0-9]+\.[0-9]_([0-9]+).*/\1/"))

echo "${RELMAJ}${RELMIN}${RELUPDATE}${RELBUILD}"

}  # End rel_2_priority

#### Main Script ####

# Check that $JDIR is set and matches format jdkN.N.N_NN
if [ -z "${JDIR}" ]; then
	echo -e "ERROR: Must set JDIR before execution" >&2
	exit 1
fi

if [[ ! "${JDIR}" =~ ^jdk[0-9]+\.[0-9]+\.[0-9]_[0-9]+$ ]]; then
	echo -e "ERROR: \$JDIR does not match jdkN.N.N_NN format" >&2
	exit 2
fi

# Check that directory ${BDIR}/${JDIR} exists
if [ ! -d "${BDIR}/${JDIR}" ]; then
	echo -e "ERROR: Directory ${BDIR}/${JDIR} does not exist" >&2
	exit 3
fi

# Create PRIORITY for alternatives command
PRIORITY=$(rel_2_priority "${JDIR}")
echo "${PRIORITY}"

# Create alternatives command in variable ALT_COMMAND
ALT_COMMAND="update-alternatives --install /usr/bin/java java \
${BDIR}/${JDIR}/bin/java ${PRIORITY} $(for file in $(find /usr/java/${JDIR}/bin -maxdepth 1 -type f ! -name java); do echo -en " --slave /usr/bin/${file##*/} ${file##*/} ${file}"; done) $(for file in $(find /usr/java/${JDIR}/man/man1 -maxdepth 1 -type f); do echo -en " --slave /usr/share/man/man1/${file##*/} ${file##*/} ${file}"; done)"

echo "${ALT_COMMAND}"
#${ALT_COMMAND}

exit 0

