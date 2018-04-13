#!/bin/bash
set -o pipefail

# set -x (bash debug) if log level is trace
# https://github.com/osixia/docker-light-baseimage/blob/stable/image/tool/log-helper
log-helper level eq trace && set -x

if [ -z "${MARIADB_HOST}" ]; then
  log-helper error "Error: MARIADB_HOST must be set."
  exit 0
fi

if [ -z "${MARIADB_FROM_DATABASE}" ] || [ -z "${MARIADB_TO_DATABASE}" ]; then
  log-helper error "Error: MARIADB_FROM_DATABASE and MARIADB_TO_DATABASE must be set."
  exit 0
fi

if [ -z "${MARIADB_ROOT_USER}" ] || [ -z "${MARIADB_ROOT_PASSWORD}" ]; then
  log-helper error "Error: MARIADB_ROOT_USER and MARIADB_ROOT_PASSWORD must be set."
  exit 0
fi

MARIADB_SSL_CMD_ARGS=""

if [ "${MARIADB_SSL,,}" == "true" ]; then
  log-helper info "SSL config..."

  # generate a certificate and key with ssl-helper if MARIADB_SSL_CRT_FILENAME and MARIADB_SSL_KEY_FILENAME files don't exists
  # https://github.com/osixia/docker-light-baseimage/blob/stable/image/service-available/:ssl-tools/assets/tool/ssl-helper
  ssl-helper ${MARIADB_SSL_HELPER_PREFIX} "${CONTAINER_SERVICE_DIR}/mariadb-helper/assets/certs/$MARIADB_SSL_CRT_FILENAME" "${CONTAINER_SERVICE_DIR}/mariadb-helper/assets/certs/$MARIADB_SSL_KEY_FILENAME" "${CONTAINER_SERVICE_DIR}/mariadb-helper/assets/certs/$MARIADB_SSL_CA_CRT_FILENAME"

  MARIADB_SSL_CMD_ARGS="--ssl --ssl-ca ${CONTAINER_SERVICE_DIR}/mariadb-helper/assets/certs/$MARIADB_SSL_CA_CRT_FILENAME --ssl-cert ${CONTAINER_SERVICE_DIR}/mariadb-helper/assets/certs/$MARIADB_SSL_CRT_FILENAME --ssl-key ${CONTAINER_SERVICE_DIR}/mariadb-helper/assets/certs/$MARIADB_SSL_KEY_FILENAME --ssl-cipher ${MARIADB_SSL_CIPHER_SUITE}"
fi

MARIADB_CMD_ARGS="-h${MARIADB_HOST} -u${MARIADB_ROOT_USER} -p${MARIADB_ROOT_PASSWORD} ${MARIADB_SSL_CMD_ARGS}"

log-helper info "Creating database ${MARIADB_TO_DATABASE} on host ${MARIADB_HOST}..."
mysqladmin ${MARIADB_CMD_ARGS} create ${MARIADB_TO_DATABASE}

CREATE_CMD_RESULT=$?

if [ $CREATE_CMD_RESULT -eq 255 ]; then
  log-helper info "Database ${MARIADB_TO_DATABASE} already exists."
  exit 0
elif [ $CREATE_CMD_RESULT -eq 0 ]; then
  log-helper info "Database ${MARIADB_TO_DATABASE} created."

  if [ -n "${MARIADB_TO_DATABASE_GRANT_USER}" ]; then
    log-helper info "Grant user ${MARIADB_TO_DATABASE_GRANT_USER} permissions on database ${MARIADB_TO_DATABASE}..."
    mysql ${MARIADB_CMD_ARGS} -e "GRANT ${MARIADB_TO_DATABASE_GRANT_PRIVILEGES} ON \`${MARIADB_TO_DATABASE}\`.* TO '${MARIADB_TO_DATABASE_GRANT_USER}'@'${MARIADB_TO_DATABASE_GRANT_USER_HOST}' ;" ${MARIADB_TO_DATABASE}
  fi

  if [ -n "${MARIADB_FROM_DATABASE_REGEX}" ]; then
    log-helper debug "Use regex ${MARIADB_FROM_DATABASE_REGEX} on ${MARIADB_TO_DATABASE}"

    if ! [[ ${MARIADB_TO_DATABASE} =~ ${MARIADB_FROM_DATABASE_REGEX} ]]; then
      log-helper error "Enable to extract database name."
      exit 1
    else
      MARIADB_FROM_DATABASE="${BASH_REMATCH[1]}${MARIADB_FROM_DATABASE}"
    fi
  fi

  if [ "${MARIADB_FROM_DATABASE}" == "${MARIADB_TO_DATABASE}" ]; then
    log-helper warning "MARIADB_FROM_DATABASE == MARIADB_TO_DATABASE == ${MARIADB_TO_DATABASE} copy aborted."
  else
    log-helper info "Copying database ${MARIADB_FROM_DATABASE} to ${MARIADB_TO_DATABASE}..."
    mysqldump ${MARIADB_CMD_ARGS} --no-create-db --events --triggers --routines --compress ${MARIADB_FROM_DATABASE} | mysql ${MARIADB_CMD_ARGS} ${MARIADB_TO_DATABASE}
  fi

else
  log-helper info "Error."
  exit 1
fi

log-helper info "Done."

exit 0
