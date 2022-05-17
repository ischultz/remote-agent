#! /usr/bin/env sh

# Function: Print a help message.
usage() {
  echo "Usage: $0 [ -u turbine_url ] [-i docker/image_name:tag]" 1>&2
  echo "" 1>&2
  echo "Arguments:" 1>&2
  echo "  -u https://localhost     The base Turbine URL" 1>&2
  echo "  -i docker/image_name:tag Override the Image/Tag used to pull the Turbine Agent" 1>&2
  echo "  -v                       print the script version" 1>&2
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

logo() {
  echo
  echo "###############################################################################"
  echo "_____              ______ _____"
  echo "__  /____  ___________  /____(_)___________"
  echo "_  __/  / / /_  ___/_  __ \_  /__  __ \  _ \\"
  echo "/ /_ / /_/ /_  /   _  /_/ /  / _  / / /  __/"
  echo "\__/ \__,_/ /_/    /_.___//_/  /_/ /_/\___/"
  echo "###############################################################################"
  echo
  echo "Turbine Agent Updater - v$SCRIPT_VERSION"
  echo
}

###############################################################################
# Configuration Vars
###############################################################################
SCRIPT_VERSION=1.0.0
AGENT_IMAGE_NAME_SANS_VERSION=nexus.swimlane.io:5000/swimlane/turbine-agent
DOCKER_BIN=$(which docker)

###############################################################################
# Script Arguments
###############################################################################
while getopts i:u:v arg; do
  case "${arg}" in
    i)
      AGENT_IMAGE_NAME=${OPTARG}
      ;;
    u)
      TURBINE_ROOT_URL=${OPTARG}
      ;;
    v)
      echo $SCRIPT_VERSION
      exit 0
      ;;
    :)
      echo "$0: Must supply an argument to -$OPTARG." >&2
      exit_abnormal
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit_abnormal
      ;;
  esac
done

logo

###############################################################################
# Validate Inputs
###############################################################################
if [ -z "$TURBINE_ROOT_URL" ]; then
  echo "Please supply a value for the Turbine URL"
  
  printf 'Turbine URL: ' >&2
  read -r TURBINE_ROOT_URL </dev/tty

  if [ -z "$TURBINE_ROOT_URL" ]; then
    exit_abnormal
  fi
fi

if [ -z "$DOCKER_BIN" ]; then
  echo "Unable to locate docker"
  printf 'Docker Path: ' >&2
  read -r DOCKER_BIN </dev/tty

  if [ -z "$DOCKER_BIN" ]; then
    exit_abnormal
  fi
fi

echo
echo

# Query Turbine version
### UNCOMMENT THE NEXT TWO LINES AND REMOVE ME WHEN TURBINE IS VERSIONED WITH PLATFORM ###
#TURBINE_VERSION_URL=${TURBINE_ROOT_URL}/api/settings/version
#TURBINE_VERSION=$(curl -sSL "$TURBINE_VERSION_URL" | sed 's/\+.*//')
TURBINE_VERSION_URL=${TURBINE_ROOT_URL}/turbine/api/v1/settings/initialized
TURBINE_VERSION=$(curl -sSL "$TURBINE_VERSION_URL" | sed -nr 's/.*\"appVersion\":\"([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')

if [ -z "$TURBINE_VERSION" ]; then
  echo "Turbine version could not obtained. Aborting..."
  exit_abnormal
fi

TURBINE_VERSION=v$TURBINE_VERSION
echo "Turbine Version: $TURBINE_VERSION"

# Get Docker Version
DOCKER_VERSION=$(${DOCKER_BIN} -v)

echo "Using Docker found at $DOCKER_BIN"
echo "Docker Version: $DOCKER_VERSION"

# check for image
AGENT_IMAGE_NAME=${AGENT_IMAGE_NAME_SANS_VERSION}:${TURBINE_VERSION}

echo "Checking for ${AGENT_IMAGE_NAME}..."
IMAGE_INFO=$(${DOCKER_BIN} image inspect "${AGENT_IMAGE_NAME}" 2>/dev/null)
if echo "$IMAGE_INFO" | grep -q "^\[\]$"; then
  echo "Agent image not found; pulling image..."
  ${DOCKER_BIN} image pull "${AGENT_IMAGE_NAME}"
  
  IMAGE_INFO=$(${DOCKER_BIN} image inspect "${AGENT_IMAGE_NAME}" 2>/dev/null)
  if echo "$IMAGE_INFO" | grep -q "^\[\]$"; then
    echo "Agent image could not be obtained. Aborting..."
    exit_abnormal
  fi

  echo "Done."
else
  echo "Agent image found."
fi