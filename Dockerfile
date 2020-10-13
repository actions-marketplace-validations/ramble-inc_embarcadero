FROM alpine

RUN apk update && \
    apk upgrade && \
    apk add --no-cache git

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]