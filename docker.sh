#!/bin/bash

if [ -f ".env" ]; then
    set -o allexport
	source .env
	set +o allexport
fi


function timestamp() {
	date "+%Y-%m-%dT%H:%M:%S%z"
}

function log() {
	echo "$(timestamp)" "$@"
}

function die() {
	log "$@"
	exit 1
}

[ -z "${CFTOKEN}" ] && die "CFTOKEN is required"
[ -z "${CFZONEID}" ] && die "CFZONEID is required"
[ -z "${CFUSERID}" ] && die "CFUSERID is required"
[ -z "${CFHOST}" ] && die "CFHOST is required"

function getRecordID() {
	local record_name="${1}"
	curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONEID/dns_records?name=$record_name" -H "Authorization: Bearer $CFTOKEN" -H "Content-Type: application/json" | jq '.result[0].id' | sed 's/"//g'
}

i=0
for record in ${CFHOST} ; do
	record_names[${i}]="${record}"
	record_ids[${i}]="$(getRecordID "${record}")"
	echo ${record_names[${i}]}
	echo ${record_ids[${i}]}
	((i++))
done

function setRecordIP() {
	local record_name="${1}"
	local record_identifier="${2}"
	local ip="${3}"
	curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONEID/dns_records/$record_identifier" -H "Authorization: Bearer $CFTOKEN" -H "Content-Type: application/json" --data "{\"id\":\"$CFZONEID\",\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\"}"
}

oldip=""
function main() {
	local ip
	ip="$(curl -s https://api.ipify.org/)"
	if [ "${ip}" == "${oldip}" ] ; then
		log "skip update ${CFHOST} with the same IP ${ip}"
		return 0
	fi
	local i
	local update
	for i in "${!record_ids[@]}" ; do
		log "set ${record_names[${i}]} IP to ${ip}"
		update="$(setRecordIP "${record_names[${i}]}" "${record_ids[${i}]}" "${ip}")"
		[ "$(echo "${update}" | jq '.success')" != "true" ] && die "${update}"
	done
	oldip="${ip}"
	return 0
}

[ -z "${CFINTERVAL}" ] && main && echo "Exited since CFINTERVAL not set." && exit 0

while true; do
	main
	sleep "$CFINTERVAL"
done