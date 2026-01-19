# Stage 1: Build
FROM node:22-slim AS builder
WORKDIR /app

# 환경 변수 설정
ARG MODE
ARG NODE_MEM_LIMIT
ENV NODE_OPTIONS="--max-old-space-size=${NODE_MEM_LIMIT}"
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV VITE_BYPASS_TUTORIAL=0 \
    NEXT_TELEMETRY_DISABLED=1

# 빌드에 필요한 도구 설치
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # 빌드용 도구
        g++ make python3 \
        # 필요한 도구
        git rsync

# pnpm 활성화
RUN corepack enable && corepack prepare pnpm@latest --activate

# 의존성 설치
COPY package.json pnpm-lock.yaml* ./
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm install --frozen-lockfile --ignore-scripts

# 소스 복사
COPY --chown=node:node . .

# 빌드 실행
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    --mount=type=cache,target=/app/node_modules/.cache \
    if [ "$MODE" = "development" ]; then \
        pnpm run build:dev; \
    elif [ "$MODE" = "beta" ]; then \
        pnpm run build:beta; \
    elif [ "$MODE" = "app" ]; then \
        pnpm run build:app; \
    else \
        pnpm run build; \
    fi

# Stage 2: Deploy (Nginx로 정적 파일 서비스)
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
