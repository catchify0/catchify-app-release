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
import 'package:catchify/theme/app_text_styles.dart';

/// Standardized error state component.
/// Provides a friendly, calm message with an optional retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = "Couldn't load this",
    this.message = 'Check your connection and try again.',
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = FluentIcons.cloud_off_24_regular,
    this.compact = false,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20.0 : 32.0,
          vertical: compact ? 24.0 : 40.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 52 : 64,
              height: compact ? 52 : 64,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: compact ? 26 : 32,
                  color: colorScheme.error,
                ),
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.rowTitle.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: compact ? 15 : 17,
                ),
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: AppTextStyles.secondary.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: compact ? 14 : 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(
                  FluentIcons.arrow_clockwise_24_regular,
                  size: 18,
                ),
                label: Text(retryLabel),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, AppTokens.buttonHeightSmall),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sliver variant of ErrorState.
class SliverErrorState extends StatelessWidget {
  const SliverErrorState({
    super.key,
    this.title = "Couldn't load this",
    this.message = 'Check your connection and try again.',
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = FluentIcons.cloud_off_24_regular,
    this.compact = false,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: ErrorState(
        title: title,
        message: message,
        onRetry: onRetry,
        retryLabel: retryLabel,
        icon: icon,
        compact: compact,
      ),
    );
  }
}
