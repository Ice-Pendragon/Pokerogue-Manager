#!/bin/bash

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then
  echo "이 스크립트는 루트 권한으로 실행해야 합니다."
  echo "사용법: sudo ./update.sh"
  exit 1
fi

# 패키지 및 시스템 유지보수
apt update -y
apt full-upgrade -y
apt autoremove -y
apt clean -y
systemctl daemon-reload

echo "========================================"
echo "업데이트가 완료되었습니다."
if [ -f /var/run/reboot-required ]; then
  echo "시스템 재부팅이 필요합니다."
fi
echo "========================================"
