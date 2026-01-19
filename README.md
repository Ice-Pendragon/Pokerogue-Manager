# 저작권

본 프로젝트는 **AGPL-3.0 (GNU Affero General Public License v3.0)** 을 준수합니다.

* **출처 고지**: 이 패키지는 [rogueserver](https://github.com/pagefaultgames/rogueserver)의 소스 코드를 일부 포함하거나 이를 기반으로 제작되었습니다.
* **공개 의무**: AGPL-3.0 라이선스 규정에 따라, 본 소프트웨어를 수정하거나 이를 활용하여 네트워크 서비스를 제공하는 경우, 반드시 전체 소스 코드를 동일한 라이선스로 공개해야 합니다.
* **비상업적 이용**: 라이선스 규정을 준수하는 범위 내에서 자유로운 재배포 및 수정이 가능합니다.
---
# 디렉토리 구조 및 파일 작성
먼저 리눅스 서버 컴퓨터에 아래 폴더 구조대로 파일들을 업로드해 두세요. (우분투도 무방합니다.)
```Plaintext
/                             # 시스템 루트 경로
├── pokerogue-manager/        # [관리용 파일 모음]
│   ├── environment/
│   │   ├── .env.local
│   │   └── .env.guest.local
│   ├── nginx/
│   │   └── default.conf
│   ├── webhook/
│   │   ├── Dockerfile
│   │   └── hooks.json
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── start.sh
│   └── stop.sh
└── config/
    └── server1/              # [폴더명] 서버 식별자
        └── config.env        # [각 서버 설정]
```
# 작업 실행 순서
## 1. 서버 초기화 및 필수 프로그램 설치
```Bash
# 패키지 업데이트 및 git, curl 설치
sudo apt-get update && sudo apt-get install -y git curl

# Docker 설치
curl -fsSL https://get.docker.com | sh
```
## 2. 파일 업로드 및 배치
FTP나 SCP 등을 이용해 로컬에서 만든 `pokerogue-manager` 폴더와 `config` 폴더를 서버의 홈 디렉토리(예: `/home/user`)에 업로드하세요.

그 다음, 이 폴더들을 시스템 루트 경로(`/`)로 옮깁니다.
```Bash
# 업로드한 폴더를 루트 경로로 이동 (만약 홈 디렉토리에 업로드했다면)
sudo mv ~/pokerogue-manager /pokerogue-manager
sudo mv ~/config /config

# /data 폴더는 자동으로 만들어지지만, 권한 문제를 위해 미리 생성
sudo mkdir -p /data
```
## 3. 파일 권한 설정 (최초 1회)
```Bash
# 실행 스크립트에 권한 부여
sudo chmod +x /pokerogue-manager/start.sh /pokerogue-manager/stop.sh
```
## 4. 스왑(Swap) 메모리 설정 (최초 1회)
```Bash
# [1] 스왑 메모리 설정 (4GB 할당)
echo ">>> Checking Swap status..."

if [ -e /swapfile ]; then
    # 현재 파일의 KB 용량 추출
    CURRENT_SWAP_KB=$(du -k /swapfile | cut -f1)
    
    if [ "$CURRENT_SWAP_KB" -lt "$((4 * 1024 * 1024))" ]; then
        echo ">>> Resizing swap file to 4GB..."
        sudo swapoff /swapfile
        sudo fallocate -l 4G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
    else
        echo ">>> Swap file is sufficient ($((CURRENT_SWAP_KB/1024))MB). Skipping."
    fi
else
    echo ">>> Creating 4GB Swap file..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
fi
grep -q "/swapfile" /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# [2] 파일 핸들 제한 확장 (8192 -> 524288)
sudo sysctl -w fs.inotify.max_user_watches=524288 vm.swappiness=10
grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf || echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf
grep -q "vm.swappiness" /etc/sysctl.conf || echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# [3] 설정 즉시 적용
sudo sysctl -p
```
## 5. 서버 실행
```Bash
sudo /pokerogue-manager/start.sh server1
```
* `config` 하위 폴더 이름이 `server1`이 아니라면, 그 폴더의 이름을 입력하세요.
* 다수의 서버를 운용하는 경우, 실행시킬 서버의 설정 파일이 위치한 폴더의 이름을 입력하세요.
# 확인 작업 순서
## 1. 실행 상태 확인
`Created`된 컨테이너들이 실제로 `Up`(실행 중) 상태로 전환되었는지 확인해야 합니다.

터미널에 입력하세요:
```Bash

sudo docker ps
```
* **성공:** 5개의 컨테이너(`server`, `db`, `client`, `watchtower`, `updater`)가 보이고, STATUS가 `Up ... seconds` 또는 `Up ... minutes` 로 되어 있어야 합니다.
* **실패:** 만약 아무것도 안 보이거나, `Restarting` 또는 `Exited`라고 뜨면 실패입니다.
## 2. 접속 가능 여부 확인
컨테이너가 `Up` 상태라면, 브라우저로 접속 가능 여부를 확인하세요.
* **접속:** `http://[서버주소]:[GAME_PORT]`
   * `GAME_PORT`는 각 인스턴스의 `config.env`에 정의된 포트입니다.
   * 이 값이 `80`이면 그대로 `http://[서버주소]`로 접속해도 무방합니다.
* **가입:** 게임 로딩이 끝나면 `Register`를 눌러 첫 번째 계정을 만듭니다.
* **확인:** 로그인 후 `M` (메뉴) 키를 눌렀을 때, 하단에 **\[관리자\]** 메뉴가 있는지 확인합니다.
## 3. 웹훅 문단속 확인
마지막으로 보안 점검입니다.
* 브라우저 새 탭에 주소 입력: `http://[서버주소]:[WEBHOOK_PORT]/hooks/update`
   * `WEBHOOK_PORT`는 각 인스턴스의 `config.env`에 정의된 포트입니다.
* 화면에 `Hook rules were not satisfied` 같은 에러 메시지가 뜨면 성공입니다.

이 3가지가 모두 확인되면, 포켓로그 서버 구축은 성공입니다.

---
# 서버 운영 및 사후 관리
서버 설치 완료 후, 안정적인 운영과 최신 버전 유지를 위한 관리 방법입니다.
## 1. 주요 관리 명령어 (상태 확인)
프로젝트가 정상적으로 작동하고 있는지 확인하는 가장 기본적인 명령어들입니다.
* **전체 컨테이너 상태 확인**: 현재 실행 중인 모든 서버 인스턴스를 확인합니다.
    ```bash
    sudo docker ps
    ```
* **실시간 게임 서버 로그 확인**: 특정 서버의 작동 상태나 에러를 모니터링합니다.
    ```bash
    # [PROJECT_NAME]은 config.env에 설정한 이름입니다.
    sudo docker logs -f [PROJECT_NAME]-server
    ```
* **디스크 사용량 확인**: 도커 이미지 및 캐시가 차지하는 용량을 점검합니다.
    ```bash
    sudo docker system df
    ```
## 2. 자동 업데이트 설정 방법 (GitHub Webhook)
GitHub 레포지토리에 새로운 코드를 `push`했을 때, 서버가 이를 감지하여 자동으로 리빌드하도록 설정할 수 있습니다.

각 인스턴스에 포함된 `updater` 서비스를 활용합니다.
* **GitHub 레포지토리 설정**: `Settings` -> `Webhooks` -> `Add webhook` 클릭
* **Payload URL**: `http://[서버주소]:[WEBHOOK_PORT]/hooks/update` 입력
   * `WEBHOOK_PORT`는 각 인스턴스의 `config.env`에 정의된 포트입니다.
* **Content type**: `application/json` 선택
* **Secret**: `config.env`의 `WEBHOOK_SECRET` 값을 입력
* **작동 확인**: `sudo docker logs -f [PROJECT_NAME]-updater`를 통해 빌드 과정을 실시간으로 모니터링할 수 있습니다.
### 3. 부팅 시 자동 재개 및 유지보수 설정
서버가 재부팅되었을 때 모든 포켓로그 인스턴스를 자동으로 다시 띄우고 시스템을 최적화합니다.

**Google Cloud Platform (GCP) 사용자:**
인스턴스 수정 -> 메타데이터 -> **`startup-script`** 키에 아래 내용을 입력하세요.
```bash
# 패키지 및 시스템 유지보수
sudo apt update -y
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt clean -y
sudo systemctl daemon-reload
# Docker 서비스 재개
sudo systemctl enable --now docker
# 모든 프로젝트 서비스 재개
for dir in /data/*/; do if [ -d "$dir" ]; then FOLDER_NAME=$(basename "$dir"); CONFIG_FILE="/config/$FOLDER_NAME/config.env"; if [ -f "$CONFIG_FILE" ]; then PROJECT_NAME=$(grep "^PROJECT_NAME=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d "'\"\r"); if [ -n "$PROJECT_NAME" ]; then sudo env PROJECT_NAME="$PROJECT_NAME" DATA_PATH="/data/$FOLDER_NAME" DOCKER_API_VERSION="$(docker version --format '{{.Server.APIVersion}}')" docker compose --env-file "$CONFIG_FILE" -p "$PROJECT_NAME" up -d; fi; fi; fi; done
# Docker 서비스 유지보수
sudo docker system prune -f
sudo docker image prune -af
```
## 4. 수동 업데이트
즉시 최신 소스로 리빌드하려면 다음 명령어를 사용합니다.
```bash
sudo /pokerogue-manager/start.sh [폴더명] update
```
## 5. 서버 중지 및 삭제
특정 프로젝트의 컨테이너를 정지하고 데이터를 삭제하려면 다음 명령어를 사용합니다. (설정 파일은 유지됨)
```bash
sudo /pokerogue-manager/stop.sh [폴더명]
```
