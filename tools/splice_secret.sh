#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
#
# splice_secret.sh (C) 2016 copyright@mzpqnxow.com under GPLv2
# -- please see LICENSE/LICENSE.md for more details on GPLv2
#
# This tool is for purposes of research only. Don't use it to hack stuff. You
# really ought to develop your own tools for that sort of behavior anyway
#
# With that said, I don't highly recommend this for "production" use either,
# something like dropbear is probably better suited to your needs
#
#
# --- Splice Secret ---
#
# This is a utility meant to be used on statically linked tsh/tshd binaries
# for which there is not a toolchain readily available or for which it is just
# a hassle to rebuild tsh/tshd but you prefer to have separate keys for each
# deployment for proper compartmentalization
#
# Because the passphrase (by well documented design) is hardcoded into the server
# this tool, there are risks when deploying on more than one machine. This tool
# just does an overengineered replace of the secret without requiring a user to
# break out the entire SDK/toolchain and recompile the tshd binary
#
# If your build host is non-GNU you can fix the PATH or fix individual binary
# locations below. There are no dependencies here that can really be considered
# third party, it uses entirely standard UNIX shell utilities, for portability.
# The side effect is that it gets a little ugly for something that is essentially
# sed with error checking
#
# --- How to Use tsh When Conducting Research on Obscure Platforms ---
#
# Ideally, one would have one tsh/tshd for every architecture, ABI, endianness,
# OS, kernel version, etc. all statically linked with some libc such as musl
# libc that allows static linking without breaking nsswitch.conf based lookups
# Each of these "golden" copies would have some default password, and it would
# be left in tsh.h. These "golden" copies would not ever actually be used, but
# would serve as templates which would then be modified by this tool, minting
# a new tsh/tshd pair with a randomly generated password into each
#
# For this to work, you will need the following:
#
# 1- A "golden" build of tsh/tshd for the architecture you intend to run tshd on
# 2- The original tsh.h file for these two "golden" build files, or the ability
#    to recreate it (you need the `secret` from tsh.h and it needs to be in the
#    format that I have changed it to- a fixed size character array, initialized
#    at compile time
# 3- The standard shell utilities listed below:
#   - chmod, dd, xxd, mktemp, wc, cut, cat, grep, rm, date, cp, dirname
#
# To use the tool, you would have the "golden" builds named "tsh" and "tshd"
# already built along with the tsh.h header. You would then simply run:
#
# ./splice_password.sh [new passphrase]
#
# It is recommended to leave the first argument blank, in which case the tool
# will generate a base64 encoded string from bytes sourced from /dev/urandom
#
# This should go through the steps of splicing in your new password to both tsh
# and tshd so they can be used without needing to be compiled again. For x86
# and other commodity architectures, this isn't very useful because recompiling
# is trivial and quick. However, for those architectures which require custom
# toolchains and musl libc for basic things like gethostbyname() etc. to work
# correctly, this is a nice timesaver if you would like to have tshd deployed
# on more than one machine and don't want to use the same password, especially
# across different security domains / levels of trust/privilege
#
# Another much easier approach would have been to leave the `secret` symbol in
# at build-time, and use that to identify the `secret` byte, and then strip the
# symbols after, but that has the disadvantage of requiring an a toolchain for
# for the target platform
#
# In case you're not getting it, This is really meant for use on obscure embedded
# devices where you can't rely on standard versions of glibc, uClibc or any other
# libc and you want to use musl libc statically linked executables
#
# I'm sorry that this is poorly written. If you use it as described, you should
# not encounter any problems but if things break, you're on your own.
#
# YMMV
#
# I'll take pull requests but a lot of this cruft was done for specific reasons
#
PATH=/bin:/usr/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/bin

# Specify your path to the GNU versions of these tools if on a non-GNU system
BASE64="$(which base64)"
CAT="$(which cat)"
CHMOD="$(which chmod)"
CP="$(which cp)"
CUT="$(which cut)"
DATE="$(which date)"
DD="$(which dd)"
DIRNAME="$(which dirname)"
GREP="$(which grep)"
MKTEMP="$(which mktemp)"
RM="$(which rm)"
TEE=$(which tee)
WC="$(which wc)"

