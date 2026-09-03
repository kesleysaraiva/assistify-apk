import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;
  int _urlIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            // ignore individual resource errors; JS handles fallback
          },
        ),
      )
      ..addJavaScriptChannel(
        'Assistify',
        onMessageReceived: (msg) {
          if (msg.message == 'error') {
            _tryNext();
          } else if (msg.message == 'playing') {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = null;
              });
            }
          }
        },
      );
    _loadCurrent();
  }

  void _tryNext() {
    if (_urlIndex + 1 < widget.urls.length) {
      setState(() {
        _urlIndex++;
        _loading = true;
        _error = null;
      });
      _loadCurrent();
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível reproduzir.\nTente outro conteúdo.';
        });
      }
    }
  }

  void _loadCurrent() {
    if (widget.urls.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'URL inválida';
      });
      return;
    }
    final url = widget.urls[_urlIndex];
    final html = _buildHtml(url);
    _controller.loadHtmlString(html, baseUrl: 'https://localhost/');
  }

  String _buildHtml(String streamUrl) {
    final u = const JsonEncoder().convert(streamUrl);
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"/>
<script src="https://cdn.jsdelivr.net/npm/hls.js@1.5.7/dist/hls.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/mpegts.js@1.7.3/dist/mpegts.min.js"></script>
<style>
  html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
  video{width:100%;height:100%;object-fit:contain;background:#000}
  #msg{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;
    color:#aaa;font-family:sans-serif;font-size:14px;text-align:center;padding:20px}
</style>
</head>
<body>
<video id="v" controls autoplay playsinline></video>
<div id="msg">Carregando…</div>
<script>
const url = $u;
const video = document.getElementById('v');
const msg = document.getElementById('msg');
function ok(){ msg.style.display='none'; try{Assistify.postMessage('playing');}catch(e){} }
function fail(){ try{Assistify.postMessage('error');}catch(e){} }
video.addEventListener('playing', ok);
video.addEventListener('error', function(){ fail(); });

function tryNative(){
  video.src = url;
  video.play().then(ok).catch(function(){ fail(); });
}

if (/\\.m3u8(\\?|\$)/i.test(url) && window.Hls && Hls.isSupported()) {
  var hls = new Hls({enableWorker:true, xhrSetup:function(xhr){try{xhr.withCredentials=false;}catch(e){}}});
  hls.loadSource(url);
  hls.attachMedia(video);
  hls.on(Hls.Events.MANIFEST_PARSED, function(){ video.play().then(ok).catch(fail); });
  hls.on(Hls.Events.ERROR, function(_, d){ if(d && d.fatal) fail(); });
  setTimeout(function(){ if(msg.style.display!=='none') fail(); }, 15000);
} else if (/\\.ts(\\?|\$)/i.test(url) && window.mpegts && mpegts.getFeatureList && mpegts.getFeatureList().mseLivePlayback) {
  try {
    var p = mpegts.createPlayer({type:'mse', isLive:true, url:url}, {enableWorker:true});
    p.attachMediaElement(video);
    p.load();
    p.on(mpegts.Events.ERROR, function(){ fail(); });
    p.play().then(ok).catch(fail);
    setTimeout(function(){ if(msg.style.display!=='none') fail(); }, 15000);
  } catch(e) { tryNative(); }
} else {
  tryNative();
  setTimeout(function(){ if(msg.style.display!=='none' && video.readyState < 2) fail(); }, 15000);
}
</script>
</body>
</html>
''';
  }

  Future<void> _retry() async {
    setState(() {
      _urlIndex = 0;
      _loading = true;
      _error = null;
    });
    _loadCurrent();
  }

  @override
  void dispose() {
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
            if (_error == null)
              Positioned.fill(child: WebViewWidget(controller: _controller)),
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
