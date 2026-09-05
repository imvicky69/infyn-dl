import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/ytm_search_result.dart';
import '../services/ytm_search_service.dart';

/// A draggable bottom sheet for searching YouTube Music.
/// Opens over the downloader screen and calls [onResultSelected]
/// with the chosen URL so the normal fetch flow kicks in unchanged.
class YtmSearchSheet extends StatefulWidget {
  const YtmSearchSheet({super.key, required this.onResultSelected});

  final ValueChanged<String> onResultSelected;

  /// Convenience helper to show the sheet.
  static Future<void> show(
    BuildContext context,
    ValueChanged<String> onResultSelected,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => YtmSearchSheet(onResultSelected: onResultSelected),
    );
  }

  @override
  State<YtmSearchSheet> createState() => _YtmSearchSheetState();
}

class _YtmSearchSheetState extends State<YtmSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  _Category _selectedCategory = _Category.songs;
  bool _isLoading = false;
  List<YtmSearchResult> _results = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<YtmSearchResult> results;
      switch (_selectedCategory) {
        case _Category.songs:
          results = await YtMusicSearchService.instance.searchSongs(query);
          break;
        case _Category.playlists:
          results = await YtMusicSearchService.instance.searchPlaylists(query);
          break;
        case _Category.albums:
          results = await YtMusicSearchService.instance.searchAlbums(query);
          break;
        case _Category.videos:
          results = await YtMusicSearchService.instance.searchVideos(query);
          break;
      }

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          _error = results.isEmpty ? 'No results found' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Search failed. Check your connection.';
        });
      }
    }
  }

  void _selectResult(YtmSearchResult result) {
    Navigator.of(context).pop();
    widget.onResultSelected(result.url);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Drag handle ────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFFFF0000),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YouTube Music Search',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Search songs, playlists, albums',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Search field ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppColors.primary
                      : AppColors.surfaceBorder,
                  width: _focusNode.hasFocus ? 1.5 : 1,
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      onSubmitted: _search,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Arijit Singh, 90s Bollywood...',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _onQueryChanged('');
                      },
                      child: Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 18),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Category chips ────────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _Category.values.map((cat) {
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      if (_searchCtrl.text.trim().isNotEmpty) {
                        _search(_searchCtrl.text.trim());
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceBorder,
                        ),
                      ),
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.onPrimary
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          Divider(color: AppColors.surfaceBorder, height: 1),

          // ── Results ───────────────────────────────────────────────────────
          Expanded(
            child: _buildBody(),
          ),

          SizedBox(height: mediaQuery.padding.bottom),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Searching YouTube Music...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty && _searchCtrl.text.trim().isEmpty) {
      return _buildEmptyState();
    }

    if (_error != null && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) => _ResultTile(
        result: _results[index],
        onTap: () => _selectResult(_results[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Icon(
                Icons.library_music_rounded,
                color: AppColors.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Search YouTube Music',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Find songs, playlists, and albums.\nSelect a result to auto-fill the download link.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Quick suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                '90s Bollywood',
                'Arijit Singh',
                'Lofi Hip Hop',
                'Punjabi Hits',
              ].map((s) => _SuggestionChip(
                    label: s,
                    onTap: () {
                      _searchCtrl.text = s;
                      _onQueryChanged(s);
                    },
                  )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category enum ────────────────────────────────────────────────────────────

enum _Category {
  songs('Songs'),
  playlists('Playlists'),
  albums('Albums'),
  videos('Videos');

  const _Category(this.label);
  final String label;
}

// ── Result tile ──────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});

  final YtmSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: result.thumbnailUrl != null
                  ? Image.network(
                      result.thumbnailUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (result.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      result.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Type badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _badgeColor(result.type).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                result.typeLabel,
                style: TextStyle(
                  color: _badgeColor(result.type),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        result.type == 'playlist' || result.type == 'album'
            ? Icons.queue_music_rounded
            : Icons.music_note_rounded,
        color: AppColors.textMuted,
        size: 22,
      ),
    );
  }

  Color _badgeColor(String type) {
    switch (type) {
      case 'song':
        return const Color(0xFF10B981);
      case 'playlist':
      case 'community_playlist':
      case 'featured_playlist':
        return const Color(0xFF6366F1);
      case 'album':
        return const Color(0xFFF59E0B);
      case 'video':
        return const Color(0xFFEF4444);
      default:
        return AppColors.textSecondary;
    }
  }
}

// ── Suggestion chip ──────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up_rounded,
                size: 13, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
