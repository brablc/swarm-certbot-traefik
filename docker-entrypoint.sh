#!/usr/bin/env bash

LOOP_SLEEP=${LOOP_SLEEP-60s}

source ./config.sh
source ./logger.sh

log_info "Using email: $CERTBOT_EMAIL"
log_info "Initial list of domains from certbot.domain labels ..."
./domains.sh

LAST_DATE=$(date +"%Y-%m-%d")

log_info "Entering loop with $LOOP_SLEEP sleep ..."
while true; do
    sleep $LOOP_SLEEP

    NEW_DATE=$(date +"%Y-%m-%d")

    if [[ $LAST_DATE != $NEW_DATE ]]; then
        LAST_DATE=$NEW_DATE
        log_info "New date detected renewing ..."
        ./renew.sh
    else
        ./issue.sh
    fi
done
