# swarm-certbot-traefik

[Traefik Proxy](https://doc.traefik.io/traefik/v2.11/) community edition does not really support Let's Encrypt in a serious way for **docker swarm**. If you have multiple instances of traefik with [letsencrypt](https://doc.traefik.io/traefik/https/acme/) support enabled, they would all start to generate same certificates, overwriting `acme.json` storage and exhausting the limits very quickly.

## Functionality

- Dashboard activated with basic authentication.
- Redirect from 80 to 433 with exception of ACME challenge.
- Dynamic loading of generated certificates.
- Challenge webroot gets automatically routed by traefik, but only gets opened when needed.
- Automatic discovery of domains, that require cerificate - use `certbot.domain` label - you can separate multiple domains with commas.

> [!IMPORTANT]
> - This project does not cover renewal yet, I will add it as soon as I will need it, it should be trivial.
> - When certbot fails to generate certificate it would store log into `/etc/letsencrypt/failed/$DOMAIN` - you have to delete it to get another attempt.
> - The setup expects that multiple copies of traefik run on the same node (manager). The assumption with swarm is, that you only have one entry point, because it is not trivial to have your traffic load balanced to multiple public IPs. The most important part is rolling update of traefik service.

Example manager-stack.yml with complete configuration - the dashboard itself is covered by created certificate:

```yml
version: '3.8'

services:

  traefik:
    image: traefik:v2.11
    networks:
      - web
    ports:
      - "80:80"
      - "443:443"
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.role == manager
      update_config:
        delay: 10s
      labels:
        - "traefik.enable=true"
        - "traefik.docker.network=web"
        - "traefik.http.middlewares.auth.basicauth.users=admin:REPLACE-ME-USE_htpassedgenerated-by-htpasswd--nb"
        - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
        - "traefik.http.routers.dashboard.entrypoints=websecure"
        - "traefik.http.routers.dashboard.middlewares=auth"
        - "traefik.http.routers.dashboard.rule=Host(`traefik.example.com`)"
        - "traefik.http.routers.dashboard.service=api@internal"
        - "traefik.http.routers.http-catchall.entrypoints=web"
        - "traefik.http.routers.http-catchall.middlewares=redirect-to-https"
        - "traefik.http.routers.http-catchall.rule=HostRegexp(`{any:.+}`)"
        - "traefik.http.routers.http-catchall.priority=1000"
        - "traefik.http.services.dashboard.loadbalancer.server.port=8080"
        - "certbot.domain=traefik.example.com"
    command:
      - "--log.level=DEBUG"
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.websecure.http.tls=true"
      - "--accesslog=true"
      - "--accesslog.format=json"
      - "--providers.file.filename=/etc/letsencrypt/traefik.yml"
      - "--providers.file.watch=true"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/letsencrypt:/etc/letsencrypt

  certbot:
    image: brablc/swarm-certbot-traefik
    networks:
      - web
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.docker.network=web"
        - "traefik.http.routers.certbot.entrypoints=web"
        - "traefik.http.routers.certbot.rule=PathPrefix(`/.well-known/acme-challenge`)"
        - "traefik.http.routers.certbot.priority=1010"
        - "traefik.http.services.certbot.loadbalancer.server.port=80"
    environment:
      LOOP_SLEEP: 60s
      CERTBOT_EMAIL: hostmaster@example.com
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/letsencrypt:/etc/letsencrypt

networks:
  web:
    external: true
```

## Credits

The code is based on [this proof of concept](https://community.letsencrypt.org/t/how-to-continuously-create-renew-certificates-without-hitting-limits/184562/25) from [@bluepuma77](https://github.com/bluepuma77).
