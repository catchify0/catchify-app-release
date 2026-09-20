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

class _LanguageOption {
  const _LanguageOption(this.code, this.native, this.english);

  final String code;
  final String native;
  final String english;
}

const _priorityLanguages = [
  _LanguageOption('ta', 'தமிழ்', 'Tamil'),
  _LanguageOption('hi', 'हिंदी', 'Hindi'),
  _LanguageOption('te', 'తెలుగు', 'Telugu'),
  _LanguageOption('en', 'English', 'English'),
  _LanguageOption('ml', 'മലയാളം', 'Malayalam'),
  _LanguageOption('kn', 'ಕನ್ನಡ', 'Kannada'),
  _LanguageOption('pa', 'ਪੰਜਾਬੀ', 'Punjabi'),
  _LanguageOption('mr', 'मराठी', 'Marathi'),
  _LanguageOption('bn', 'বাংলা', 'Bengali'),
  _LanguageOption('gu', 'ગુજરાતી', 'Gujarati'),
  _LanguageOption('ur', 'اردو', 'Urdu'),
  _LanguageOption('or', 'ଓଡ଼ିଆ', 'Odia'),
  _LanguageOption('as', 'অসমীয়া', 'Assamese'),
  _LanguageOption('sa', 'संस्कृतम्', 'Sanskrit'),
  _LanguageOption('kok', 'कोंकणी', 'Konkani'),
];

class LanguageOnboardingPage extends StatefulWidget {
  const LanguageOnboardingPage({super.key});

  @override
  State<LanguageOnboardingPage> createState() =>
      _LanguageOnboardingPageState();
}

class _LanguageOnboardingPageState extends State<LanguageOnboardingPage> {
  String? _selectedCode;
  bool _isProcessing = false;

  Future<void> _selectLanguage(String languageCode) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _selectedCode = languageCode;
    });

    try {
      // 1. Atomically persist contentLanguageCode and hasSeenLanguageOnboarding = true
      // App UI locale is deliberately preserved as English.
      await completeContentLanguageOnboarding(languageCode);

      if (!mounted) return;

      // 2. Navigate to Home with freshLoad flag so home feed performs fresh language-aware load
      context.go(
        NavigationManager.homePath,
        extra: {'freshLoad': true},
      );
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
      await completeContentLanguageOnboarding('en');
      if (!mounted) return;
      context.go(
        NavigationManager.homePath,
        extra: {'freshLoad': true},
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final l10n = context.l10n;
    const titleText = 'Choose your language';
    const descText =
        "Pick the language you'd like to hear and discover music in.";
    final skipText = l10n?.skip ?? 'Skip';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: AppTextStyles.pageTitle.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    descText,
                    style: AppTextStyles.body.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
                    itemCount: _priorityLanguages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                    ),
                    itemBuilder: (context, index) {
                      final language = _priorityLanguages[index];
                      final isSelected = _selectedCode == language.code;
                      return _LanguageCard(
                        language: language,
                        isSelected: isSelected,
                        onTap: () => _selectLanguage(language.code),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
