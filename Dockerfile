FROM alpine

RUN apk update && \
    apk upgrade && \
    apk add --no-cache git curl jq

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]