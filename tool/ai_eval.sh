#!/usr/bin/env bash
# Bộ đánh giá AI (06 VS12-T12): 20 lần tạo thực đơn với model thật, tỷ lệ hợp lệ
# và chi phí trung bình. Cần ANTHROPIC_API_KEY (khóa dev, giới hạn 1 USD, OPS-4).
#   tool/ai_eval.sh            model thật
#   tool/ai_eval.sh --fake     kiểm tra bộ đánh giá với nhà cung cấp giả
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/server"
exec dart run bin/ai_eval.dart "$@"
