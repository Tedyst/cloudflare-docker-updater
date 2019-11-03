FROM alpine:3.7

RUN apk add --no-cache bash bind-tools curl jq
CMD /usr/local/bin/cloudflare-update-dns.sh

COPY docker.sh /usr/local/bin/cloudflare-update-dns.sh
