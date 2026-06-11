# syntax=docker/dockerfile:1.7

# ---------- Build stage ----------
# Use an Elixir image that matches the OTP/Elixir versions used in CI
# (otp-28 / elixir 1.19) on Ubuntu noble for compatibility with the
# runtime image used below. hexpm/elixir publishes 1.19.5 only on Ubuntu.
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.5
ARG UBUNTU_VERSION=noble-20260509.1

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}"
ARG RUNNER_IMAGE="ubuntu:noble"

FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies (Node.js is required by the Svelte/esbuild
# pipeline invoked via `mix assets.deploy`).
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
       build-essential \
       git \
       curl \
       ca-certificates \
       gnupg \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Prepare app directory
WORKDIR /app

# Install Hex + Rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod
# Skip the Burrito cross-platform wrap step when releasing inside the image.
ENV BURRITO_BUILD=false

# Cache deps separately for better layer caching
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/runtime.exs ./config/
RUN mix deps.get --only prod \
  && mix deps.compile

# Copy assets sources and install JS deps
COPY assets/package.json assets/package-lock.json ./assets/
RUN cd assets && npm ci --no-audit --no-fund

# Copy the rest of the application sources
COPY priv ./priv
COPY lib ./lib
COPY assets ./assets
COPY rel ./rel

# Build assets and the release
RUN mix assets.deploy \
  && mix release xtrace --overwrite

# ---------- Runtime stage ----------
FROM ${RUNNER_IMAGE} AS runner

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
       libstdc++6 \
       openssl \
       libncurses6 \
       locales \
       ca-certificates \
       tini \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=4000

WORKDIR /app

# Create a non-root user. Ubuntu noble ships with a default `ubuntu` user
# occupying UID/GID 1000, so remove it first before creating our own.
RUN userdel -r ubuntu 2>/dev/null || true \
  && groupadd --gid 1000 app \
  && useradd --uid 1000 --gid app --shell /bin/bash --create-home app

# Copy the release built in the previous stage
COPY --from=builder --chown=app:app /app/_build/prod/rel/xtrace ./

USER app

# 4000: Phoenix HTTP
# 4369: EPMD (Erlang Port Mapper Daemon)
# 9100: Erlang distribution port (pinned via ERL_AFLAGS in rel/env.sh.eex)
EXPOSE 4000 4369 9100

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/bin/xtrace", "start"]
