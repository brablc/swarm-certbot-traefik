#!/usr/bin/env bash

source ./config.sh
source ./logger.sh

SERVER_PID=""
EXPORT=0
while read DOMAIN; do
    if [ -d $LE_DIR/live/$DOMAIN ]; then
        continue
    fi
    if [ -f $LE_DIR/failed/$DOMAIN ]; then
        log_warn "$DOMAIN|Skipping domain marked as failed ..."
        continue
    fi

    if [ -z "$SERVER_PID" ]; then
        log_info "Starting http server ..."
        python -m http.server 80 --directory $WEBROOT &
        SERVER_PID=$!
        trap "kill $SERVER_PID" EXIT
        sleep 5
    fi

    FILE="$ACME_PATH/check-${DOMAIN}-$(date +%s)"
    TEST_URL="http://$DOMAIN/$FILE"
    log_info "$DOMAIN|Test challenge accessibility $TEST_URL ..."

    echo "certbot" > $WEBROOT/$FILE
    curl --silent -v --max-time 5 $TEST_URL > /tmp/result
    ERR=$?
    rm -f $WEBROOT/$FILE
    if [ $ERR -ne 0 -o "$(cat /tmp/result)" != "certbot" ]; then
        log_error "$DOMAIN|Domain challenge failed $TEST_URL"
        continue
    fi

    log_info "$DOMAIN|Domain challenge ok, run certbot ..."

    {
        flock 200
        certbot certonly \
            --webroot -w $WEBROOT \
            --non-interactive \
            --agree-tos \
            --no-eff-email \
            --keep-until-expiring \
            -m $CERTBOT_EMAIL \
            --cert-name $DOMAIN \
            -d $DOMAIN > $LE_DIR/failed/$DOMAIN

        CERTBOT_RESULT=$?

    } 200>$LOCK_FILE

    if (( $CERTBOT_RESULT == 0 )); then
        log_info "$DOMAIN|Cerbot ok"
        rm -f $LE_DIR/failed/$DOMAIN
        EXPORT=1
    else
        log_error"$DOMAIN|Cerbot failed read log $LE_DIR/failed/$DOMAIN ."
    fi

done < <(./domains.sh)

if [ $EXPORT = 1 ]; then
    ./export.sh
fi
