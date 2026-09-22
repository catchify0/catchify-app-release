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

import 'dart:async';

import 'package:flutter/material.dart';

class MarqueeWidget extends StatefulWidget {
  const MarqueeWidget({
    super.key,
    required this.child,
    this.direction = Axis.horizontal,
    this.animationDuration = const Duration(milliseconds: 6000),
    this.backDuration = const Duration(milliseconds: 800),
    this.pauseDuration = const Duration(milliseconds: 800),
    this.manualScrollEnabled = true,
  });

  final Widget child;
  final Axis direction;
  final Duration animationDuration, backDuration, pauseDuration;
  final bool manualScrollEnabled;

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  Timer? _timer;
  Completer<bool>? _sleepCompleter;
  bool _isAnimating = false;
  bool _isDisposed = false;
  bool _disableAnimations = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  @override
  void didUpdateWidget(MarqueeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_disableAnimations == disableAnimations) return;

    _disableAnimations = disableAnimations;
    if (_disableAnimations) {
      _cancelPendingSleep();
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.jumpTo(0);
      }
    } else if (!_isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelPendingSleep();
    _scrollController.dispose();
    super.dispose();
  }

  void _cancelPendingSleep() {
    _timer?.cancel();
    _timer = null;
    final completer = _sleepCompleter;
    _sleepCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
  }

  Future<bool> _sleep(Duration duration) {
    _cancelPendingSleep();
    final completer = Completer<bool>();
    _sleepCompleter = completer;
    _timer = Timer(duration, () {
      _timer = null;
      _sleepCompleter = null;
      if (!_isDisposed && !_disableAnimations) {
        completer.complete(true);
      } else {
        completer.complete(false);
      }
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: widget.direction,
        controller: _scrollController,
        physics: widget.manualScrollEnabled
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: widget.child,
      ),
    );
  }

  Future<void> _startAnimation() async {
    if (_isDisposed || _isAnimating || _disableAnimations) return;

    _isAnimating = true;

    while (_scrollController.hasClients &&
        !_isDisposed &&
        !_disableAnimations) {
      try {
        if (_scrollController.position.maxScrollExtent <= 0) {
          break;
        }

        final paused = await _sleep(widget.pauseDuration);
        if (!paused || _isDisposed || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.animationDuration,
          curve: Curves.linear,
        );

        final pausedAfter = await _sleep(widget.pauseDuration);
        if (!pausedAfter || _isDisposed || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          0,
          duration: widget.backDuration,
          curve: Curves.easeOut,
        );
      } catch (e) {
        break;
      }
    }

    _isAnimating = false;
  }
}
