#!/usr/bin/env bash

LOOP_SLEEP=${LOOP_SLEEP-60s}
CERTBOT_EMAIL=${CERTBOT_EMAIL-hostmaster@example.com}

LE_DIR=/etc/letsencrypt
TRAEFIK_EXPORT=${LE_DIR}/traefik.yml
WEBROOT=/tmp/webroot

mkdir -p $WEBROOT/.well-known/acme-challenge $LE_DIR/failed

function get_domains() {
  docker stack ls --format "{{.Name}}" \
    | xargs -ISTACK docker stack services STACK --format "{{.Name}}" \
    | xargs -ISERVICE docker service inspect SERVICE --format '{{ index .Spec.Labels "certbot.domain"}}' \
    | grep \. | sed 's/,/\n/g'
}

function export_certificates() {
  FILE=$TRAEFIK_EXPORT
  (
    printf "tls:\n  options:\n    default:\n      minVersion: VersionTLS12\n  certificates:\n"
    while read DOMAIN; do
      printf "    # CERT FILE $DOMAIN\n"
      printf "    - certFile: |-\n"
      sed -e 's/^/        /' $DOMAIN/fullchain.pem
      printf "      keyFile: |-\n"
      sed -e 's/^/        /' $DOMAIN/privkey.pem
    done < <(find $LE_DIR/live/ -maxdepth 1 -mindepth 1 -type d -print)
  ) > ${FILE}.new
  mv ${FILE}.new $FILE
}

function run_certbot() {
  SERVER_PID=""
  EXPORT=0
  while read DOMAIN; do
    if [ -d $LE_DIR/live/$DOMAIN ]; then
      continue
    fi
    if [ -f $LE_DIR/failed/$DOMAIN ]; then
      echo "-W|$DOMAIN|Skipping domain marked as failed ..." >&2
      continue
    fi

    if [ -z "$SERVER_PID" ]; then
      echo "-I|Starting http server ..." >&2
      python -m http.server 80 --directory $WEBROOT &
      SERVER_PID=$!
      sleep 5
      echo "-I|Done." >&2
    fi

    FILE=.well-known/acme-challenge/check-${DOMAIN}-$(date +%s)
    TEST_URL="http://$DOMAIN/$FILE"
    echo "-I|$DOMAIN|Test challenge accessibility $TEST_URL ..." >&2

    echo "certbot" > $WEBROOT/$FILE
    curl --silent -v --max-time 5 $TEST_URL > /tmp/result
    ERR=$?
    rm -f $WEBROOT/$FILE
    if [ $ERR -ne 0 -o "$(cat /tmp/result)" != "certbot" ]; then
      echo "-E|$DOMAIN|Domain challenge failed $TEST_URL" >&2
      continue
    fi

    echo "-I|$DOMAIN|Domain challenge ok, run certbot ..."
    certbot certonly \
      --webroot -w $WEBROOT \
      --non-interactive \
      --agree-tos \
      --no-eff-email \
      --keep-until-expiring \
      -m $CERTBOT_EMAIL \
      --cert-name $DOMAIN \
      -d $DOMAIN > $LE_DIR/failed/$DOMAIN
    if [ $? -eq 0 ]; then
      echo "-I|$DOMAIN|Cerbot ok" >&2
      rm -f $LE_DIR/failed/$DOMAIN
      EXPORT=1
    else
      echo "-I|$DOMAIN|Cerbot failed." >&2
    fi

  done < <(get_domains)

  if [ -n "$SERVER_PID" ]; then
    echo "-I|Killing http server ..." >&2
    kill $SERVER_PID
    sleep 5
    echo "-I|Done." >&2
  fi

  if [ $EXPORT = 1 ]; then
    echo "-I|Exporting certificates for traefik ..." >&2
    export_certificates
    echo "-I|Done." >&2
  fi
}


echo "-I|Using email: $CERTBOT_EMAIL"
echo "-I|Initial list of domains from certbot.domain labels ..."
get_domains

echo "-I|Entering loop with $LOOP_SLEEP sleep ..."
while true; do
  run_certbot
  sleep $LOOP_SLEEP
done
