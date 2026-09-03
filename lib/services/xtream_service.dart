import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class XtreamService {
  PanelCredentials? _creds;

  void setCredentials(PanelCredentials c) => _creds = c;

  PanelCredentials? get credentials => _creds;

  Future<Map<String, dynamic>> login(PanelCredentials creds) async {
    final url = Uri.parse(
        '${creds.apiUrl}&action=get_live_categories'); // lightweight check
    final res = await http.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Servidor respondeu ${res.statusCode}');
    }
    // Also try user info
    final infoUrl = Uri.parse(creds.apiUrl);
    final infoRes = await http.get(infoUrl).timeout(const Duration(seconds: 15));
    if (infoRes.statusCode == 200) {
      final body = jsonDecode(infoRes.body);
      if (body is Map && body['user_info'] != null) {
        final status = body['user_info']['auth']?.toString();
        if (status == '0') throw Exception('Usuário ou senha inválidos');
        _creds = creds;
        return Map<String, dynamic>.from(body as Map);
      }
    }
    // If categories returned as list, login is ok
    final cats = jsonDecode(res.body);
    if (cats is List) {
      _creds = creds;
      return {'user_info': {'auth': 1}};
    }
    throw Exception('Não foi possível autenticar no painel');
  }

  Future<List<Category>> getLiveCategories() async {
    final data = await _get('get_live_categories');
    if (data is! List) return [];
    return data
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e), 'live'))
        .toList();
  }

  Future<List<Category>> getVodCategories() async {
    final data = await _get('get_vod_categories');
    if (data is! List) return [];
    return data
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e), 'vod'))
        .toList();
  }

  Future<List<Category>> getSeriesCategories() async {
    final data = await _get('get_series_categories');
    if (data is! List) return [];
    return data
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e), 'series'))
        .toList();
  }

  Future<List<Channel>> getLiveStreams({String? categoryId}) async {
    var action = 'get_live_streams';
    if (categoryId != null && categoryId.isNotEmpty) {
      action += '&category_id=$categoryId';
    }
    final data = await _get(action);
    if (data is! List) return [];
    return data
        .map((e) => Channel.fromLiveJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Channel>> getVodStreams({String? categoryId}) async {
    var action = 'get_vod_streams';
    if (categoryId != null && categoryId.isNotEmpty) {
      action += '&category_id=$categoryId';
    }
    final data = await _get(action);
    if (data is! List) return [];
    return data
        .map((e) => Channel.fromVodJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Channel>> getSeries({String? categoryId}) async {
    var action = 'get_series';
    if (categoryId != null && categoryId.isNotEmpty) {
      action += '&category_id=$categoryId';
    }
    final data = await _get(action);
    if (data is! List) return [];
    return data
        .map((e) => Channel.fromSeriesJson(Map<String, dynamic>.from(e)))
        .toList();
  }


  Future<SeriesInfo> getSeriesInfo(Channel series) async {
    final data = await _get('get_series_info&series_id=${series.streamId}');
    if (data is! Map) {
      return SeriesInfo(series: series, seasons: []);
    }
    final map = Map<String, dynamic>.from(data);
    final episodesRaw = map['episodes'];
    final seasons = <Season>[];
    if (episodesRaw is Map) {
      final keys = episodesRaw.keys.map((e) => e.toString()).toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
      for (final key in keys) {
        final list = episodesRaw[key];
        if (list is! List) continue;
        final eps = <Episode>[];
        for (final e in list) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final id = '${m['id'] ?? ''}';
          if (id.isEmpty) continue;
          final num = m['episode_num']?.toString() ?? id;
          final title = (m['title'] as String?)?.trim();
          eps.add(Episode(
            id: id,
            title: title != null && title.isNotEmpty ? 'E$num — $title' : 'Episódio $num',
            containerExtension: (m['container_extension'] as String?) ?? 'mp4',
            plot: m['plot'] as String?,
          ));
        }
        if (eps.isNotEmpty) {
          seasons.add(Season(number: key, episodes: eps));
        }
      }
    }
    return SeriesInfo(series: series, seasons: seasons);
  }

  /// Stream URL builders (Xtream standard)
  String liveStreamUrl(String streamId) {
    final c = _creds!;
    return '${c.baseUrl}/live/${c.username}/${c.password}/$streamId.ts';
  }

  String liveStreamUrlM3u8(String streamId) {
    final c = _creds!;
    return '${c.baseUrl}/live/${c.username}/${c.password}/$streamId.m3u8';
  }

  List<String> liveUrls(String streamId) {
    final c = _creds!;
    final b = c.baseUrl;
    final u = c.username;
    final p = c.password;
    return [
      '$b/live/$u/$p/$streamId.m3u8',
      '$b/live/$u/$p/$streamId.ts',
      '$b/live/$u/$p/$streamId',
    ];
  }

  String vodStreamUrl(String streamId, {String ext = 'mp4'}) {
    final c = _creds!;
    return '${c.baseUrl}/movie/${c.username}/${c.password}/$streamId.$ext';
  }

  List<String> vodUrls(String streamId, {String? ext}) {
    final c = _creds!;
    final b = c.baseUrl;
    final u = c.username;
    final p = c.password;
    final e = (ext == null || ext.isEmpty) ? 'mp4' : ext;
    final list = <String>[
      '$b/movie/$u/$p/$streamId.$e',
    ];
    for (final x in ['mp4', 'mkv', 'avi', 'ts', 'm3u8']) {
      final url = '$b/movie/$u/$p/$streamId.$x';
      if (!list.contains(url)) list.add(url);
    }
    return list;
  }

  String seriesStreamUrl(String episodeId, {String ext = 'mp4'}) {
    final c = _creds!;
    return '${c.baseUrl}/series/${c.username}/${c.password}/$episodeId.$ext';
  }

  List<String> seriesUrls(String episodeId, {String? ext}) {
    final c = _creds!;
    final b = c.baseUrl;
    final u = c.username;
    final p = c.password;
    final e = (ext == null || ext.isEmpty) ? 'mp4' : ext;
    final list = <String>['$b/series/$u/$p/$episodeId.$e'];
    for (final x in ['mp4', 'mkv', 'ts', 'm3u8']) {
      final url = '$b/series/$u/$p/$episodeId.$x';
      if (!list.contains(url)) list.add(url);
    }
    return list;
  }

  Future<dynamic> _get(String action) async {
    if (_creds == null) throw Exception('Não autenticado');
    final url = Uri.parse('${_creds!.apiUrl}&action=$action');
    final res = await http.get(url).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('Erro HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }
}
