#!/bin/bash
if [ -f /.dockerenv ]; then
    exec > >(tee -i /proc/1/fd/1) 2>&1
fi

export FOLDER_NAME=$1
if [ -z "$FOLDER_NAME" ]; then
    echo "Usage: sudo ./start.sh [folder-name]"
    exit 1
fi

export DOCKER_API_VERSION=$(docker version --format '{{.Server.APIVersion}}')
export CONFIG_PATH="/config/${FOLDER_NAME}"
export DATA_PATH="/data/${FOLDER_NAME}"
SOURCE_DIR="${DATA_PATH}/source"
API_PATH="${DATA_PATH}/api"
COMPOSE_FILE="/pokerogue-manager/docker-compose.yml"
CONFIG_FILE="${CONFIG_PATH}/config.env"

PROJECT_NAME=$(grep '^PROJECT_NAME=' "$CONFIG_FILE" | cut -d'=' -f2- | tr -d "'\"\r")
if [ -z "$PROJECT_NAME" ]; then
    echo "!!! CRITICAL ERROR: PROJECT_NAME not found!"
    exit 1
fi
WEBHOOK_SECRET=$(grep '^WEBHOOK_SECRET=' "$CONFIG_FILE" | cut -d'=' -f2- | tr -d "'\"\r")

SUDO=""
[ "$EUID" -ne 0 ] && SUDO="sudo"

# 1. 시스템 메모리 자동 감지 및 빌드 제한 설정
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -ge 8192 ]; then
    export NODE_MEM_LIMIT=$((TOTAL_RAM * 3 / 4))
else
    export NODE_MEM_LIMIT=4096
fi
echo ">>> System RAM: ${TOTAL_RAM}MB / Assigned Build Memory: ${NODE_MEM_LIMIT}MB"

# 2. [Backend] API 서버 소스 가져오기
if [ ! -d "$API_PATH" ]; then
    echo ">>> Cloning RogueServer (Backend)..."
    $SUDO git clone --depth 1 --shallow-submodules --recursive https://github.com/pagefaultgames/rogueserver.git "$API_PATH"
else
    echo ">>> Updating RogueServer..."
    cd "$API_PATH"
    $SUDO git pull origin master || {
        echo ">>> Standard update failed. Attempting force sync..."; 
        $SUDO git fetch --all && $SUDO git reset --hard origin/master && $SUDO git clean -fd;
    }
    $SUDO git submodule update --init --depth 1 --recursive
    cd - > /dev/null
fi

# 3. [Frontend] 게임 클라이언트 소스 업데이트
SOURCE_REPO=$(grep '^GIT_REPO=' "$CONFIG_FILE" | cut -d'=' -f2- | tr -d "'\"\r")
SOURCE_BRANCH=$(grep '^GIT_BRANCH=' "$CONFIG_FILE" | cut -d'=' -f2- | tr -d "'\"\r")

if [ ! -d "$SOURCE_DIR" ]; then
    echo ">>> Updating Frontend Source..."
    $SUDO mkdir -p "$SOURCE_DIR"
    $SUDO git clone --depth 1 --shallow-submodules --recursive -b "$SOURCE_BRANCH" "$SOURCE_REPO" "$SOURCE_DIR"
else
    echo ">>> Updating Frontend Source..."
    cd "$SOURCE_DIR"
    $SUDO git pull origin "$SOURCE_BRANCH" || {
        echo ">>> Standard update failed. Attempting force sync..."; 
        $SUDO git fetch --all && $SUDO git reset --hard origin/"$SOURCE_BRANCH" && $SUDO git clean -fd;
    }
    $SUDO git submodule update --init --depth 1 --recursive
    cd - > /dev/null
fi

# 4. [Cleanup] 호스트 빌드 결과물 제거
echo ">>> Removing build artifacts from host..."
$SUDO find "$SOURCE_DIR" \( -name "node_modules" -o -name "dist" \) -type d -prune -exec rm -rf '{}' +

# 5. [Optimize] 빌드 환경 설정
echo ">>> Optimizing build environment for ${PROJECT_NAME}..."

# .env.local 또는 .env.MODE.local 복사
MODE=$(grep '^MODE=' "$CONFIG_FILE" | cut -d'=' -f2- | tr -d "'\"\r")
if [ "$MODE" = "development" ] || [ "$MODE" = "app" ]; then
    ENV_SOURCE_FILE="./environment/.env.guest.local"
else
    ENV_SOURCE_FILE="./environment/.env.local"
fi
if [ -f "${SOURCE_DIR}/.env.${MODE}" ]; then
    ENV_TARGET_FILE="${SOURCE_DIR}/.env.${MODE}.local"
else
    ENV_TARGET_FILE="${SOURCE_DIR}/.env.local"
fi
if ! cmp -s "$ENV_SOURCE_FILE" "$ENV_TARGET_FILE"; then
    cp "$ENV_SOURCE_FILE" "$ENV_TARGET_FILE"
fi

# .dockerignore 재생성
DOCKERIGNORE_CONTENT="# .dockerignore
**/.git/
**/node_modules/
*.log
*.md
.gitignore
.env
Dockerfile"
if [ ! -f "${SOURCE_DIR}/.dockerignore" ] || [ "$DOCKERIGNORE_CONTENT" != "$(cat "${SOURCE_DIR}/.dockerignore" 2>/dev/null)" ]; then
    echo "$DOCKERIGNORE_CONTENT" > "${SOURCE_DIR}/.dockerignore"
fi

# 6. [Start] 빌드 및 실행
if [ "$2" == "update" ]; then
    echo ">>> Updating Services for ${PROJECT_NAME} using data from ${FOLDER_NAME}..."
    # 소스 업데이트
    cd "$API_PATH" && $SUDO git pull && cd - > /dev/null
    cd "$SOURCE_DIR" && $SUDO git pull && cd - > /dev/null
    # 컨테이너 리빌드
    $SUDO env PROJECT_NAME="$PROJECT_NAME" \
              DATA_PATH="$DATA_PATH" \
              NODE_MEM_LIMIT="$NODE_MEM_LIMIT" \
              DOCKER_API_VERSION="$DOCKER_API_VERSION" \
          docker compose --env-file "$CONFIG_FILE" -p "$PROJECT_NAME" up -d --build server client
else
    # 기존 컨테이너 정리
    echo ">>> Terminating existing containers for ${PROJECT_NAME}..."
    $SUDO env PROJECT_NAME="$PROJECT_NAME" \
              DATA_PATH="$DATA_PATH" \
          docker compose --env-file "$CONFIG_FILE" -p "$PROJECT_NAME" down --remove-orphans > /dev/null 2>&1
    # 빌드 (또는 리빌드)
    echo ">>> Starting Services for ${PROJECT_NAME} using data from ${FOLDER_NAME}..."
    $SUDO env PROJECT_NAME="$PROJECT_NAME" \
              DATA_PATH="$DATA_PATH" \
              NODE_MEM_LIMIT="$NODE_MEM_LIMIT" \
              DOCKER_API_VERSION="$DOCKER_API_VERSION" \
          docker compose --env-file "$CONFIG_FILE" -p "$PROJECT_NAME" up -d --build
fi
