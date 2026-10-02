/*
 *     Copyright (C) 2026 Thamodharan Ganesan
 *
 *     Catchify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Catchify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/catchify0/catchify0.github.io
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/language_utils.dart';

/// Opens the unified Language & Region setup bottom sheet.
/// [initialTab] 0 = Region, 1 = Music Language.
Future<void> showLanguageRegionSetupSheet(
  BuildContext context, {
  int initialTab = 0,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppTokens.radiusSheet),
        topRight: Radius.circular(AppTokens.radiusSheet),
      ),
    ),
    builder: (context) => LanguageRegionSetupSheet(initialTab: initialTab),
  );
}

/// Convenience aliases for backward compatibility and focused entry points.
Future<void> showRegionSwitcherSheet(BuildContext context) =>
    showLanguageRegionSetupSheet(context);

Future<void> showMusicLanguageSwitcherSheet(BuildContext context) =>
    showLanguageRegionSetupSheet(context, initialTab: 1);

class LanguageRegionSetupSheet extends StatefulWidget {
  const LanguageRegionSetupSheet({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  State<LanguageRegionSetupSheet> createState() =>
      _LanguageRegionSetupSheetState();
}

class _LanguageRegionSetupSheetState extends State<LanguageRegionSetupSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _countrySearchController = TextEditingController();
  final TextEditingController _languageSearchController = TextEditingController();

  String _countryFilter = '';
  String _languageFilter = '';

  static const _popularCountryCodes = ['GLOBAL', 'US', 'GB', 'IN', 'JP', 'KR'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );

    _countrySearchController.addListener(() {
      setState(() {
        _countryFilter = _countrySearchController.text.trim().toLowerCase();
      });
    });

    _languageSearchController.addListener(() {
      setState(() {
        _languageFilter = _languageSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countrySearchController.dispose();
    _languageSearchController.dispose();
    super.dispose();
  }

  void _selectCountry(CountryOption country) {
    if (contentCountryPreference != country.code) {
      setContentCountryPreference(country.code);
      showToast(context, '${country.flag} ${country.name} selected');

      // If user's current music language is not among country's primary languages,
      // switch to Language tab smoothly so user can align their language if they want!
      final currentLang = contentLanguagePreference ?? 'en';
      if (!country.primaryLanguages.contains(currentLang) &&
          country.primaryLanguages.isNotEmpty) {
        _tabController.animateTo(1);
        return;
      }
    }
    Navigator.of(context).pop();
  }

  void _selectLanguage(MusicLanguageOption lang) {
    if (contentLanguagePreference != lang.code) {
      setContentLanguagePreference(lang.code);
      showToast(context, '🎵 ${lang.nativeName} (${lang.englishName}) selected');
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.50,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTokens.radiusSheet),
              topRight: Radius.circular(AppTokens.radiusSheet),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                  ),
                ),
              ),

              // Title and Current Status Banner
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        FluentIcons.globe_search_24_filled,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Language & Region Setup',
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Charts, trending hits & music recommendation preferences',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Quick Status Summary Pills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: contentCountryPreferenceNotifier,
                      builder: (context, countryCode, _) {
                        final country = getCountryByCode(countryCode);
                        return Expanded(
                          child: InkWell(
                            onTap: () => _tabController.animateTo(0),
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusCard),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusCard),
                                border: Border.all(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    country.flag,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      country.code == 'GLOBAL'
                                          ? 'Global'
                                          : country.name,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<String?>(
                      valueListenable: contentLanguagePreferenceNotifier,
                      builder: (context, langCode, _) {
                        final lang = getMusicLanguageByCode(langCode);
                        return Expanded(
                          child: InkWell(
                            onTap: () => _tabController.animateTo(1),
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusCard),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusCard),
                                border: Border.all(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FluentIcons.music_note_2_20_filled,
                                    size: 14,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${lang.nativeName} (${lang.englishName})',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Segmented Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    labelColor: colorScheme.onPrimary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(
                        iconMargin: EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.globe_20_regular, size: 16),
                            SizedBox(width: 6),
                            Text('Region / Country'),
                          ],
                        ),
                      ),
                      Tab(
                        iconMargin: EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.music_note_2_20_regular, size: 16),
                            SizedBox(width: 6),
                            Text('Music Language'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRegionTab(context, scrollController, colorScheme),
                    _buildLanguageTab(context, scrollController, colorScheme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegionTab(
    BuildContext context,
    ScrollController scrollController,
    ColorScheme colorScheme,
  ) {
    final currentCountryCode = contentCountryPreference;
    final filteredCountries = supportedCountries.where((c) {
      if (_countryFilter.isEmpty) return true;
      return c.name.toLowerCase().contains(_countryFilter) ||
          c.code.toLowerCase().contains(_countryFilter) ||
          c.flag.contains(_countryFilter);
    }).toList();

    return Column(
      children: [
        // Search Box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _countrySearchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search country or region...',
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 13.5,
              ),
              prefixIcon: Icon(
                FluentIcons.search_20_regular,
                size: 20,
                color: colorScheme.primary,
              ),
              suffixIcon: _countryFilter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _countrySearchController.clear,
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Quick Popular Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _popularCountryCodes.map((code) {
              final country = getCountryByCode(code);
              final isSelected = currentCountryCode == country.code;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Text(
                    country.flag,
                    style: const TextStyle(fontSize: 14),
                  ),
                  label: Text(
                    country.code == 'GLOBAL' ? 'Global' : country.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  checkmarkColor: colorScheme.onPrimary,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  onSelected: (_) => _selectCountry(country),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),
        const Divider(height: 1, indent: 16, endIndent: 16),

        // Countries list
        Expanded(
          child: filteredCountries.isEmpty
              ? Center(
                  child: Text(
                    'No matching countries found',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: filteredCountries.length,
                  itemBuilder: (context, index) {
                    final country = filteredCountries[index];
                    final isSelected = currentCountryCode == country.code;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Material(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusCard),
                        child: InkWell(
                          onTap: () => _selectCountry(country),
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusCard),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  country.flag,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        country.name,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        getCountryChartQuery(country.code),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLanguageTab(
    BuildContext context,
    ScrollController scrollController,
    ColorScheme colorScheme,
  ) {
    final currentCountry = getCountryByCode(contentCountryPreference);
    final currentLanguageCode = resolveContentLanguageCode(
      contentLanguagePreference ?? 'en',
    );

    // Primary languages for the currently selected region
    final primaryCodes = currentCountry.primaryLanguages;

    // Filter languages
    final filteredLanguages = supportedMusicLanguages.where((l) {
      if (_languageFilter.isEmpty) return true;
      return l.englishName.toLowerCase().contains(_languageFilter) ||
          l.nativeName.toLowerCase().contains(_languageFilter) ||
          l.code.toLowerCase().contains(_languageFilter);
    }).toList();

    // Split into recommended for this region vs others
    final recommended = <MusicLanguageOption>[];
    final others = <MusicLanguageOption>[];

    for (final lang in filteredLanguages) {
      if (primaryCodes.contains(lang.code)) {
        recommended.add(lang);
      } else {
        others.add(lang);
      }
    }

    // Sort recommended by order in primaryLanguages
    recommended.sort((a, b) {
      final aIdx = primaryCodes.indexOf(a.code);
      final bIdx = primaryCodes.indexOf(b.code);
      return aIdx.compareTo(bIdx);
    });

    return Column(
      children: [
        // Search Box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _languageSearchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search music language (e.g. Tamil, தமிழ், English)...',
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 13.5,
              ),
              prefixIcon: Icon(
                FluentIcons.search_20_regular,
                size: 20,
                color: colorScheme.primary,
              ),
              suffixIcon: _languageFilter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _languageSearchController.clear,
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              // Recommended Section
              if (recommended.isNotEmpty) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        currentCountry.flag,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Recommended for ${currentCountry.name}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                ...recommended.map((lang) => _buildLanguageTile(
                      lang,
                      currentLanguageCode,
                      colorScheme,
                      isRecommended: true,
                    )),
                const SizedBox(height: 8),
                const Divider(height: 1, indent: 8, endIndent: 8),
                const SizedBox(height: 8),
              ],

              // All Other Languages Section
              if (others.isNotEmpty) ...[
                if (recommended.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Text(
                      'All Languages',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ...others.map((lang) => _buildLanguageTile(
                      lang,
                      currentLanguageCode,
                      colorScheme,
                      isRecommended: false,
                    )),
              ],

              if (recommended.isEmpty && others.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No matching languages found',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageTile(
    MusicLanguageOption lang,
    String currentLanguageCode,
    ColorScheme colorScheme, {
    required bool isRecommended,
  }) {
    final isSelected = currentLanguageCode == lang.code;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: InkWell(
          onTap: () => _selectLanguage(lang),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lang.code.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.nativeName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang.englishName,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: colorScheme.onPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
