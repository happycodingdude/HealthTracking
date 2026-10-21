# Migration

Từ Bản 3 (05 Bản 3 TR3-05, 06 Bản 3 ED3-01), cấu trúc database chỉ đổi bằng
file `NNNN_<tên>.sql` đánh số tiếp trong thư mục này, **chỉ thêm, không sửa,
không xóa** file đã có. Server chạy các file chưa chạy khi khởi động
(`Migrator`); `admin migrate` chạy cùng việc đó cho database dev và test.

- `0001_baseline.sql`: cấu trúc Bản 2 đang chạy production, đóng băng từ
  `db/schema.sql` của bản đã triển khai. Database production tạo từ
  `schema.sql` trước đây được ghi nhận là đã chạy `0001` ở lần khởi động đầu
  tiên (không chạy lại).
- `0002_v3.sql`: toàn bộ cấu trúc Bản 3.

File có dòng `-- migrate:commit` được chạy từng đoạn, mỗi đoạn một
transaction (giá trị enum mới phải commit trước khi dùng).

`../db/schema.sql` là tổng các migration, sinh bằng `tool/gen_schema.sh`; không
sửa tay (`tool/check.sh` và CI kiểm tra).
