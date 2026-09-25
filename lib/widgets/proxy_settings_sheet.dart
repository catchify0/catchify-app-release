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
import 'package:catchify/models/proxy_model.dart';
import 'package:catchify/services/proxy_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/language_utils.dart';

class ProxySettingsSheet extends StatefulWidget {
  const ProxySettingsSheet({super.key});

  @override
  State<ProxySettingsSheet> createState() => _ProxySettingsSheetState();
}

class _ProxySettingsSheetState extends State<ProxySettingsSheet> {
  late final TextEditingController _customProxyController;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _customProxyController = TextEditingController(
      text: customProxyNotifier.value,
    );
  }

  @override
  void dispose() {
    _customProxyController.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    final res = await ProxyManager().testProxyConnection(
      customAddress: _customProxyController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testSuccess = res['success'] == true;
      _testResult = res['message']?.toString() ?? 'Test finished';
    });
  }

  void _saveCustomProxy() {
    final text = _customProxyController.text.trim();
    setCustomProxyAddress(text);
    if (proxyModeNotifier.value != ProxyMode.custom) {
      setProxyMode(ProxyMode.custom);
    }
    showToast(context, 'Custom proxy saved');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentCountry = getCountryByCode(contentCountryPreference);

    return ValueListenableBuilder<ProxyMode>(
      valueListenable: proxyModeNotifier,
      builder: (context, currentMode, _) {
        final isEnabled = currentMode != ProxyMode.off;

        return ValueListenableBuilder<ProxyStatus>(
          valueListenable: ProxyManager().proxyStatusNotifier,
          builder: (context, status, _) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 18,
                right: 18,
                top: 4,
                bottom: 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Bar with close icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusControl,
                              ),
                            ),
                            child: Icon(
                              FluentIcons.shield_keyhole_24_filled,
                              color: colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Proxy & Regional Routing',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Smart bypass for geo-blocked songs',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.dismiss_20_regular),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Master Toggle Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? colorScheme.primary.withValues(alpha: 0.08)
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusMedium,
                      ),
                      border: Border.all(
                        color: isEnabled
                            ? colorScheme.primary.withValues(alpha: 0.35)
                            : colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEnabled ? 'Proxy Enabled' : 'Proxy Disabled',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isEnabled ? colorScheme.primary : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEnabled
                                    ? currentMode.displayName
                                    : 'Direct connection (fastest, standard)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isEnabled,
                          activeColor: colorScheme.primary,
                          onChanged: (val) {
                            if (val) {
                              setProxyMode(ProxyMode.auto);
                              showToast(context, 'Smart Auto-Proxy activated');
                            } else {
                              setProxyMode(ProxyMode.off);
                              showToast(context, 'Proxy disabled');
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // Mode Selector (Visible when Enabled)
                  if (isEnabled) ...[
                    const SizedBox(height: 16),
                    Text(
                      'ROUTING MODE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Smart Auto Chip/Tile
                    _buildModeTile(
                      context: context,
                      mode: ProxyMode.auto,
                      title: 'Smart Auto (Recommended)',
                      subtitle:
                          'Direct 0ms speed. Auto-activates proxy only if track fails or is blocked.',
                      icon: FluentIcons.flash_24_regular,
                      isSelected: currentMode == ProxyMode.auto,
                      badge: 'FASTEST',
                      badgeColor: Colors.green,
                      onTap: () {
                        setProxyMode(ProxyMode.auto);
                        showToast(context, 'Smart Auto mode active');
                      },
                    ),

                    const SizedBox(height: 8),

                    // Country Match Chip/Tile
                    _buildModeTile(
                      context: context,
                      mode: ProxyMode.countryMatch,
                      title: 'Match Region (${currentCountry.code})',
                      subtitle:
                          'Routes through proxies in ${currentCountry.name} to match your selected region.',
                      icon: FluentIcons.globe_24_regular,
                      isSelected: currentMode == ProxyMode.countryMatch,
                      badge: currentCountry.code,
                      badgeColor: colorScheme.primary,
                      onTap: () {
                        setProxyMode(ProxyMode.countryMatch);
                        showToast(
                          context,
                          'Country Match (${currentCountry.code}) active',
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Custom Proxy Chip/Tile
                    _buildModeTile(
                      context: context,
                      mode: ProxyMode.custom,
                      title: 'Custom Server',
                      subtitle: 'Use your own private HTTP or SOCKS proxy.',
                      icon: FluentIcons.server_24_regular,
                      isSelected: currentMode == ProxyMode.custom,
                      onTap: () {
                        setProxyMode(ProxyMode.custom);
                      },
                    ),

                    // Custom Proxy Input Field
                    if (currentMode == ProxyMode.custom) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.25,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMedium,
                          ),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customProxyController,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'e.g. 192.168.1.100:8080',
                                      labelText: 'Server IP : Port',
                                      prefixIcon: const Icon(
                                        FluentIcons.link_20_regular,
                                        size: 20,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppTokens.radiusControl,
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (_) => _saveCustomProxy(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  icon: const Icon(FluentIcons.save_20_regular),
                                  tooltip: 'Save',
                                  onPressed: _saveCustomProxy,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 16),

                  // Connection Health & Ping Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusMedium,
                      ),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: !isEnabled
                                ? colorScheme.outline
                                : (status.isActive
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testResult ??
                                (status.message ??
                                    (isEnabled
                                        ? 'Standby (0ms delay)'
                                        : 'Direct connection')),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _testSuccess == true
                                  ? Colors.greenAccent
                                  : (_testSuccess == false
                                        ? Colors.redAccent
                                        : colorScheme.onSurfaceVariant),
                              fontWeight: _testResult != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _isTesting ? null : _runTest,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusPill,
                              ),
                            ),
                          ),
                          child: _isTesting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      FluentIcons.pulse_20_regular,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ping',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModeTile({
    required BuildContext context,
    required ProxyMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected ? colorScheme.primary : null,
                            fontSize: 13,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? colorScheme.primary)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusPill,
                              ),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: badgeColor ?? colorScheme.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<ProxyMode>(
                value: mode,
                groupValue: proxyModeNotifier.value,
                onChanged: (_) => onTap(),
                activeColor: colorScheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
