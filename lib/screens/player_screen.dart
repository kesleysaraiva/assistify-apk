import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

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
  bool _showControls = true;
  int _urlIndex = 0;

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': '*/*',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _tryNext();
  }

  Future<void> _tryNext() async {
    if (_urlIndex >= widget.urls.length) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível reproduzir.\nTente outro conteúdo.';
        });
      }
      return;
    }
    final url = widget.urls[_urlIndex];
    setState(() {
      _loading = true;
      _error = null;
    });
    await _controller?.dispose();
    _controller = null;
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = c;
      await c.initialize().timeout(const Duration(seconds: 20));
      await c.play();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      _urlIndex++;
      await _tryNext();
    }
  }

  Future<void> _retry() async {
    _urlIndex = 0;
    await _tryNext();
  }

  @override
  void dispose() {
    _controller?.dispose();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _loading
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.purple),
                        const SizedBox(height: 12),
                        Text(
                          'Tentando ${_urlIndex + 1}/${widget.urls.length}...',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    )
                  : _error != null
                      ? Padding(
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
                        )
                      : (c != null && c.value.isInitialized)
                          ? GestureDetector(
                              onTap: () =>
                                  setState(() => _showControls = !_showControls),
                              child: AspectRatio(
                                aspectRatio: c.value.aspectRatio == 0
                                    ? 16 / 9
                                    : c.value.aspectRatio,
                                child: VideoPlayer(c),
                              ),
                            )
                          : const SizedBox.shrink(),
            ),
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Image.asset(
                        'assets/logo-icon.png',
                        width: 28,
                        height: 28,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 28),
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
            if (_showControls &&
                c != null &&
                c.value.isInitialized &&
                _error == null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: IconButton(
                  icon: Icon(
                    c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: () {
                    setState(() {
                      if (c.value.isPlaying) {
                        c.pause();
                      } else {
                        c.play();
                      }
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
