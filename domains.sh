#!/usr/bin/env bash

SOCK=/var/run/docker.sock
URL=http://v1.45/services

curl -s --unix-socket $SOCK $URL \
    | jq -r '.[] | select(.Spec.Labels["com.docker.stack.namespace"] != null) | .Spec.Name' \
    | xargs -I {} sh -c "curl -s --unix-socket $SOCK $URL/{} | jq -r '.Spec.Labels[\"certbot.domain\"] | select(.)'" \
    | grep \. | sed 's/,/\n/g'
