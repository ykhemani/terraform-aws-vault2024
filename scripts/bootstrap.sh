#!/bin/bash

# logging functions
_log() {
  local type="$1"; shift
  # accept argument string or stdin
  local text="$*"; if [ "$#" -eq 0 ]; then text="$(cat)"; fi
  local dt; dt="$(date --rfc-3339=seconds)"
  printf '%s [%s] [Entrypoint]: %s\n' "$dt" "$type" "$text"
}

_info() {
  _log INFO "$@"
}
_warn() {
  _log WARN "$@" >&2
}
_error() {
  _log ERROR "$@" >&2
  exit 1
}

if [ "$SSH_IMPORT_ID" == "" ]
then
  _error "SSH_IMPORT_ID is not set"
else
  _info "SSH_IMPORT_ID is $SSH_IMPORT_ID"
fi
