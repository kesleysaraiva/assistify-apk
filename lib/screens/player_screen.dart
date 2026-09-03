import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Player IPTV com media_kit (libmpv) — suporta HLS, TS, HTTP, MP4.
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
  late final Player _player;
  late final VideoController _videoController;
  bool _loading = true;
  String? _error;
  int _urlIndex = 0;
  bool _showControls = true;
  bool _disposed = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();

    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
        title: 'Assistify',
      ),
    );
    _videoController = VideoController(_player);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player.stream.error.listen((event) {
      if (_disposed || !mounted) return;
      _onError();
    });

    _player.stream.playing.listen((playing) {
      if (_disposed || !mounted) return;
      setState(() {
        _isPlaying = playing;
        if (playing) _loading = false;
      });
    });

    _player.stream.buffering.listen((buffering) {
      if (_disposed || !mounted) return;
      if (!buffering && _player.state.playing) {
        setState(() => _loading = false);
      }
    });

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

  Future<void> _openUrl(String url) async {
    if (_disposed || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _player.open(
        Media(
          url,
          httpHeaders: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': '*/*',
            'Connection': 'keep-alive',
          },
        ),
        play: true,
      );

      // Se em 20s não começar a tocar, tenta próxima URL
      Future.delayed(const Duration(seconds: 20), () {
        if (_disposed || !mounted) return;
        if (_loading && !_player.state.playing) {
          _onError();
        }
      });
    } catch (_) {
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

  Future<void> _togglePlay() async {
    await _player.playOrPause();
  }

  @override
  void dispose() {
    _disposed = true;
    _player.dispose();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Vídeo
            if (_error == null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showControls = !_showControls),
                  child: Video(
                    controller: _videoController,
                    controls: NoVideoControls,
                    fill: Colors.black,
                  ),
                ),
              ),

            // Loading
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

            // Erro
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

            // Controles
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
