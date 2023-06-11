#!/bin/bash

__findWorkDir() {
  ## Get the real script folder path
  # shellcheck disable=SC2164
  cd "$(dirname "$0")"
  script=$(basename "$0")
  # Iterate down a (possible) chain of symlinks
  while [ -L "$script" ]
  do
      script=$(readlink "$script")
      # shellcheck disable=SC2164
      cd "$(dirname "$script")"
      script=$(basename "$script")
  done
  workDir=$(pwd -P)
  # shellcheck disable=SC2164
  cd "$workDir"
}

envsubst() {
  # $1 = Source file path
  # $2 = Destination file path
  if [ "$2" = "" ]; then
    echo "ERR: envsubst function called without parameters"
    exit 1
  fi
  # shellcheck disable=SC2034
  DOLLAR='$'
  cp "$1" "$2"
  # shellcheck disable=SC2086
  sed ${sedFlags} 's/\\/\\\\/g;s/"/\\"/g;s/`/BACKQUOTE/g' "$2"
  # shellcheck disable=SC2086
  sed ${sedFlags} '' "$2"
  # shellcheck disable=SC2086
  eval "echo \"$(cat $2)\"" > "$2"
  # shellcheck disable=SC2086
  sed ${sedFlags} 's/BACKQUOTE/`/g' "$2"
}

__loadConfig() {
  # env.conf is needed
  if [[ ! -f env.conf ]]; then
    echo "ERR: env.conf is missing"
    echo "     Please copy env.sample.conf to env.conf"
    echo "     and update variable values before running launch script"
    exit 1
  fi

  while read -r line
  do
    if [[ "$line" != "" && "$line" =~ = && ! "$line" =~ ^#.* ]]; then
      # shellcheck disable=SC2086
      varName=$(echo $line|awk -F '[=]' '{print $1}')
      # shellcheck disable=SC2001,SC2086
      varValue=$(echo $line|sed "s/^${varName}=//")
      # shellcheck disable=SC2086
      export ${varName}="${varValue}"
    fi
  done <<< "$(cat env.conf)"
}

__validations() {

  osv=$(uname|awk '{ print $1 }')
  if [[ "$osv" == "Darwin" ]]; then
      sedFlags="-i '' "
  else
      sedFlags="-i "
  fi

  # Cleanup exited containers
  # Warn: This will clean non related but exited containers as well.
  # shellcheck disable=SC2046
  docker rm $(docker ps -q -f "status=exited") >/dev/null 2>&1
}

__launchDockerContainers() {
  set -e

  envsubst "docker-compose.yml" ".local-docker-compose.yml"
  if ! /usr/local/bin/docker-compose -f .local-docker-compose.yml -p "${STACK}" up -d; then
    echo "Docker compose command failed"
    exit 1
  else
    echo "Docker compose has launched services. Please check container logs"
  fi
}

# Main

__findWorkDir
__loadConfig
__validations
__launchDockerContainers
