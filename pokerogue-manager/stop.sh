#!/bin/bash

# 1. 인자 확인
FOLDER_NAME=$1
if [ -z "$FOLDER_NAME" ]; then
    echo "사용법: sudo ./stop.sh [폴더명]"
    exit 1
fi

# 2. 경로 및 설정 로드
COMPOSE_FILE="/pokerogue-manager/docker-compose.yml"
CONFIG_FILE="/config/${FOLDER_NAME}/config.env"
DATA_PATH="/data/${FOLDER_NAME}"

# 설정 파일이 없으면 중단
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 에러: ${CONFIG_FILE}이 없습니다. 먼저 설정을 구성해 주세요."
    exit 1
fi

# 프로젝트 이름 추출 (없으면 폴더명 사용)
PROJECT_NAME=$(grep '^PROJECT_NAME=' "$CONFIG_FILE" | cut -d'=' -f2- | tr -d "'\"\r")
if [ -z "$PROJECT_NAME" ]; then
    echo "!!! CRITICAL ERROR: PROJECT_NAME not found!"
    exit 1
fi

SUDO=""
[ "$EUID" -ne 0 ] && SUDO="sudo"

echo "⚠️  [${PROJECT_NAME}] 인스턴스 초기화 (설정 제외 모든 데이터 삭제)"
read -p "정말 ${PROJECT_NAME} 프로젝트의 데이터와 컨테이너를 삭제하시겠습니까? (y/N): " CONFIRM
if [[ $CONFIRM != "y" ]]; then
    echo "작업을 취소합니다."
    exit 1
fi

# 3. Docker 리소스 정리 (컨테이너 + 가상 네트워크 + 익명 볼륨)
echo "🛑 컨테이너 정지 및 도커 리소스 해제 중..."
$SUDO docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down --remove-orphans -v

# 4. 호스트 데이터 폴더 삭제
if [ -d "$DATA_PATH" ]; then
    echo "🗑️  데이터 폴더 삭제 중: ${DATA_PATH}"
    $SUDO rm -rf "$DATA_PATH"
    echo "✅ 데이터 삭제 완료 (설정 파일은 /config/${FOLDER_NAME}에 보존됨)"
else
    echo "ℹ️  삭제할 데이터 폴더가 이미 존재하지 않습니다."
fi

echo "✨ [${PROJECT_NAME}] 정리가 완료되었습니다. 'start.sh'로 즉시 재시작이 가능합니다."
