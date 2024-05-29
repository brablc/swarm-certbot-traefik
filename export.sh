#!/usr/bin/env bash

source ./config.sh
source ./logger.sh

TRAEFIK_EXPORT=${LE_DIR}/traefik.yml

log_info "Exporting certificates for traefik ..."

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

log_info "Export done."
