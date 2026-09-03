import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const _keyCreds = 'assistify_creds';
  static const _keyFavs = 'assistify_favs';

  Future<void> saveCredentials(PanelCredentials c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCreds, jsonEncode(c.toJson()));
  }

  Future<PanelCredentials?> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCreds);
    if (raw == null) return null;
    try {
      return PanelCredentials.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCreds);
  }

  Future<List<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFavs) ?? [];
  }

  Future<void> saveFavorites(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFavs, ids);
  }
}
