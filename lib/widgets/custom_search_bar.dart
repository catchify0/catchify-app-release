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

class CustomSearchBar extends StatefulWidget {
  const CustomSearchBar({
    super.key,
    required this.onSubmitted,
    required this.controller,
    required this.focusNode,
    required this.labelText,
    this.onChanged,
    this.loadingProgressNotifier,
  });
  final Function(String) onSubmitted;
  final ValueNotifier<bool>? loadingProgressNotifier;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final Function(String)? onChanged;

  @override
  _CustomSearchBarState createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFocused = widget.focusNode.hasFocus;
    final hasText = widget.controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SearchBar(
        elevation: WidgetStateProperty.all(0),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return colorScheme.surfaceContainerLow;
          }
          return colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
        }),
        surfaceTintColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return colorScheme.primary.withValues(alpha: 0.1);
          }
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: 0.08),
        ),
        shape: WidgetStateProperty.resolveWith((states) {
          final focused = states.contains(WidgetState.focused);
          return RoundedRectangleBorder(
            side: BorderSide(
              color: focused
                  ? colorScheme.primary.withValues(alpha: 0.72)
                  : colorScheme.outlineVariant.withValues(alpha: 0.75),
              width: focused ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(18),
          );
        }),
        constraints: const BoxConstraints(minHeight: 52),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 14),
        ),
        hintText: widget.labelText,
        hintStyle: WidgetStateProperty.all(
          TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        textStyle: WidgetStateProperty.all(
          TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Icon(
          FluentIcons.search_24_regular,
          color: isFocused
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          size: 22,
        ),
        onSubmitted: (String value) {
          widget.onSubmitted(value);
          widget.focusNode.unfocus();
        },
        onChanged: widget.onChanged != null
            ? (value) async {
                widget.onChanged!(value);
                setState(() {});
              }
            : null,
        textInputAction: TextInputAction.search,
        controller: widget.controller,
        focusNode: widget.focusNode,
        trailing: [
          if (hasText)
            IconButton(
              tooltip: 'Clear search',
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                FluentIcons.dismiss_24_regular,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () {
                widget.controller.clear();
                widget.onChanged?.call('');
                setState(() {});
              },
            ),
        ],
      ),
    );
  }
}
