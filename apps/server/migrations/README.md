# Migration

Trong lúc dev chưa có file migration nào (06 Bản 2 IR2-13, ED2-18): cấu trúc
database nằm trong `../db/schema.sql`, sửa thẳng file đó và tạo lại database dev
bằng `tool/reset_dev_db.sh`.

Khi bản đầu tiên có dữ liệu thật được phát hành, `schema.sql` lúc đó được đóng
băng thành `0001_baseline.sql` ở thư mục này (06 Bản 2 VS31-T07, 06 Bản 1
VS15-T10). Từ đó mọi thay đổi cấu trúc là một file `NNNN_<tên>.sql` đánh số
tiếp, chỉ thêm, không sửa file đã chạy trên production. Server chạy các file này
khi khởi động (`Migrator`).
