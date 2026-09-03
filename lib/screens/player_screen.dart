import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Player based on ExoPlayer (video_player on Android).
class PlayerScreen extends StatefulWidget {
  final String title;
  final List<String> urls;
  final Channel channel;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.urls,
    required this.channel,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;
  int _urlIndex = 0;
  bool _showControls = true;
  bool _disposed = false;
  bool _isPlaying = false;

  // Headers típicos de apps IPTV / ExoPlayer
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': '*/*',
    'Connection': 'keep-alive',
    'Accept-Encoding': 'identity',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _start();
  }

  Future<void> _start() async {
    if (widget.urls.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'URL inválida';
      });
      return;
    }
    await _openUrl(widget.urls[_urlIndex]);
  }

  Future<void> _disposeController() async {
    final old = _controller;
    _controller = null;
    if (old == null) return;
    try {
      await old.pause();
    } catch (_) {}
    try {
      await old.dispose();
    } catch (_) {}
  }

  VideoFormat? _hintFor(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8') || u.endsWith('/m3u8') || u.contains('format=m3u8')) {
      return VideoFormat.hls;
    }
    if (u.contains('.mpd')) return VideoFormat.dash;
    if (u.contains('.mp4') || u.contains('.mkv') || u.contains('.avi')) {
      return VideoFormat.other;
    }
    // live/ts often works better as HLS attempt first; fallback without hint
    return null;
  }

  Future<void> _openUrl(String url) async {
    if (_disposed || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _isPlaying = false;
    });

    await _disposeController();

    VideoPlayerController? c;
    try {
      final hint = _hintFor(url);
      c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _headers,
        formatHint: hint,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      c.addListener(() {
        if (_disposed || !mounted || _controller != c) return;
        final v = c!.value;
        if (v.hasError) {
          _onError();
          return;
        }
        if (v.isInitialized && (v.isPlaying || v.position > Duration.zero)) {
          if (_loading || !_isPlaying) {
            setState(() {
              _loading = false;
              _isPlaying = v.isPlaying;
            });
          }
        }
      });

      await c.initialize().timeout(const Duration(seconds: 25));
      if (_disposed || !mounted) {
        await c.dispose();
        return;
      }

      await c.setLooping(false);
      await c.setVolume(1.0);
      await c.play();

      if (!mounted || _disposed) {
        await c.dispose();
        return;
      }

      setState(() {
        _controller = c;
        _loading = false;
        _isPlaying = true;
      });
    } catch (_) {
      try {
        await c?.dispose();
      } catch (_) {}
      if (!_disposed && mounted) {
        _onError();
      }
    }

    Future.delayed(const Duration(seconds: 28), () {
      if (_disposed || !mounted) return;
      if (_loading && _controller == c) {
        _onError();
      }
    });
  }

  void _onError() {
    if (_disposed || !mounted) return;
    if (_urlIndex + 1 < widget.urls.length) {
      _urlIndex++;
      _openUrl(widget.urls[_urlIndex]);
    } else {
      setState(() {
        _loading = false;
        _error = 'Não foi possível reproduzir.\nTente outro conteúdo.';
      });
    }
  }

  Future<void> _retry() async {
    _urlIndex = 0;
    await _start();
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
      setState(() => _isPlaying = false);
    } else {
      await c.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _disposeController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final initialized = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (initialized && _error == null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showControls = !_showControls),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: c!.value.aspectRatio == 0
                          ? 16 / 9
                          : c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              ),
            if (_loading && _error == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.purple),
                    const SizedBox(height: 12),
                    Text(
                      'Tentando ${_urlIndex + 1}/${widget.urls.length}...',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retry,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.purple,
                        ),
                        child: const Text('Tentar de novo'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Image.asset(
                        'assets/logo-icon.png',
                        width: 26,
                        height: 26,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 26),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (initialized)
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlay,
                        ),
                      IconButton(
                        icon: Icon(
                          widget.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: widget.isFavorite
                              ? AppColors.purple
                              : Colors.white,
                        ),
                        onPressed: widget.onToggleFavorite,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
