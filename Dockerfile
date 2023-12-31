FROM crystallang/crystal:1.8.2-alpine AS BUILDER

WORKDIR /build/

COPY shard.yml shard.lock .
COPY src src/

ENV CRYSTAL_CACHE_DIR=/root/.cache/crystal

RUN --mount=type=cache,target=/root/.cache/crystal \
  shards build \
  --cross-compile \
  --target=aarch64-linux-musl \
  --production \
  | tee /tmp/build.log \
  && grep '^cc' /tmp/build.log > link.sh

FROM alpine:latest AS LINKER

WORKDIR /build/

RUN apk add --no-cache \
  alpine-sdk \
  gc-dev \
  libevent-static \
  libgcrypt-static \
  libssh-dev \
  openssl-libs-static \
  pcre2-dev \
  yaml-static \
  zlib-static

COPY --from=BUILDER /build/link.sh .
COPY --from=BUILDER /build/bin/ bin/

RUN . link.sh \
  && strip bin/entrypoint

RUN mkdir lib/ \
  && ldd bin/entrypoint | cut -f2 | cut -d' ' -f3 | xargs -I'{}' cp {} lib/

FROM alpine:latest AS ALPINE

RUN apk add --no-cache \
  gc \
  libssh \
  pcre2

COPY --from=LINKER /build/bin/entrypoint /

ENTRYPOINT ["/entrypoint"]

FROM scratch AS MINIMAL

COPY --from=LINKER /build/bin/entrypoint /
COPY --from=LINKER /build/lib/ /lib/

ENTRYPOINT ["/entrypoint"]
