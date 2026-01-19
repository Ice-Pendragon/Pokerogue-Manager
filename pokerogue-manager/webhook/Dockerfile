FROM almir/webhook

# 관리에 필요한 도구 설치
USER root
RUN --mount=type=cache,target=/var/cache/apk \
    apk add \
        # 설치에 필요한 도구
        bash git \
        # 관리에 필요한 도구
        docker-cli docker-cli-compose
