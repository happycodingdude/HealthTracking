import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../ui/theme.dart';

/// Một trình phát đã tạo (chỉ sau khi Bạn chạm phát).
abstract interface class VideoPlayerHandle {
  /// Trình phát để đặt vào khung 16:9.
  Widget get view;

  /// Hủy trình phát (rời màn hình, thử lại).
  Future<void> close();
}

/// Trình phát video (06 Bản 2 ED2-11, TD2-19): widget test dùng bản giả, không
/// tạo WebView.
abstract interface class VideoPlayerGateway {
  /// Tạo trình phát cho [videoId] và phát. [onReady] khi video đã tải xong,
  /// [onError] khi tải lỗi (F18-E3).
  VideoPlayerHandle open(
    String videoId, {
    required VoidCallback onReady,
    required VoidCallback onError,
  });
}

final videoPlayerGatewayProvider = Provider<VideoPlayerGateway>(
  (ref) => const YoutubeVideoGateway(),
);

/// `youtube_player_iframe` (05 Bản 2 §6.4.6, §6.13): miền
/// `youtube-nocookie.com`, chỉ tạo và nạp video khi Bạn đã chạm phát; WebView
/// chỉ được tải miền YouTube, mọi điều hướng khác bị chặn. App không thêm cầu
/// nối JavaScript nào; gói chỉ dùng kênh nội bộ của nó để nhận trạng thái
/// trình phát.
final class YoutubeVideoGateway implements VideoPlayerGateway {
  const YoutubeVideoGateway();

  static const _allowedHosts = {
    'www.youtube-nocookie.com',
    'youtube-nocookie.com',
    'www.youtube.com',
    'youtube.com',
    'm.youtube.com',
  };

  /// Lỗi khung trống báo lúc khởi tạo, trước khi nạp video.
  static const _initialErrors = {YoutubeError.invalidParam};

  /// Video đã nạp vào trình phát (hiện hình xem trước hoặc đang phát).
  static const _loaded = {
    PlayerState.cued,
    PlayerState.buffering,
    PlayerState.playing,
    PlayerState.paused,
  };

  /// WebView chỉ tải trang trống hoặc miền YouTube.
  static bool allowed(Uri? uri) =>
      uri != null &&
      (uri.scheme == 'about' ||
          (uri.scheme == 'https' && _allowedHosts.contains(uri.host)));

  @override
  VideoPlayerHandle open(
    String videoId, {
    required VoidCallback onReady,
    required VoidCallback onError,
  }) {
    final controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
        interfaceLanguage: 'vi',
      ),
    );
    var failed = false;
    void fail() {
      if (failed) return;
      failed = true;
      onError();
    }

    controller.webViewController.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (r) => allowed(Uri.tryParse(r.url))
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) fail();
        },
      ),
    );
    // Khung trống (chưa có mã video) báo lỗi `invalidParam` ngay khi khởi
    // tạo và gói chỉ xóa lỗi khi video đã phát: chỉ lỗi mới xuất hiện sau đó
    // (video bị gỡ, cấm nhúng, lỗi mạng của trình phát) mới là tải lỗi.
    var ready = false;
    var lastError = YoutubeError.none;
    // Hủy trong [_YoutubeHandle.close].
    // ignore: cancel_subscriptions
    final sub = controller.listen((value) {
      final error = value.error;
      if (error != YoutubeError.none && error != lastError) {
        lastError = error;
        if (!_initialErrors.contains(error) || ready) fail();
        return;
      }
      lastError = error;
      if (!ready && _loaded.contains(value.playerState)) {
        ready = true;
        onReady();
      }
    });
    // Nạp và phát ngay (Bạn đã chạm phát); gói chờ trình phát sẵn sàng.
    unawaited(
      controller
          .loadVideoById(videoId: videoId)
          .catchError((Object _) => fail()),
    );
    return _YoutubeHandle(controller, sub);
  }
}

final class _YoutubeHandle implements VideoPlayerHandle {
  _YoutubeHandle(this._controller, this._sub);

  final YoutubePlayerController _controller;
  final StreamSubscription<YoutubePlayerValue> _sub;

  @override
  Widget get view => YoutubePlayer(
    controller: _controller,
    backgroundColor: TokenColor.surface,
  );

  @override
  Future<void> close() async {
    await _sub.cancel();
    await _controller.close();
  }
}
