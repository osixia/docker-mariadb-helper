#!/bin/bash
set -o pipefail

# set -x (bash debug) if log level is trace
# https://github.com/osixia/docker-light-baseimage/blob/stable/image/tool/log-helper
log-helper level eq trace && set -x

if [ -n "${DSN_EXPORT_FILE}" ]; then

  if [ -z "${DSN_EXPORT_VARIABLE_NAME}" ]; then
    log-helper error "Error: DSN_EXPORT_VARIABLE_NAME must be set"
    exit 1
  fi

  mkdir -p "$(dirname "${DSN_EXPORT_FILE}")" && touch "${DSN_EXPORT_FILE}"

  DSN="${DSN_EXPORT_VARIABLE_NAME}=${DSN_USER}:${DSN_PASSWORD}@tcp(${DSN_HOST}:3306)/${DSN_DATABASE}${DSN_ARGS}"

  log-helper debug "Export ${DSN} to ${DSN_EXPORT_FILE}"
  echo "${DSN}" > ${DSN_EXPORT_FILE}
  log-helper info "Done."

fi

exit 0
