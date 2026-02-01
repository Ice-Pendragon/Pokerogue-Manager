#!/bin/bash

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "이 스크립트는 루트 권한(sudo)으로 실행해야 합니다."
    echo "사용법: sudo ./shutdown.sh"
    exit 1
fi

# 종료 확인 (실수 방지)
echo "========================================"
echo "  서버 종료 시퀀스 (Shutdown Sequence)  "
echo "모든 서버를 안전하게 보관하고,"
echo "리눅스 시스템을 종료합니다."
echo "========================================"
read -p "정말로 시스템을 종료하시겠습니까? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "작업이 취소되었습니다."
    exit 0
fi

# 종료 시작 후 취소 방지
stty -echo
trap '' SIGINT SIGTERM

# Docker 서비스 종료
echo "Docker 서비스 종료 중..."
systemctl stop docker.socket
systemctl stop docker.service
echo "Docker 서비스 종료 완료."

# 시스템 종료
echo "시스템을 종료합니다."
shutdown -P now
sleep infinity
