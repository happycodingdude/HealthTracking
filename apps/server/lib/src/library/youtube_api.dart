import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';

/// Trạng thái một video theo YouTube Data API v3 (`videos.list`,
/// `part=status,contentDetails`).
final class VideoInfo {
  const VideoInfo({
    required this.id,
    required this.privacyStatus,
    required this.embeddable,
    required this.uploadStatus,
    required this.durationSeconds,
  });

  final String id;

  /// `public` / `unlisted` / `private`.
  final String privacyStatus;
  final bool embeddable;

  /// `processed` khi đã xử lý xong.
  final String uploadStatus;
  final int durationSeconds;

  /// Tiêu chí của video trong thư viện (05 Bản 2 §6.10.3 bước 2, LIB-R2).
  /// null = đạt; ngược lại là lý do không khả dụng.
  VideoUnavailableReason? get problem {
    if (privacyStatus != 'public') return VideoUnavailableReason.private;
    if (!embeddable) return VideoUnavailableReason.notEmbeddable;
    if (uploadStatus != 'processed') return VideoUnavailableReason.removed;
    if (durationSeconds > LibraryRules.maxVideoSeconds) {
      return VideoUnavailableReason.tooLong;
    }
    return null;
  }
}

final class YouTubeApiException implements Exception {
  YouTubeApiException(this.message);

  final String message;

  @override
  String toString() => 'YouTubeApiException: $message';
}

/// YouTube Data API (05 Bản 2 TD2-17, TD2-18). Gửi đi **chỉ mã video**
/// (TR2-10). Dùng chung cho công cụ đo độ dài (VS21-T05) và job kiểm tra video
/// hằng ngày (VS-22).
abstract interface class YouTubeApi {
  /// Thông tin các video tồn tại trong [ids]; video bị gỡ không có trong kết
  /// quả. Lỗi gọi API → [YouTubeApiException].
  Future<Map<String, VideoInfo>> videos(List<String> ids);
}

/// `videos.list` qua REST, API key, lô tối đa 50 mã (TA2-09).
final class YouTubeDataApiClient implements YouTubeApi {
  YouTubeDataApiClient({
    required String apiKey,
    HttpClient? client,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 30),
  }) : _apiKey = apiKey,
       _client = client ?? HttpClient(),
       _endpoint =
           endpoint ??
           Uri.parse('https://www.googleapis.com/youtube/v3/videos');

  final String _apiKey;
  final HttpClient _client;
  final Uri _endpoint;
  final Duration timeout;

  static const batchSize = 50;

  @override
  Future<Map<String, VideoInfo>> videos(List<String> ids) async {
    final out = <String, VideoInfo>{};
    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.sublist(
        i,
        i + batchSize > ids.length ? ids.length : i + batchSize,
      );
      out.addAll(parseResponse(await _get(batch)));
    }
    return out;
  }

  Future<Object?> _get(List<String> ids) async {
    final uri = _endpoint.replace(
      queryParameters: {
        'part': 'status,contentDetails',
        'id': ids.join(','),
        'maxResults': '$batchSize',
        'key': _apiKey,
      },
    );
    try {
      final req = await _client.getUrl(uri).timeout(timeout);
      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      if (res.statusCode != 200) {
        // Không ghi khóa hay URL vào lỗi.
        throw YouTubeApiException('HTTP ${res.statusCode}');
      }
      return jsonDecode(body);
    } on YouTubeApiException {
      rethrow;
    } on Exception catch (e) {
      throw YouTubeApiException(e.runtimeType.toString());
    }
  }

  /// Đọc thân phản hồi `videos.list`.
  static Map<String, VideoInfo> parseResponse(Object? json) {
    if (json is! Map || json['items'] is! List) {
      throw YouTubeApiException('phản hồi không đúng định dạng');
    }
    final out = <String, VideoInfo>{};
    for (final item in json['items'] as List) {
      if (item is! Map) continue;
      final id = item['id'];
      final status = item['status'];
      final details = item['contentDetails'];
      if (id is! String || status is! Map || details is! Map) continue;
      final duration = parseIsoDuration('${details['duration']}');
      if (duration == null) continue;
      out[id] = VideoInfo(
        id: id,
        privacyStatus: '${status['privacyStatus']}',
        embeddable: status['embeddable'] == true,
        uploadStatus: '${status['uploadStatus']}',
        durationSeconds: duration,
      );
    }
    return out;
  }

  static final _duration = RegExp(
    r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
  );

  /// `PT48S` → 48, `PT1M2S` → 62, `PT1H` → 3600, `P0D` → 0. Sai → null.
  static int? parseIsoDuration(String value) {
    final m = _duration.firstMatch(value);
    if (m == null || value == 'P' || value.endsWith('T')) return null;
    int g(int i) => int.parse(m.group(i) ?? '0');
    return g(1) * 86400 + g(2) * 3600 + g(3) * 60 + g(4);
  }
}

/// YouTube giả (06 Bản 2 ED2-07): trạng thái và độ dài từng mã cấu hình được,
/// mặc định ở local và CI.
final class FakeYouTubeApi implements YouTubeApi {
  /// Video theo mã; không có trong map = video đã bị gỡ.
  final videosById = <String, VideoInfo>{};

  /// Số lần gọi (mỗi lô một lần, như API thật).
  int calls = 0;

  /// Đặt true để mô phỏng lỗi gọi API (hết hạn mức, mất mạng).
  bool failing = false;

  void put(
    String id, {
    String privacy = 'public',
    bool embeddable = true,
    String upload = 'processed',
    int seconds = 48,
  }) => videosById[id] = VideoInfo(
    id: id,
    privacyStatus: privacy,
    embeddable: embeddable,
    uploadStatus: upload,
    durationSeconds: seconds,
  );

  @override
  Future<Map<String, VideoInfo>> videos(List<String> ids) async {
    for (var i = 0; i < ids.length; i += YouTubeDataApiClient.batchSize) {
      calls++;
    }
    if (failing) throw YouTubeApiException('giả lập lỗi');
    return {
      for (final id in ids)
        if (videosById[id] case final v?) id: v,
    };
  }
}
