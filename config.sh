CERTBOT_EMAIL=${CERTBOT_EMAIL-hostmaster@example.com}

LE_DIR="/etc/letsencrypt"
WEBROOT="/tmp/webroot"
ACME_PATH=".well-known/acme-challenge"
LOCK_FILE="/tmp/certbot.lck"

mkdir -p "$WEBROOT/$ACME_PATH" "$LE_DIR/failed"
echo "ok" > "$WEBROOT/$ACME_PATH/test.txt"
