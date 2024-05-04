FROM certbot/certbot

RUN apk update --no-cache && apk add bash curl jq

WORKDIR /app

COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh

ENTRYPOINT ["./docker-entrypoint.sh"]
