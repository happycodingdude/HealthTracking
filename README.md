# Health Tracking

Monorepo (Dart pub workspace, TD-01):

| Thư mục | Nội dung |
|---|---|
| `apps/mobile` | App iPhone (Flutter) |
| `apps/server` | Backend Dart (shelf + PostgreSQL) |
| `packages/domain` | Business rules thuần Dart, dùng chung |
| `packages/api_contract` | DTO, mã lỗi, codec dùng chung |
| `deploy/` | Docker Compose |
| `docs/specs/` | Spec 01 → 06 (LOCKED) |
| `docs/progress.md` | Tiến độ Phase 7 |

Kiểm tra toàn bộ ở local (giống CI): `tool/check.sh`. Hướng dẫn môi trường dev: `docs/dev-setup.md`.
