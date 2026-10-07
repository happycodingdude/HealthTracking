# Ảnh Linux amd64 cho golden test (ED-09), cùng phiên bản Flutter với dự án
# (environment.flutter trong apps/mobile/pubspec.yaml). Dựng bởi tool/golden.sh.
FROM ubuntu:24.04
ARG FLUTTER_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils libglu1-mesa libsqlite3-dev \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
  | tar -xJ -C /opt \
 && git config --system --add safe.directory /opt/flutter
ENV PATH=/opt/flutter/bin:$PATH
RUN flutter config --no-analytics >/dev/null && flutter precache --no-android --no-ios --no-web && flutter --version
