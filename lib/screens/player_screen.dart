import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
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
  BetterPlayerController? _controller;
  bool _loading = true;
  String? _error;
  int _urlIndex = 0;
  bool _disposed = false;

  // Headers que o APK antigo e a maioria dos players IPTV usam
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
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

    // Dispose controller anterior
    _controller?.dispose(forceDispose: true);
    _controller = null;

    try {
      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url,
        headers: _headers,
        liveStream: widget.channel.type == 'live',
        bufferingConfiguration: const BetterPlayerBufferingConfiguration(
          minBufferMs: 2000,
          maxBufferMs: 30000,
          bufferForPlaybackMs: 1000,
          bufferForPlaybackAfterRebufferMs: 2000,
        ),
      );

      final config = BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        aspectRatio: 16 / 9,
        handleLifecycle: true,
        autoDetectFullscreenDeviceOrientation: true,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          enableSkips: false,
          enableOverflowMenu: false,
          enablePlaybackSpeed: false,
          enableQualities: false,
          enableSubtitles: false,
          enableAudioTracks: false,
          controlBarColor: Colors.black54,
          iconsColor: Colors.white,
          progressBarPlayedColor: AppColors.purple,
          progressBarHandleColor: AppColors.purple,
          loadingColor: AppColors.purple,
        ),
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage ?? 'Erro ao reproduzir');
        },
      );

      final controller = BetterPlayerController(config);
      await controller.setupDataSource(dataSource);

      controller.addEventsListener((event) {
        if (_disposed || !mounted) return;
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized ||
            event.betterPlayerEventType == BetterPlayerEventType.play) {
          setState(() => _loading = false);
        }
        if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          _onError();
        }
      });

      if (!mounted || _disposed) {
        controller.dispose(forceDispose: true);
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
      });

      // Timeout de segurança
      Future.delayed(const Duration(seconds: 25), () {
        if (_disposed || !mounted) return;
        if (_loading) _onError();
      });
    } catch (e) {
      if (!_disposed && mounted) _onError();
    }
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

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _retry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose(forceDispose: true);
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
            if (_controller != null && _error == null)
              Positioned.fill(
                child: BetterPlayer(controller: _controller!),
              ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.purple),
              ),
            if (_error != null) _buildErrorWidget(_error!),
            // Barra superior
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
                        widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: widget.isFavorite ? AppColors.purple : Colors.white,
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
