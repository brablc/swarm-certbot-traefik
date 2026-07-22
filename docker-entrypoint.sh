#!/usr/bin/env bash

LOOP_SLEEP=${LOOP_SLEEP-60s}

source ./config.sh
source ./logger.sh

log_info "Using email: $CERTBOT_EMAIL"
log_info "Initial list of domains from certbot.domain labels ..."
./domains.sh

# Kept on the volume so a restart does not skip a renewal the container never ran.
LAST_DATE=$(cat "$LAST_DATE_FILE" 2>/dev/null)
log_info "Last renew attempt: ${LAST_DATE:-never}"

log_info "Entering loop with $LOOP_SLEEP sleep ..."
while true; do
  sleep "$LOOP_SLEEP"

  NEW_DATE=$(date +"%Y-%m-%d")

  if [[ $LAST_DATE != "$NEW_DATE" ]]; then
    LAST_DATE=$NEW_DATE
    echo "$NEW_DATE" >"$LAST_DATE_FILE"
    log_info "New date detected renewing ..."
    ./renew.sh
  else
    ./issue.sh
  fi
done
