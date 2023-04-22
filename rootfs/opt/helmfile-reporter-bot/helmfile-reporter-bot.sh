#!/bin/bash

# helmfile-reporter-bot

# Author: Vitali Quiering (vitali@quiering.com)

set -eu

# default add version
_VERSION=${VERSION:?something went wrong, version missing}

# determine where we are running and where symlinks are pointing to
_SCRIPT="$(basename -- "$0")"
_SCRIPT_DIR="$(readlink -f -- "$0")"
_SCRIPT_HOME="$(dirname -- "${_SCRIPT_DIR}")"

# get the dir the original script is running in for further sourcing
_SCRIPT_HOME="$(dirname "$(readlink -f "$0")")" || true

# init some vars as `false`
_DOCKERIZED=false
_EKS=false
_AWS="${AWS:-false}"
_GITLAB="${GITLAB:-false}"
_GITHUB="${GITHUB:-false}"
_GITEA="${GITEA:-false}"
_KUBE=false

# our kube config file
_KUBECONFIG="${_SCRIPT_HOME}/.kube/config"
_WORKSPACE="${WORKSPACE:-${_SCRIPT_HOME}/tmp}"

# init aws
function initAws() {

	logDbg "function: ${FUNCNAME[0]}"

	_AWS=true

	# aws variables
	_AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
	_AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
	_AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
	_AWS_REGION="${AWS_REGION:-${_AWS_DEFAULT_REGION}}"

}

# init K8s vars
function initK8sVars() {

	logDbg "function: ${FUNCNAME[0]}"

	# kubernetes config
	_KUBE_CONFIG="${KUBE_CONFIG:-}"
	_KUBE_CONTEXT="${KUBE_CONTEXT:-}"

}

# init helmfile vars if provided
function initHelmfile() {

	logDbg "function: ${FUNCNAME[0]}"

	# helmfile config
	_HELMFILE_ENVIRONMENT="${HELMFILE_ENVIRONMENT:-}"
	_HELMFILE_SELECTOR="${HELMFILE_SELECTOR:-}"

}

# init gitlab if provided
function initGitlab() {

	logDbg "function: ${FUNCNAME[0]}"

	_GITLAB=true

	# gitlab config
	_GITLAB_USERNAME="${GITLAB_USERNAME:-}"
	_GITLAB_TOKEN="${GITLAB_TOKEN:-}"

}

# init github if provided
function initGithub() {

	logDbg "function: ${FUNCNAME[0]}"

	_GITHUB=true

	# gitlab config
	_WORKSPACE="${GITHUB_WORKSPACE:-}"

}

# init gitea if provided
function initGitea() {

	logDbg "function: ${FUNCNAME[0]}"

	_GITEA=true

}

########################## LOGGING ##########################################

# Source the logging functions.
_LOG_LEVEL="${LOG_LEVEL:-INFO}"
# shellcheck source=/dev/null
source "${_SCRIPT_HOME}/includes/logging.sh"

#############################################################################

function printEnv() {

	logDbg "function: ${FUNCNAME[0]}"

	logInfo "version: ${_VERSION}"
	logDbg "command: ${_SCRIPT_DIR}"
	logDbg "helmfile: $(helmfile --version)" || true
	logInfo "user: $(whoami)" || true
	logDbg "kernel: $(uname -r)" || true
	logInfo "Docker: ${_DOCKERIZED}"
	logInfo "EKS: ${_EKS}"
	[[ -n "${_KUBE_CONTEXT}" ]] && logInfo "kube-context: ${_KUBE_CONTEXT}"

}

# determine if we are running in docker, failsafe to false
if grep -q containerd /proc/self/cgroup; then
	_DOCKERIZED=true
	_EKS=true
elif [[ -f /.dockerenv ]]; then
	_DOCKERIZED=true
fi

function initK8s() {

	logDbg "function: ${FUNCNAME[0]}"

	initK8sVars

	mkdir -p "$(dirname "${_KUBECONFIG}")" ||
		(logErr "could not create $(dirname "${_KUBECONFIG}")" && return 1)

	echo "${_KUBE_CONFIG}" | base64 -d >"${_KUBECONFIG}" ||
		(logErr "could not create ${_KUBECONFIG}" && return 1)

	chmod 0600 "${_KUBECONFIG}" ||
		(logErr "could not chmod ${_KUBECONFIG}" && return 1)

	_KUBE=true

}

_ENV_RAW=$(env)
_ENV_CUT=$(echo "${_ENV_RAW}" | cut -d= -f1)
_ENV_GREP=$(echo "${_ENV_CUT}" | grep "_")
_ENV_CUT=$(echo "${_ENV_GREP}" | cut -d_ -f1)
_ENV_SORT=$(echo "${_ENV_CUT}" | sort -n)
_ENV_UNIQ=$(echo "${_ENV_SORT}" | uniq)

for _ARG in ${_ENV_UNIQ}; do
	case "${_ARG}" in
	KUBE)
		initK8s
		;;
	HELMFILE)
		initHelmfile
		;;
	AWS)
		initAws
		;;
	GITLAB)
		initGitlab
		;;
	GITHUB)
		initGithub
		;;
	GITEA)
		initGitea
		;;
	*) ;;
	esac
done

printEnv

[[ -n "${_KUBE}" ]] ||
	(logErr "something is wrong with the kubernetes config, exiting" && exit 1)

# export `${KUBECONFIG}` as this is the only way `helm` can use that file
export KUBECONFIG=${_KUBECONFIG}

_REPORT_DIR="${REPORT_DIR:-${_WORKSPACE}/helmfile-report}"
_REPORT_FILENAME="${REPORT_FILENAME:-report.txt}"

mkdir -p "${_REPORT_DIR}" ||
	(logErr "could not create ${_REPORT_DIR}" && exit 1)

logInfo "Starting helmfile command"

cd "${_WORKSPACE}" &&
	helmfile -q --kube-context "${_KUBE_CONTEXT}" diff --suppress-secrets --context 3 >"${_REPORT_DIR}/${_REPORT_FILENAME}"

logInfo "Done"

exit 0
