class PanelCredentials {
  final String host; // e.g. http://telaplay.lat
  final String username;
  final String password;

  const PanelCredentials({
    required this.host,
    required this.username,
    required this.password,
  });

  String get baseUrl {
    var h = host.trim();
    if (!h.startsWith('http')) h = 'http://$h';
    if (h.endsWith('/')) h = h.substring(0, h.length - 1);
    return h;
  }

  String get apiUrl =>
      '$baseUrl/player_api.php?username=$username&password=$password';

  Map<String, dynamic> toJson() => {
        'host': host,
        'username': username,
        'password': password,
      };

  factory PanelCredentials.fromJson(Map<String, dynamic> j) => PanelCredentials(
        host: j['host'] as String,
        username: j['username'] as String,
        password: j['password'] as String,
      );
}

class Category {
  final String id;
  final String name;
  final String type; // live | vod | series

  Category({required this.id, required this.name, required this.type});

  factory Category.fromJson(Map<String, dynamic> j, String type) => Category(
        id: '${j['category_id']}',
        name: '${j['category_name'] ?? 'Sem nome'}',
        type: type,
      );
}

class Channel {
  final String id;
  final String name;
  final String? logo;
  final String categoryId;
  final String streamId;
  final String type; // live | vod | series
  final String? containerExtension;
  final String? plot;
  final String? rating;

  Channel({
    required this.id,
    required this.name,
    this.logo,
    required this.categoryId,
    required this.streamId,
    required this.type,
    this.containerExtension,
    this.plot,
    this.rating,
  });

  factory Channel.fromLiveJson(Map<String, dynamic> j) => Channel(
        id: 'live_${j['stream_id']}',
        name: '${j['name'] ?? 'Canal'}',
        logo: j['stream_icon'] as String?,
        categoryId: '${j['category_id'] ?? ''}',
        streamId: '${j['stream_id']}',
        type: 'live',
      );

  factory Channel.fromVodJson(Map<String, dynamic> j) => Channel(
        id: 'vod_${j['stream_id']}',
        name: '${j['name'] ?? 'Filme'}',
        logo: j['stream_icon'] as String?,
        categoryId: '${j['category_id'] ?? ''}',
        streamId: '${j['stream_id']}',
        type: 'vod',
        containerExtension: j['container_extension'] as String?,
        plot: j['plot'] as String?,
        rating: j['rating']?.toString(),
      );

  factory Channel.fromSeriesJson(Map<String, dynamic> j) => Channel(
        id: 'series_${j['series_id']}',
        name: '${j['name'] ?? 'Série'}',
        logo: j['cover'] as String?,
        categoryId: '${j['category_id'] ?? ''}',
        streamId: '${j['series_id']}',
        type: 'series',
        plot: j['plot'] as String?,
        rating: j['rating']?.toString(),
      );
}

class SeriesInfo {
  final Channel series;
  final List<Season> seasons;

  SeriesInfo({required this.series, required this.seasons});
}

class Season {
  final String number;
  final List<Episode> episodes;

  Season({required this.number, required this.episodes});
}

class Episode {
  final String id;
  final String title;
  final String containerExtension;
  final String? plot;

  Episode({
    required this.id,
    required this.title,
    required this.containerExtension,
    this.plot,
  });
}
