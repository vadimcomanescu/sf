#!/usr/bin/env bash
set -euo pipefail

: "${SF_RUN_DIR:?SF_RUN_DIR must be set}"

export XDG_DATA_HOME="${XDG_DATA_HOME:-$SF_RUN_DIR/.xdg-data}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$SF_RUN_DIR/.xdg-cache}"
export npm_config_cache="${npm_config_cache:-$SF_RUN_DIR/.npm-cache}"

# pnpm specific
export PNPM_HOME="${PNPM_HOME:-$SF_RUN_DIR/.pnpm-home}"
export PNPM_STORE_DIR="${PNPM_STORE_DIR:-$SF_RUN_DIR/.pnpm-store}"

mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$npm_config_cache" "$PNPM_HOME" "$PNPM_STORE_DIR"
