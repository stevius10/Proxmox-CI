#!/usr/bin/env bash
set -eo pipefail

PROJECT_NAME="${PWD##*/}"

# Paths 
PROJECT_DIR="$(pwd)"

DEVELOP_DIR="${DEVELOP_DIR:-"$PROJECT_DIR/local"}"
SETUP_DIR="${SETUP_DIR:-"$PROJECT_DIR/setup"}"
TEMP_DIR="${TEMP_DIR:-"$DEVELOP_DIR/.build"}"

CURRENT_FILE="${1:-setup/tasks/main.yml}"

# Configuration
DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME:-"$PROJECT_NAME-image"}"
DOCKER_CONTAINER_NAME="${DOCKER_CONTAINER_NAME:-"$PROJECT_NAME-container"}"
DOCKER_INIT_WAIT="${DOCKER_INIT_WAIT:-5}"

# Environment 
export DOCKER_DEFAULT_PLATFORM="${DOCKER_DEFAULT_PLATFORM:-linux/arm64}"

###

ROLE_NAME=$(dirname $(dirname "$CURRENT_FILE"))
echo "[$PROJECT_NAME:$PROJECT_DIR] $CURRENT_FILE: $ROLE_NAME"

DOCKERFILE_HASH=$(md5 -q "$DEVELOP_DIR/Dockerfile")
IMAGE_EXISTS=$(docker images -q "$DOCKER_IMAGE_NAME" 2>/dev/null)
STORED_HASH=""
[[ -f ""${TEMP_DIR}/${DOCKER_IMAGE_NAME}.hash"" ]] && STORED_HASH=$(cat "${TEMP_DIR}/${DOCKER_IMAGE_NAME}.hash")

BUILD_NEEDED=false
if [[ -z "$IMAGE_EXISTS" ]] || [[ "$STORED_HASH" != "$DOCKERFILE_HASH" ]]; then
    BUILD_NEEDED=true
    echo "[$PROJECT_NAME:Image] Build"
    docker build -t "$DOCKER_IMAGE_NAME" -f "$DEVELOP_DIR/Dockerfile" "$PROJECT_DIR"
    echo "$DOCKERFILE_HASH" > "${TEMP_DIR}/${DOCKER_IMAGE_NAME}.hash"
    echo "[$PROJECT_NAME:Image] $DOCKER_IMAGE_NAME built successfully"
fi

CONTAINER_ID=$(docker ps -aq --filter "name=$DOCKER_CONTAINER_NAME" 2>/dev/null)
if [[ -n "$CONTAINER_ID" ]]; then
    CONTAINER_RUNNING=$(docker ps -q --filter "id=$CONTAINER_ID" 2>/dev/null)

    if [[ "$BUILD_NEEDED" == "true" ]] || [[ -z "$CONTAINER_RUNNING" ]]; then
        echo "[$PROJECT_NAME:Container] Stop and remove container $DOCKER_CONTAINER_NAME (ID: $CONTAINER_ID)..."
        [[ -n "$CONTAINER_RUNNING" ]] && docker stop "$CONTAINER_ID" >/dev/null
        docker rm "$CONTAINER_ID" >/dev/null
        echo "[$PROJECT_NAME:Container] $DOCKER_CONTAINER_NAME removed"
        CONTAINER_ID=""
    fi
fi

if [[ -z "$CONTAINER_ID" ]]; then
    echo "[$PROJECT_NAME:Container] Start $DOCKER_CONTAINER_NAME"
    CONTAINER_ID=$(docker run -d --privileged \
        --tmpfs /tmp --tmpfs /run \
        -p 8080:8080 -p 80:80 -p 2222:2222 -w "/$PROJECT_NAME" \
        -v "$PROJECT_DIR:/$PROJECT_NAME" \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw --cgroupns=host \
        --name "$DOCKER_CONTAINER_NAME" \
        "$DOCKER_IMAGE_NAME")

    echo "[$PROJECT_NAME:Container] $DOCKER_CONTAINER_NAME $CONTAINER_ID started"
    echo "[$PROJECT_NAME:Container] Wait $DOCKER_INIT_WAIT seconds"
    sleep "$DOCKER_INIT_WAIT"
fi

echo "[$PROJECT_NAME:Ansible] Apply role $ROLE_NAME"
docker exec "$CONTAINER_ID" bash -c "mkdir -p config/.gitea/workflows && cp .gitea/workflows/pipeline.yml config/.gitea/workflows/ && env MOUNT=share cinc-client -l info --local-mode --config-option cookbook_path=. --chef-license accept -o share && cinc-client -l info --local-mode --config-option cookbook_path=. --chef-license accept -o config"
# ANSIBLE_ROLES_PATH="/$SETUP_DIR" -e "architecture=arm64" "$CONTAINER_ID" ansible-playbook -e 'target=127.0.0.1' -c local ".docker/.build/${ROLE_NAME}.yml"

