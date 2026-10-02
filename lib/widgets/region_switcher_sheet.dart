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

Future<void> showRegionSwitcherSheet(BuildContext context) {
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
    builder: (context) => const RegionSwitcherSheet(),
  );
}

class RegionSwitcherSheet extends StatefulWidget {
  const RegionSwitcherSheet({super.key});

  @override
  State<RegionSwitcherSheet> createState() => _RegionSwitcherSheetState();
}

class _RegionSwitcherSheetState extends State<RegionSwitcherSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  static const _popularCodes = ['GLOBAL', 'US', 'GB', 'IN', 'JP', 'KR'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _filter = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCountry(CountryOption country) {
    if (contentCountryPreference != country.code) {
      setContentCountryPreference(country.code);
      showToast(context, '${country.flag} ${country.name} selected');
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentCode = contentCountryPreference;

    final filteredCountries = supportedCountries.where((c) {
      if (_filter.isEmpty) return true;
      return c.name.toLowerCase().contains(_filter) ||
          c.code.toLowerCase().contains(_filter) ||
          c.flag.contains(_filter);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
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
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                  ),
                ),
              ),

              // Title and Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        FluentIcons.globe_24_filled,
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
                            'Music Region & Charts',
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Switch global charts, trending music & releases',
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

              const SizedBox(height: 12),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
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
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _searchController.clear,
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
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
                  children: _popularCodes.map((code) {
                    final country = getCountryByCode(code);
                    final isSelected = currentCode == country.code;
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
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusPill),
                          side: BorderSide(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
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

              // Country list
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
                          final isSelected = currentCode == country.code;

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
          ),
        );
      },
    );
  }
}
