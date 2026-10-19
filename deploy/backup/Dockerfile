# Container sao lưu (05 §6.13.4, 06 OPS-2): pg_dump → age → rclone, 02:00 hằng ngày.
#   docker build -f deploy/backup/Dockerfile -t ghcr.io/happycodingdude/ironly-backup:<tag> deploy/backup
FROM alpine:3.20
RUN apk add --no-cache postgresql16-client age rclone curl tzdata \
 && adduser -D -u 10002 backup
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod 755 /usr/local/bin/backup.sh
USER backup
ENV TZ=Asia/Ho_Chi_Minh BACKUP_AT=02:00
ENTRYPOINT ["/usr/local/bin/backup.sh"]
CMD ["loop"]
