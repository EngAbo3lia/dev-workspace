# syntax=docker/dockerfile:1.7
#
# Builds the open-source Warp TUI client (warp_tui) and serves it in the browser
# through ttyd. Warp has no supported server edition: the desktop app and the web
# client are both closed backends. This image packages the OSS terminal front-end
# (`warp-tui-oss`), which supports the browser device-authorization login flow.

FROM rust:1.92-bookworm AS build

ARG WARP_REF=ae60375ef1d3895908756878fe4a07cbe703ce1a
ARG CARGO_BUILD_JOBS=4
ARG PROTOC_VERSION=25.1

ENV CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS} \
    CARGO_TERM_COLOR=always \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      git \
      jq \
      libasound2-dev \
      libclang-dev \
      libexpat1-dev \
      libfontconfig1-dev \
      libfreetype-dev \
      libgit2-dev \
      libssl-dev \
      libwayland-dev \
      libxkbcommon-dev \
      pkg-config \
      unzip \
    && rm -rf /var/lib/apt/lists/*

# The repository requires protoc >= 3.15 for proto3 optional fields; the
# distribution package is too old on several bases, so fetch the pinned build.
RUN curl -fsSL -o /tmp/protoc.zip \
      "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip" \
    && unzip -o /tmp/protoc.zip -d /usr/local bin/protoc 'include/*' \
    && rm /tmp/protoc.zip

WORKDIR /src

RUN git init -q . \
    && git remote add origin https://github.com/warpdotdev/warp.git \
    && git fetch -q --depth 1 origin "${WARP_REF}" \
    && git checkout -q --detach FETCH_HEAD

# `standalone` makes bundled_resources_dir() resolve the resources directory that
# sits next to the binary instead of a .app bundle layout.
RUN cargo build --release -p warp_tui --bin warp-tui-oss --features standalone

# Copies bundled skills and generates settings_schema.json through the binary's
# dump-settings-schema subcommand.
RUN NO_LICENSES=1 \
    SETTINGS_SCHEMA_EXECUTABLE=/src/target/release/warp-tui-oss \
    ./script/prepare_bundled_resources /src/target/release/resources oss

FROM debian:bookworm-slim AS runtime

ARG TTYD_VERSION=1.7.7

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      jq \
      less \
      libasound2 \
      libexpat1 \
      libfontconfig1 \
      libfreetype6 \
      libgit2-1.5 \
      libssl3 \
      libwayland-client0 \
      libxkbcommon0 \
      openssh-client \
      procps \
      python3 \
      ripgrep \
      tini \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /usr/local/bin/ttyd \
      "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    && chmod 0755 /usr/local/bin/ttyd

RUN useradd --create-home --uid 1000 --shell /bin/bash warp

COPY --from=build /src/target/release/warp-tui-oss /opt/warp/warp-tui-oss
COPY --from=build /src/target/release/resources /opt/warp/resources
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0755 /usr/local/bin/entrypoint.sh /opt/warp/warp-tui-oss \
    && chown -R warp:warp /home/warp

USER warp

ENV HOME=/home/warp \
    TERM=xterm-256color \
    SHELL=/bin/bash

WORKDIR /workspace

EXPOSE 7681

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
