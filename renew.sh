#!/usr/bin/env bash

source ./config.sh
source ./logger.sh

# A retired domain keeps its certificate here and, being the stalest one, would be
# picked every day and block the renewal of all the others - skip it.
# shellcheck disable=SC2012
DOMAIN=$(ls $LE_DIR/live/*/cert.pem -1tr | awk -F/ '{print $5}' | while read -r TEST_DOMAIN; do
  getent hosts "$TEST_DOMAIN" >/dev/null && echo "$TEST_DOMAIN" && break
done)

if [[ -z $DOMAIN ]]; then
  log_warn "No resolvable live domain found, terminating."
  exit
fi
log_info "Will use $DOMAIN to test challenge accessibility."

log_info "Starting http server ..."
python -m http.server 80 --directory $WEBROOT &
# shellcheck disable=SC2064
trap "kill $!" exit
sleep 5

FILE="$ACME_PATH/check-renew-$(date +%s)"
TEST_URL="http://$DOMAIN/$FILE"
log_info "Test challenge accessibility $TEST_URL ..."

echo "certbot" >"$WEBROOT/$FILE"
curl --silent -v --max-time 5 "$TEST_URL" >/tmp/result
ERR=$?
rm -f "$WEBROOT/$FILE"
if [[ $ERR -ne 0 || "$(cat /tmp/result)" != "certbot" ]]; then
  log_error "Test challenge failed $TEST_URL"
  exit 1
fi

log_info "Calling certbot renew ..."
{
  flock 200
  certbot renew --webroot -w $WEBROOT --non-interactive

  CERTBOT_RESULT=$?

} 200>$LOCK_FILE

if ((CERTBOT_RESULT == 0)); then
  log_info "Cerbot ok."
  ./export.sh
else
  log_error "Cerbot failed."
fi
