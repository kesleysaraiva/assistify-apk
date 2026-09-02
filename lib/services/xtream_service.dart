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

  /// Stream URL builders (Xtream standard)
  String liveStreamUrl(String streamId) {
    final c = _creds!;
    return '${c.baseUrl}/live/${c.username}/${c.password}/$streamId.ts';
  }

  String liveStreamUrlM3u8(String streamId) {
    final c = _creds!;
    return '${c.baseUrl}/live/${c.username}/${c.password}/$streamId.m3u8';
  }

  String vodStreamUrl(String streamId, {String ext = 'mp4'}) {
    final c = _creds!;
    return '${c.baseUrl}/movie/${c.username}/${c.password}/$streamId.$ext';
  }

  String seriesStreamUrl(String episodeId, {String ext = 'mp4'}) {
    final c = _creds!;
    return '${c.baseUrl}/series/${c.username}/${c.password}/$episodeId.$ext';
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
