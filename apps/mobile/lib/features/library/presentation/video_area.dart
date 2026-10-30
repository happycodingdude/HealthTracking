import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../data/video_player_gateway.dart';

enum _VideoState { idle, loading, playing, offline, failed }

/// Khu video 16:9 của S-67 (04 Bản 2 S-67, UA2-12, 05 Bản 2 §6.4.6): lúc đầu
/// chỉ là khung tối với nút phát và độ dài, **không tạo trình phát**; chạm phát
/// (và có mạng) mới tạo. Trạng thái: chưa phát · đang tải · video không khả
/// dụng (F18-E1) · không có mạng (F18-E2) · tải lỗi có "Thử lại" (F18-E3).
/// Tên, hình, hướng dẫn của bài luôn hiện, không phụ thuộc khu này (F19-R2).
class VideoArea extends ConsumerStatefulWidget {
  const VideoArea({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<VideoArea> createState() => _VideoAreaState();
}

class _VideoAreaState extends ConsumerState<VideoArea> {
  _VideoState _state = _VideoState.idle;
  VideoPlayerHandle? _player;
  StreamSubscription<bool>? _connectivity;

  @override
  void initState() {
    super.initState();
    final monitor = ref.read(connectivityProvider);
    unawaited(
      monitor.isOnline().then((online) {
        if (mounted && !online && _state == _VideoState.idle) {
          setState(() => _state = _VideoState.offline);
        }
      }),
    );
    _connectivity = monitor.changes.listen((online) {
      if (!mounted) return;
      if (!online && _state == _VideoState.idle) {
        setState(() => _state = _VideoState.offline);
      } else if (online && _state == _VideoState.offline) {
        setState(() => _state = _VideoState.idle);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_connectivity?.cancel());
    unawaited(_player?.close());
    super.dispose();
  }

  Future<void> _play() async {
    await _player?.close();
    _player = null;
    if (!await ref.read(connectivityProvider).isOnline()) {
      if (mounted) setState(() => _state = _VideoState.offline);
      return;
    }
    if (!mounted) return;
    setState(() {
      _state = _VideoState.loading;
      _player = ref
          .read(videoPlayerGatewayProvider)
          .open(
            widget.exercise.youtubeVideoId,
            onReady: () {
              if (mounted && _state == _VideoState.loading) {
                setState(() => _state = _VideoState.playing);
              }
            },
            onError: () {
              if (mounted) setState(() => _state = _VideoState.failed);
            },
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Khung video nền thẻ (04 Bản 4 S-67).
    final frame = context.tokens.surface;
    final onFrame = context.tokens.textPrimary;
    final palette = context.palette;
    final duration = widget.exercise.videoDurationS;

    Widget grey(String text, {Widget? action}) => _Box(
      color: palette.neutralContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );

    if (!widget.exercise.videoAvailable) {
      return KeyedSubtree(
        key: const ValueKey('video-unavailable'),
        child: grey(S.videoUnavailable),
      );
    }
    switch (_state) {
      case _VideoState.offline:
        return KeyedSubtree(
          key: const ValueKey('video-offline'),
          child: grey(S.videoOffline),
        );
      case _VideoState.failed:
        return KeyedSubtree(
          key: const ValueKey('video-failed'),
          child: grey(
            S.videoLoadFailed,
            action: TextButton(
              key: const ValueKey('video-retry'),
              onPressed: _play,
              child: const Text(S.retry),
            ),
          ),
        );
      case _VideoState.idle:
        return Semantics(
          button: true,
          label: duration == null
              ? S.playVideo
              : '${S.playVideo}, ${Fmt.videoDuration(duration)}',
          child: ExcludeSemantics(
            child: GestureDetector(
              key: const ValueKey('video-play'),
              onTap: _play,
              child: _Box(
                color: frame,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 56, color: onFrame),
                    if (duration != null)
                      Text(
                        Fmt.videoDuration(duration),
                        style: context.text.titleMedium?.copyWith(
                          color: onFrame,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      case _VideoState.loading:
      case _VideoState.playing:
        // Cùng một cây cho đang tải và đang phát: trình phát không bị tạo lại.
        final loading = _state == _VideoState.loading;
        Widget waiting({Key? key}) => Column(
          key: key,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 56,
              color: onFrame.withValues(alpha: 0.6),
            ),
            Text(
              S.videoLoading,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: onFrame),
            ),
          ],
        );
        return _AbovePlayer(
          key: const ValueKey('video-player'),
          visible: loading,
          overlay: _Box(
            color: frame,
            child: waiting(key: const ValueKey('video-loading')),
          ),
          // Bản ẩn của lớp chờ giữ khung đủ cao cho chữ (cỡ chữ lớn).
          child: _Box(
            color: frame,
            background: _player?.view,
            child: loading
                ? ExcludeSemantics(
                    child: Visibility.maintain(
                      visible: false,
                      child: waiting(),
                    ),
                  )
                : null,
          ),
        );
    }
  }
}

/// Đặt [overlay] đè lên [child] khi [visible]. Trình phát YouTube trên iPhone
/// tự vẽ WebView trong một lớp `OverlayPortal` phía trên màn hình, nên lớp
/// "Đang tải video…" cũng phải là một `OverlayPortal`, gọi `show` sau trình
/// phát để được vẽ trên cùng (thứ tự vẽ của `OverlayPortal`). [overlay] phủ
/// đúng bề ngang của [child]; [child] tự chứa bản ẩn của lớp chờ để cao bằng.
class _AbovePlayer extends StatefulWidget {
  const _AbovePlayer({
    super.key,
    required this.visible,
    required this.overlay,
    required this.child,
  });

  final bool visible;
  final Widget overlay;
  final Widget child;

  @override
  State<_AbovePlayer> createState() => _AbovePlayerState();
}

class _AbovePlayerState extends State<_AbovePlayer> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  /// Trình phát gọi `show` của nó sau 1–2 khung hình: gọi lại `show` trong
  /// vài khung hình đầu để lớp chờ luôn nằm trên.
  void _raise([int frames = 4]) {
    if (!mounted || !widget.visible) return;
    _portal.show();
    if (frames > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _raise(frames - 1));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _raise());
  }

  @override
  void didUpdateWidget(_AbovePlayer old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _raise());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => OverlayPortal(
        controller: _portal,
        // Không gọi `hide` giữa lúc dựng: hết chờ thì lớp phủ rỗng.
        overlayChildBuilder: (_) => !widget.visible
            ? const SizedBox.shrink()
            : Positioned(
                top: 0,
                left: 0,
                child: CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: widget.overlay,
                    ),
                  ),
                ),
              ),
        child: CompositedTransformTarget(link: _link, child: widget.child),
      ),
    );
  }
}

/// Khung video: tối thiểu 16:9, cao thêm khi chữ dài (cỡ chữ lớn), không cắt
/// chữ. [background] (trình phát) phủ kín khung, [child] nằm giữa, phía trên.
class _Box extends StatelessWidget {
  const _Box({required this.color, this.child, this.background});

  final Color color;
  final Widget? child;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: color,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: KeyedSubtree(
                    key: const ValueKey('video-player-slot'),
                    child: background ?? const SizedBox.shrink(),
                  ),
                ),
                SizedBox(width: width, height: width * 9 / 16),
                if (child case final c?)
                  Padding(padding: const EdgeInsets.all(16), child: c),
              ],
            ),
          ),
        );
      },
    );
  }
}
