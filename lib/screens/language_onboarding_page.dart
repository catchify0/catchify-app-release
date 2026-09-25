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
 *
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/catchify0/catchify0.github.io
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/utilities/language_utils.dart';

class _LanguageOption {
  const _LanguageOption(this.code, this.native, this.english);

  final String code;
  final String native;
  final String english;
}

const _allLanguages = [
  _LanguageOption('ta', 'தமிழ்', 'Tamil'),
  _LanguageOption('hi', 'हिंदी', 'Hindi'),
  _LanguageOption('te', 'తెలుగు', 'Telugu'),
  _LanguageOption('en', 'English', 'English'),
  _LanguageOption('ml', 'മലയാളം', 'Malayalam'),
  _LanguageOption('kn', 'ಕನ್ನಡ', 'Kannada'),
  _LanguageOption('pa', 'ਪੰਜਾਬੀ', 'Punjabi'),
  _LanguageOption('es', 'Español', 'Spanish / Latin'),
  _LanguageOption('ko', '한국어', 'Korean / K-Pop'),
  _LanguageOption('ja', '日本語', 'Japanese / J-Pop'),
  _LanguageOption('fr', 'Français', 'French'),
  _LanguageOption('de', 'Deutsch', 'German'),
  _LanguageOption('pt', 'Português', 'Portuguese'),
  _LanguageOption('id', 'Bahasa Indonesia', 'Indonesian'),
  _LanguageOption('ar', 'العربية', 'Arabic'),
  _LanguageOption('mr', 'मराठी', 'Marathi'),
  _LanguageOption('bn', 'বাংলা', 'Bengali'),
  _LanguageOption('gu', 'ગુજરાતી', 'Gujarati'),
  _LanguageOption('ur', 'اردو', 'Urdu'),
  _LanguageOption('it', 'Italiano', 'Italian'),
  _LanguageOption('tr', 'Türkçe', 'Turkish'),
  _LanguageOption('ru', 'Русский', 'Russian'),
  _LanguageOption('or', 'ଓଡ଼ିଆ', 'Odia'),
  _LanguageOption('as', 'অসমীয়া', 'Assamese'),
  _LanguageOption('sa', 'संस्कृतम्', 'Sanskrit'),
  _LanguageOption('kok', 'कोंकणी', 'Konkani'),
];

class LanguageOnboardingPage extends StatefulWidget {
  const LanguageOnboardingPage({super.key});

  @override
  State<LanguageOnboardingPage> createState() => _LanguageOnboardingPageState();
}

class _LanguageOnboardingPageState extends State<LanguageOnboardingPage> {
  late final PageController _pageController;
  int _currentStep = 0;
  String _selectedCountry = contentCountryPreference;
  String? _selectedLanguageCode;
  bool _isProcessing = false;
  String _countrySearch = '';
  final TextEditingController _countrySearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _countrySearchController.dispose();
    super.dispose();
  }

  void _onCountrySelected(String countryCode) {
    setState(() {
      _selectedCountry = countryCode;
      _currentStep = 1;
    });
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _backToCountryStep() {
    setState(() => _currentStep = 0);
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _completeOnboarding(String languageCode) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _selectedLanguageCode = languageCode;
    });

    try {
      await completeContentLanguageOnboarding(
        languageCode,
        selectedCountryCode: _selectedCountry,
      );

      if (!mounted) return;

      context.go(NavigationManager.homePath, extra: {'freshLoad': true});
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _skipOnboarding() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await completeContentLanguageOnboarding(
        'en',
        selectedCountryCode: _selectedCountry,
      );
      if (!mounted) return;
      context.go(NavigationManager.homePath, extra: {'freshLoad': true});
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  List<_LanguageOption> _getSortedLanguages() {
    final country = getCountryByCode(_selectedCountry);
    final primary = country.primaryLanguages;

    if (primary.isEmpty) return _allLanguages;

    final priorityList = <_LanguageOption>[];
    final remainingList = <_LanguageOption>[];

    for (final lang in _allLanguages) {
      if (primary.contains(lang.code)) {
        priorityList.add(lang);
      } else {
        remainingList.add(lang);
      }
    }

    // Sort priority by the order declared in country.primaryLanguages
    priorityList.sort((a, b) {
      final aIdx = primary.indexOf(a.code);
      final bIdx = primary.indexOf(b.code);
      return aIdx.compareTo(bIdx);
    });

    return [...priorityList, ...remainingList];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final skipText = l10n?.skip ?? 'Skip';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep == 1
            ? IconButton(
                icon: const Icon(FluentIcons.chevron_left_24_regular),
                tooltip: 'Back to Country',
                onPressed: _backToCountryStep,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentStep == 0
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentStep == 1
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _skipOnboarding,
            child: Text(
              skipText,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildCountryStep(colorScheme),
            _buildLanguageStep(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryStep(ColorScheme colorScheme) {
    final filteredCountries = supportedCountries.where((c) {
      final q = _countrySearch.trim().toLowerCase();
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your country',
                style: AppTextStyles.pageTitle.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select your region for charts, trending hits, and music releases.',
                style: AppTextStyles.body.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _countrySearchController,
                onChanged: (val) => setState(() => _countrySearch = val),
                decoration: InputDecoration(
                  hintText: 'Search countries...',
                  prefixIcon: const Icon(FluentIcons.search_24_regular),
                  suffixIcon: _countrySearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(FluentIcons.dismiss_24_regular),
                          onPressed: () {
                            _countrySearchController.clear();
                            setState(() => _countrySearch = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: filteredCountries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final country = filteredCountries[index];
              final isSelected = _selectedCountry == country.code;
              return Material(
                color: isSelected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.8)
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _onCountrySelected(country.code),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Text(
                          country.flag,
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            country.name,
                            style: TextStyle(
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            FluentIcons.checkmark_circle_20_filled,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                      ],
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

  Widget _buildLanguageStep(ColorScheme colorScheme) {
    final sortedLanguages = _getSortedLanguages();
    final chosenCountry = getCountryByCode(_selectedCountry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your language',
                style: AppTextStyles.pageTitle.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick the language you want to discover and listen to.',
                style: AppTextStyles.body.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _backToCountryStep,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chosenCountry.flag,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Region: ${chosenCountry.name}',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        FluentIcons.arrow_repeat_all_20_regular,
                        size: 13,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedLanguages.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                ),
                itemBuilder: (context, index) {
                  final language = sortedLanguages[index];
                  final isSelected = _selectedLanguageCode == language.code;
                  return _LanguageCard(
                    language: language,
                    isSelected: isSelected,
                    onTap: () => _completeOnboarding(language.code),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final _LanguageOption language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.85)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);

    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant.withValues(alpha: 0.35);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      language.native,
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      FluentIcons.checkmark_circle_20_filled,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                ],
              ),
              Text(
                language.english,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                      : colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
