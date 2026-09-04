import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _loading = true;
  String? _error;
  int _urlIndex = 0;
  bool _disposed = false;

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': '*/*',
    'Connection': 'keep-alive',
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
      setState(() {
        _loading = false;
        _error = 'URL inválida';
      });
      return;
    }
    await _openUrl(widget.urls[_urlIndex]);
  }

  Future<void> _openUrl(String url) async {
    if (_disposed || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    await _disposePlayers();

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _headers,
      );

      await controller.initialize().timeout(const Duration(seconds: 25));

      if (_disposed || !mounted) {
        await controller.dispose();
        return;
      }

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.purple,
          handleColor: AppColors.purple,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        placeholder: const Center(
          child: CircularProgressIndicator(color: AppColors.purple),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          );
        },
      );

      setState(() {
        _videoController = controller;
        _chewieController = chewie;
        _loading = false;
      });
    } catch (_) {
      if (!_disposed && mounted) _onError();
    }
  }

  Future<void> _disposePlayers() async {
    _chewieController?.dispose();
    _chewieController = null;
    await _videoController?.dispose();
    _videoController = null;
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

  @override
  void dispose() {
    _disposed = true;
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_chewieController != null && _error == null)
              Positioned.fill(
                child: Chewie(controller: _chewieController!),
              ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.purple),
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                color: Colors.black54,
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
