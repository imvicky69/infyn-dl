import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user_preferences.dart';
import '../services/user_preferences_service.dart';

/// Interactive modal sheet allowing users to customize their local music preferences
/// (languages, genres, moods) without needing an account or cloud sync.
class PreferenceSelectionSheet extends StatefulWidget {
  const PreferenceSelectionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PreferenceSelectionSheet(),
    );
  }

  @override
  State<PreferenceSelectionSheet> createState() =>
      _PreferenceSelectionSheetState();
}

class _PreferenceSelectionSheetState extends State<PreferenceSelectionSheet> {
  late final Set<String> _selectedLanguages;
  late final Set<String> _selectedGenres;
  late final Set<String> _selectedMoods;

  @override
  void initState() {
    super.initState();
    final current = UserPreferencesService.instance.preferences;
    _selectedLanguages = current.languages.toSet();
    _selectedGenres = current.genres.toSet();
    _selectedMoods = current.moods.toSet();
  }

  void _saveAndClose() {
    final updated = UserPreferences(
      languages: _selectedLanguages.toList(),
      genres: _selectedGenres.toList(),
      moods: _selectedMoods.toList(),
      isOnboarded: true,
    );
    UserPreferencesService.instance.updatePreferences(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalize Your Feed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '100% private & on-device • Tailors "For You"',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollable Sections
          Expanded(
            child: ListView(
              children: [
                _buildSectionTitle(
                    'Preferred Languages', Icons.language_rounded),
                _buildChipGroup(
                  items: UserPreferences.availableLanguages,
                  selected: _selectedLanguages,
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('Favorite Genres', Icons.music_note_rounded),
                _buildChipGroup(
                  items: UserPreferences.availableGenres,
                  selected: _selectedGenres,
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('Listening Moods', Icons.mood_rounded),
                _buildChipGroup(
                  items: UserPreferences.availableMoods,
                  selected: _selectedMoods,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    UserPreferencesService.instance.completeOnboarding();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Explore All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saveAndClose,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save & Tune Feed'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipGroup({
    required List<String> items,
    required Set<String> selected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = selected.contains(item);
        return FilterChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (checked) {
            setState(() {
              if (checked) {
                selected.add(item);
              } else {
                selected.remove(item);
              }
            });
          },
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primary.withValues(alpha: 0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
            ),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