RANDOMNESS='/dev/urandom'
# RANDOMNESS='/dev/random'

NEW="$(${DATE} +%Y%m%d-%H%m%S)"

TSH=tsh
TSH_H="tsh.h"
TSH_NEW="$TSH.$NEW"
TSHD=tshd
TSHD_NEW="$TSHD.$NEW"

NEW_NOTES="README.$NEW"

ZAP="${RM} -I -rf"
ZERO=/dev/zero

DEPS=(
    "${CAT}"
    "${CHMOD}"
    "${CP}"
    "${CUT}"
    "${DATE}"
    "${DD}"
    "${DIRNAME}"
    "${GREP}"
    "${MKTEMP}"
    "${RM}"
    "${TEE}"
    "${WC}")

"${CHMOD}" 700 .
umask 022

function fatal() {
    exit_msg="${1-UNKNOWN ERROR}"
    exit_code="${2-1}"
    echo
    echo "FATAL: ${exit_msg}"
    exit "${exit_code}"
}

function check_prerequisites() {
    echo '[+] Checking for basic system tools ...'
    for TOOL in "${DEPS[@]}"
    do
        [[ -x "${TOOL}" ]] || fatal "${TOOL} is not found in your PATH" 42
    done
    echo '  [*] Done'
    echo '[+] Checking for prebuilt tsh/tshd and tsh header with secret ...'
    for depend_file in "${TSH}" "${TSHD}" "${TSH_H}"
    do
        [[ -e "${depend_file}" ]] || fatal 'tsh, tshd and tsh.h must be in this directory'
    done
    echo '  [*] Done'
}

function pad_null() {
    TMP_RAW_FILE='pass.raw'
    ARG_INSTRING="$1"
    SECRET_MAXLEN="$2"
    ARG_INSTRING_LEN="$(echo -n "${ARG_INSTRING}" | ${WC} -c)"
    if [ "${ARG_INSTRING_LEN}" -gt "${SECRET_MAXLEN}" ]; then
        fatal "FATAL: Password is too long, must be <= ${SECRET_MAXLEN} bytes !!" 42
    fi
    PAD_BYTES=$((SECRET_MAXLEN - ARG_INSTRING_LEN))
    WORKDIR="$("${MKTEMP}" -p "${PWD}" -d)"
    pushd "$WORKDIR" >/dev/null 2>&1
    echo -n "${ARG_INSTRING}" > "${TMP_RAW_FILE}"
    "${DD}" bs=1 status=none if="${ZERO}" of="${TMP_RAW_FILE}" count="${PAD_BYTES}" conv=notrunc oflag=append || fatal "dd failed in pad_null" 42
    popd >/dev/null 2>&1
    echo "${WORKDIR}/${TMP_RAW_FILE}"
    return
}

function usage() {
    echo "Usage:"
    echo "  $0 <new password>"
    exit 0
}

