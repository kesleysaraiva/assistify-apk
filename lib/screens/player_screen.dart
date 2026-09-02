import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  final Channel channel;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.url,
    required this.channel,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _fav = false;
  bool _error = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fav = widget.isFavorite;
    MediaKit.ensureInitialized();
    _player = Player();
    _controller = VideoController(_player);
    _start();
  }

  Future<void> _start() async {
    try {
      // Prefer m3u8; fallback handled by media_kit
      await _player.open(Media(widget.url));
    } catch (e) {
      // try .ts variant for live
      if (widget.channel.type == 'live') {
        try {
          final tsUrl = widget.url.replaceAll('.m3u8', '.ts');
          await _player.open(Media(tsUrl));
          return;
        } catch (_) {}
      }
      setState(() {
        _error = true;
        _errorMsg = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Image.asset('assets/logo-icon.png', height: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _fav ? Icons.favorite : Icons.favorite_border,
              color: _fav ? AppColors.purple : Colors.white,
            ),
            onPressed: () {
              widget.onToggleFavorite();
              setState(() => _fav = !_fav);
            },
          ),
        ],
      ),
      body: _error
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                    const SizedBox(height: 16),
                    const Text('Não foi possível reproduzir', style: TextStyle(fontSize: 16)),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(_errorMsg!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _error = false);
                        _start();
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: Video(
                controller: _controller,
                controls: MaterialVideoControls,
              ),
            ),
    );
  }
}
