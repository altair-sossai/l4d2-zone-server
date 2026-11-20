#!/usr/bin/env bash
set -u

build="$1"
root="/home/devops"
folder="${root}/${build}"
game="/home/steam/l4d2/left4dead2"
servers_url="${PLAYSTATS_SERVERS_URL:-https://l4d2.com.br/api/servers}"
server_id="${PLAYSTATS_SERVER_ID:-l4d2-com-br-competitive}"
interval="${DEPLOY_CHECK_INTERVAL:-60}"
deadline=$(( $(date +%s) + ${DEPLOY_MAX_WAIT_HOURS:-48} * 3600 ))

log() {
  echo "$(date '+%F %T') [${build}] $*"
}

players() {
  curl -fsS -m 15 "${servers_url}" | jq -r --arg id "${server_id}" '[.[] | select(.publicId == $id) | if .state == "Online" then .players else 0 end] | first // "unknown"' 2>/dev/null || echo "unknown"
}

newer_build() {
  ls -1 "${root}" | grep -E '^[0-9]+$' | sort -n | tail -n 1
}

empty_since=""

log "Waiting for ${server_id} to be empty before deploying"

while true; do
  if [ ! -d "${folder}" ]; then
    log "The upload folder is gone, nothing to deploy"
    exit 0
  fi

  latest="$(newer_build)"
  if [ -n "${latest}" ] && [ "${latest}" -gt "${build}" ]; then
    log "Build ${latest} is newer, leaving this one"
    rm -rf "${folder}"
    exit 0
  fi

  if [ "$(date +%s)" -gt "${deadline}" ]; then
    log "Gave up: the server was never empty"
    exit 1
  fi

  count="$(players)"

  if [ "${count}" = "0" ]; then
    if [ -n "${empty_since}" ]; then
      break
    fi
    empty_since="$(date +%s)"
    log "The server looks empty, checking again"
  else
    empty_since=""
    log "Players: ${count}"
  fi

  sleep "${interval}"
done

exec 9>"${root}/deploy.lock"
flock 9

log "Deploying"
tar -xzf "${folder}/addons.tar.gz" -C "${game}/addons"
mkdir -p "${game}/bash"
tar -xzf "${folder}/bash.tar.gz" -C "${game}/bash"
tar -xzf "${folder}/cfg.tar.gz" -C "${game}/cfg"
tar -xzf "${folder}/scripts.tar.gz" -C "${game}/scripts"
cp -f "${folder}/host.txt" "${folder}/motd.txt" "${game}/"
dos2unix "${game}"/bash/*.sh > /dev/null 2>&1
chmod +x "${game}"/bash/*.sh
rm -rf "${folder}"
log "Deployed"