function main() {
    APPNAME="$0"
    NEW_SECRET="${1-}"

    [[ "${APPNAME}" == "-h" ]] && usage "${APPNAME}"
    [[ $# -gt 2 ]] && usage "${APPNAME}"

    check_prerequisites

    SECRET=$(${CAT} ${TSH_H} | ${GREP} 'char' | ${CUT} -d '"' -f 2)
    echo "[+] Original password in binary was '${SECRET}' ..."

    SECRET_MAXLEN="$(echo "${SECRET}" | ${WC} -c | ${CUT} -d ' ' -f 1)"
    SECRET_MAXLEN=$((SECRET_MAXLEN -1 ))
    echo "[+] Determined from tsh.h a maximum secret size of ${SECRET_MAXLEN} bytes ..."
    
    [[ $# -eq 1 ]] || \
        NEW_SECRET="$("${DD}" bs=1 status=none if=${RANDOMNESS} count=$((SECRET_MAXLEN * 2)) | \
                        cut -c 1-"${SECRET_MAXLEN}" | \
                        ${BASE64} -w 0 | \
                        "${DD}" bs=1 status=none count=${SECRET_MAXLEN})"
    
    [[ ${#NEW_SECRET} -gt SECRET_MAXLEN ]] && fatal "new secret is ${#NEW_SECRET} bytes, maximum length permitted is ${SECRET_MAXLEN} bytes" 42
    echo "[+] Using dynamically generated passphrase '${NEW_SECRET}'"
    PADDED_PASSWORD_FILE="$(pad_null "${NEW_SECRET}" "${SECRET_MAXLEN}")"
    trap "${ZAP} "$("${DIRNAME}" "${PADDED_PASSWORD_FILE}")"; exit" INT EXIT TERM QUIT
    echo "[+] Built a NULL padded buffer of ${SECRET_MAXLEN} bytes containing new password ..."
    SECRET="$(${CAT} ${TSH_H} \
                | ${GREP} 'secret' | \
                ${CUT} -d '"' -f 2)"
    echo "[+] Grabbed the 'base' original password from the header file ..."    
    echo "[+] Making sure base binaries ${TSH} and ${TSHD} were built from this tsh.h file ..."
    "${GREP}" "${SECRET}" ${TSHD} >/dev/null 2>&1 || \
        fatal "password in ${TSH_H} does not match password in ${TSHD} binary. Cannote perform replacement" 42
    "${GREP}" "${SECRET}" ${TSH} >/dev/null 2>&1  || \
        fatal "password in ${TSH_H} does not match password in ${TSH} binary. Cannot perform replacement" 42
    TSH_PASS_OFFSET="$("${GREP}" --byte-offset --only-matching --text "${SECRET}" "${TSH}")" || \
        fatal "${TSH_H} does not seem to match ${TSH} binary ..." 42
    TSH_PASS_OFFSET="$(echo "${TSH_PASS_OFFSET}" | "${CUT}" -d ':' -f 1)"  || \
        fatal "Bad output when parsing grep output from $TSH" 42
    printf "[*] Successfully found secret @ file offset 0x%x in $TSH\n" "${TSH_PASS_OFFSET}"
    
    echo "[+] Performing splice of new password into $TSH_NEW .."
    "${CP}" "${TSH}" "${TSH_NEW}"
    "${DD}" bs=1 status=none if="$PADDED_PASSWORD_FILE" of="${TSH_NEW}" seek="${TSH_PASS_OFFSET}" conv=notrunc || fatal "${DD} failed in tsh new" 42
    echo "  [*] Done, created ${TSH_NEW} for deployment!"
    TSHD_PASS_OFFSET=$(${GREP} --byte-offset --only-matching --text "${SECRET}" ${TSHD}) || \
        fatal "${TSH_H} does not seem to match ${TSHD} binary ..." 42
    TSHD_PASS_OFFSET=$(echo "${TSHD_PASS_OFFSET}" | "${CUT}" -d ':' -f 1) || \
        fatal "Bad output when parsing grep output from ${TSHD}" 42
    printf "[*] Successfully found secret @ file offset 0x%x in $TSHD\n" "${TSHD_PASS_OFFSET}"
    echo "[+] Performing splice of new password into ${TSHD_NEW} .."
    "${CP}" "${TSHD}" "${TSHD_NEW}"
    "${DD}" bs=1 status=none if="${PADDED_PASSWORD_FILE}" of="${TSHD_NEW}" seek="${TSHD_PASS_OFFSET}" conv=notrunc || \
        fatal "${DD} failed in tshd new"
    echo "  [*] Done, created ${TSHD_NEW} for deployment"    
    
    echo "The default password has been changed to the new password on both tsh and tshd"
    echo "The password for $TSH_NEW/${TSHD_NEW} is ${NEW_SECRET}" | "${TEE}" "${NEW_NOTES}"
    echo "Please see $TSH_NEW / ${TSHD_NEW} / $NEW_NOTES"
    echo
    return
}

main "$@"