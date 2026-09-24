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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentCountry = getCountryByCode(contentCountryPreference);

    return ValueListenableBuilder<ProxyMode>(
      valueListenable: proxyModeNotifier,
      builder: (context, currentMode, _) {
        return ValueListenableBuilder<ProxyStatus>(
          valueListenable: ProxyManager().proxyStatusNotifier,
          builder: (context, status, _) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          FluentIcons.shield_keyhole_24_filled,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Advanced Proxy & Routing',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Bypass regional blocks & customize connection',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Status Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusMedium,
                      ),
                      border: Border.all(
                        color: status.isActive
                            ? colorScheme.primary.withValues(alpha: 0.4)
                            : colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentMode == ProxyMode.off
                                ? colorScheme.outline
                                : (status.isActive
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentMode.displayName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                status.message ?? currentMode.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (status.latencyMs != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusPill,
                              ),
                            ),
                            child: Text(
                              '${status.latencyMs}ms',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Mode Options
                  _buildModeOption(
                    context: context,
                    mode: ProxyMode.auto,
                    title: 'Smart Auto-Failover (Recommended)',
                    subtitle:
                        'Direct streaming by default (0ms). Auto-activates proxy only if track fails or is geo-blocked.',
                    icon: FluentIcons.flash_24_regular,
                    isSelected: currentMode == ProxyMode.auto,
                    onTap: () {
                      setProxyMode(ProxyMode.auto);
                      showToast(context, 'Smart Auto-Proxy activated');
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildModeOption(
                    context: context,
                    mode: ProxyMode.countryMatch,
                    title: 'Country Matched (${currentCountry.code})',
                    subtitle:
                        'Routes requests through proxies in ${currentCountry.name} to match selected Music Region.',
                    icon: FluentIcons.globe_24_regular,
                    isSelected: currentMode == ProxyMode.countryMatch,
                    onTap: () {
                      setProxyMode(ProxyMode.countryMatch);
                      showToast(
                        context,
                        'Country Matched (${currentCountry.code}) proxy set',
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildModeOption(
                    context: context,
                    mode: ProxyMode.custom,
                    title: 'Custom Proxy',
                    subtitle: 'Use your own private HTTP / SOCKS proxy server.',
                    icon: FluentIcons.server_24_regular,
                    isSelected: currentMode == ProxyMode.custom,
                    onTap: () {
                      setProxyMode(ProxyMode.custom);
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildModeOption(
                    context: context,
                    mode: ProxyMode.off,
                    title: 'Disabled (Direct Only)',
                    subtitle:
                        'Direct connection only. No proxy routing will be used.',
                    icon: FluentIcons.dismiss_circle_24_regular,
                    isSelected: currentMode == ProxyMode.off,
                    onTap: () {
                      setProxyMode(ProxyMode.off);
                      showToast(context, 'Proxy disabled');
                    },
                  ),

                  if (currentMode == ProxyMode.custom) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _customProxyController,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        labelText: 'Custom Proxy Server',
                        hintText: 'e.g. 192.168.1.100:8080 or host:port',
                        prefixIcon: const Icon(FluentIcons.link_24_regular),
                        suffixIcon: IconButton(
                          icon: const Icon(FluentIcons.save_24_regular),
                          onPressed: () {
                            setCustomProxyAddress(
                              _customProxyController.text.trim(),
                            );
                            showToast(context, 'Custom proxy saved');
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusControl,
                          ),
                        ),
                      ),
                      onSubmitted: (v) {
                        setCustomProxyAddress(v.trim());
                        showToast(context, 'Custom proxy saved');
                      },
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Test Connection Button & Result
                  FilledButton.tonalIcon(
                    onPressed: _isTesting ? null : _runTest,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(FluentIcons.pulse_24_regular),
                    label: Text(
                      _isTesting ? 'Testing connection...' : 'Test Connection',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusControl,
                        ),
                      ),
                    ),
                  ),

                  if (_testResult != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_testSuccess == true
                                ? Colors.green
                                : Colors.red)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testSuccess == true
                                ? FluentIcons.checkmark_circle_24_regular
                                : FluentIcons.error_circle_24_regular,
                            size: 18,
                            color: _testSuccess == true
                                ? Colors.green
                                : Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _testSuccess == true
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required ProxyMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
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
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
