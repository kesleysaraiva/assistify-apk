import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../services/xtream_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  final XtreamService xtream;
  final StorageService storage;

  const HomeScreen({super.key, required this.xtream, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0; // 0 live, 1 movies, 2 series, 3 favs
  List<Category> _categories = [];
  List<Channel> _channels = [];
  String? _selectedCategoryId;
  bool _loading = true;
  String? _error;
  String _search = '';
  List<String> _favs = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFavs();
    _loadTab();
  }

  Future<void> _loadFavs() async {
    _favs = await widget.storage.loadFavorites();
    if (mounted) setState(() {});
  }

  Future<void> _loadTab() async {
    setState(() {
      _loading = true;
      _error = null;
      _channels = [];
      _categories = [];
      _selectedCategoryId = null;
    });
    try {
      if (_tab == 0) {
        _categories = await widget.xtream.getLiveCategories();
        _channels = await widget.xtream.getLiveStreams();
      } else if (_tab == 1) {
        _categories = await widget.xtream.getVodCategories();
        _channels = await widget.xtream.getVodStreams();
      } else if (_tab == 2) {
        _categories = await widget.xtream.getSeriesCategories();
        _channels = await widget.xtream.getSeries();
      } else {
        // favorites – need all types cached; for simplicity reload live
        _categories = [];
        final live = await widget.xtream.getLiveStreams();
        _channels = live.where((c) => _favs.contains(c.id)).toList();
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _selectCategory(String? id) async {
    setState(() {
      _selectedCategoryId = id;
      _loading = true;
    });
    try {
      if (_tab == 0) {
        _channels = await widget.xtream.getLiveStreams(categoryId: id);
      } else if (_tab == 1) {
        _channels = await widget.xtream.getVodStreams(categoryId: id);
      } else if (_tab == 2) {
        _channels = await widget.xtream.getSeries(categoryId: id);
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Channel> get _filtered {
    if (_search.isEmpty) return _channels;
    final q = _search.toLowerCase();
    return _channels.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _toggleFav(Channel ch) async {
    if (_favs.contains(ch.id)) {
      _favs.remove(ch.id);
    } else {
      _favs.add(ch.id);
    }
    await widget.storage.saveFavorites(_favs);
    setState(() {});
  }

  Future<void> _openChannel(Channel ch) async {
    if (ch.type == 'series') {
      await _openSeries(ch);
      return;
    }
    List<String> urls;
    if (ch.type == 'live') {
      urls = widget.xtream.liveUrls(ch.streamId);
    } else {
      urls = widget.xtream.vodUrls(ch.streamId, ext: ch.containerExtension);
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: ch.name,
          urls: urls,
          channel: ch,
          isFavorite: _favs.contains(ch.id),
          onToggleFavorite: () => _toggleFav(ch),
        ),
      ),
    );
  }

  Future<void> _openSeries(Channel ch) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.purple)),
    );
    try {
      final info = await widget.xtream.getSeriesInfo(ch);
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      if (info.seasons.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum episódio encontrado')),
        );
        return;
      }
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.bgSecondary,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) {
              return ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    ch.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final season in info.seasons) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Text(
                        'Temporada ${season.number}',
                        style: const TextStyle(
                          color: AppColors.purpleLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final ep in season.episodes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          ep.title,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        trailing: const Icon(Icons.play_circle_fill, color: AppColors.purple),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          final urls = widget.xtream.seriesUrls(
                            ep.id,
                            ext: ep.containerExtension,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                title: '${ch.name} — ${ep.title}',
                                urls: urls,
                                channel: ch,
                                isFavorite: _favs.contains(ch.id),
                                onToggleFavorite: () => _toggleFav(ch),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir série: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await widget.storage.clearCredentials();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(xtream: widget.xtream, storage: widget.storage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            if (_categories.isNotEmpty) _buildCategories(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Image.asset('assets/logo-full.png', height: 36),
          const Spacer(),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: AppColors.bgSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            tooltip: 'Sair',
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Ao Vivo', 'Filmes', 'Séries', 'Favoritos'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = _tab == i;
          return ChoiceChip(
            label: Text(tabs[i]),
            selected: selected,
            onSelected: (_) {
              setState(() => _tab = i);
              _loadTab();
            },
            selectedColor: AppColors.purple,
            backgroundColor: AppColors.bgSecondary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide.none,
          );
        },
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            final sel = _selectedCategoryId == null;
            return FilterChip(
              label: const Text('Todos'),
              selected: sel,
              onSelected: (_) => _selectCategory(null),
              selectedColor: AppColors.purple.withOpacity(0.3),
              checkmarkColor: AppColors.purpleLight,
              labelStyle: TextStyle(color: sel ? AppColors.purpleLight : AppColors.textSecondary, fontSize: 13),
              side: BorderSide(color: sel ? AppColors.purple : AppColors.border),
              backgroundColor: AppColors.bgElevated,
            );
          }
          final cat = _categories[i - 1];
          final sel = _selectedCategoryId == cat.id;
          return FilterChip(
            label: Text(cat.name),
            selected: sel,
            onSelected: (_) => _selectCategory(cat.id),
            selectedColor: AppColors.purple.withOpacity(0.3),
            checkmarkColor: AppColors.purpleLight,
            labelStyle: TextStyle(color: sel ? AppColors.purpleLight : AppColors.textSecondary, fontSize: 13),
            side: BorderSide(color: sel ? AppColors.purple : AppColors.border),
            backgroundColor: AppColors.bgElevated,
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.purple));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadTab, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(child: Text('Nenhum item encontrado', style: TextStyle(color: AppColors.textMuted)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${list.length} itens',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => _ChannelCard(
              channel: list[i],
              isFav: _favs.contains(list[i].id),
              onTap: () => _openChannel(list[i]),
              onFav: () => _toggleFav(list[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final Channel channel;
  final bool isFav;
  final VoidCallback onTap;
  final VoidCallback onFav;

  const _ChannelCard({
    required this.channel,
    required this.isFav,
    required this.onTap,
    required this.onFav,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  channel.logo != null && channel.logo!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: channel.logo!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.bgElevated),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onFav,
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? AppColors.purple : Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.bgElevated,
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: AppColors.purple, size: 40),
      ),
    );
  }
}
