FROM certbot/certbot

RUN apk update --no-cache && apk add bash curl jq

WORKDIR /app

COPY *.sh ./
RUN chmod +x *.sh

ENTRYPOINT ["./docker-entrypoint.sh"]
