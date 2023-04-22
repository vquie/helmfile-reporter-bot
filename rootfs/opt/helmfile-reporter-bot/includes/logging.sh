#!/bin/bash
#
# This script will be included / sourced to parent scripts to let logging
# be the same in every script.
#
# Author: Vitali Quiering (vitali@quiering.com)

########################## LOGGING ##########################################

# Log Level
_LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Where to we store our errors temporarily before we return them?
_TMP_ERROR_FILE="/tmp/script-error"

function logMsg() {

	# when running on macOS this will fail, use `$(date)` instead.
	#_DATE=$(date)
	_DATE=$(date +"%Y-%m-%dT%H:%M:%S%z")
	echo "${_DATE} $1"

}

function logErr() {

	[[ "${_LOG_LEVEL_ID}" -ge 2 ]] && logMsg "[ERROR] $1" || return 0

	# after logging the error we need to check if anything was redirected into
	# our temp error file. If yes, we need to log the content and delete the
	# file.
	if [[ -s "${_TMP_ERROR_FILE}" ]]; then

		_MESSAGE=$(tr <"${_TMP_ERROR_FILE}" '\n' ',' | tr -d $'\r')
		rm "${_TMP_ERROR_FILE}"

		logErr "${_MESSAGE}"

	fi

}

function logWarn() {

	[[ "${_LOG_LEVEL_ID}" -ge 3 ]] && logMsg "[WARN] $1" || return 0

}

function logInfo() {

	[[ "${_LOG_LEVEL_ID}" -ge 5 ]] && logMsg "[INFO] $1" || return 0

}

function logDbg() {

	[[ "${_LOG_LEVEL_ID}" -ge 6 ]] && logMsg "[DEBUG] $1" || return 0

}

# parse ${LOG_LEVEL} env variable and set our logging int accordingly
case "${_LOG_LEVEL}" in
ERROR | error)
	_LOG_LEVEL_ID=2
	;;
WARN | warn)
	_LOG_LEVEL_ID=3
	;;
INFO | info)
	_LOG_LEVEL_ID=5
	;;
DEBUG | debug)
	_LOG_LEVEL_ID=6
	;;
*)
	logErr "unknown log level, exiting ..."
	;;
esac
