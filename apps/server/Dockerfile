# Ảnh Docker của server (05 §6.13.2, 06 OPS-1): dựng nhiều tầng, dart compile exe.
# Build context là gốc repo (pub workspace, TD-01):
#   docker build -f apps/server/Dockerfile -t ironly-api:<tag> .
# Tầng build dùng đúng phiên bản Flutter của dự án (environment.flutter trong
# apps/mobile/pubspec.yaml) vì workspace có cả app Flutter; tầng chạy chỉ có
# hai file thực thi `server`, `admin`, migration, schema.sql và thư viện bài tập.
# Flutter chỉ có SDK Linux x64, nên tầng build luôn chạy amd64 và biên dịch chéo
# sang kiến trúc đích (TARGETARCH: amd64 hoặc arm64) bằng `--target-arch`.

FROM --platform=linux/amd64 ubuntu:24.04 AS build
ARG FLUTTER_VERSION=3.47.6
ARG TARGETARCH
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
  | tar -xJ -C /opt \
 && git config --system --add safe.directory /opt/flutter
ENV PATH=/opt/flutter/bin:$PATH
RUN flutter config --no-analytics >/dev/null

WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
COPY packages ./packages
COPY apps/server ./apps/server
COPY apps/mobile/pubspec.yaml ./apps/mobile/pubspec.yaml
RUN flutter pub get
RUN mkdir -p /out && cd apps/server \
 && ARCH="$([ "$TARGETARCH" = arm64 ] && echo arm64 || echo x64)" \
 && dart compile exe --target-os linux --target-arch "$ARCH" bin/server.dart -o /out/server \
 && dart compile exe --target-os linux --target-arch "$ARCH" bin/admin.dart -o /out/admin

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 --create-home app
WORKDIR /app
COPY --from=build /out/server /out/admin ./
COPY apps/server/migrations ./migrations
COPY apps/server/db/schema.sql ./db/schema.sql
COPY data/exercises.json ./data/exercises.json
USER app
ENV HOST=0.0.0.0 PORT=8080 MIGRATIONS_DIR=/app/migrations
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/healthz || exit 1
CMD ["./server"]
