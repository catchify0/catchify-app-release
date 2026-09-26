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
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:catchify/main.dart';
import 'package:catchify/models/position_data.dart';
import 'package:catchify/services/android_auto_service.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/listening_stats_service.dart';
import 'package:catchify/services/io_service.dart';
import 'package:catchify/services/proxy_manager.dart';
import 'package:catchify/services/radio_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/utilities/map_utils.dart';
import 'package:catchify/utilities/mediaitem.dart';
import 'package:catchify/utilities/queue_entry_utils.dart';
import 'package:rxdart/rxdart.dart';

class CatchifyAudioHandler extends BaseAudioHandler {
  CatchifyAudioHandler() {
    if (Platform.isAndroid) {
      _androidEqualizer = AndroidEqualizer();
      audioPlayer = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_androidEqualizer]),
        audioLoadConfiguration: const AudioLoadConfiguration(
          androidLoadControl: AndroidLoadControl(
            maxBufferDuration: Duration(seconds: 60),
            bufferForPlaybackDuration: Duration(milliseconds: 500),
            bufferForPlaybackAfterRebufferDuration: Duration(
              milliseconds: 1500,
            ),
          ),
        ),
      );
      audioPlayer.setAndroidAudioAttributes(
        const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
      );
    } else {
      audioPlayer = AudioPlayer();
    }

    _setupEventSubscriptions();
    _updatePlaybackState();

    _initialize();
  }

  late final AndroidEqualizer _androidEqualizer;
  late final AudioPlayer audioPlayer;
  bool _equalizerInitialized = false;
  Future<bool>? _equalizerInitFuture;
  DateTime _equalizerRetryNotBefore = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _sleepTimer;
  Timer? _debounceTimer;
  bool sleepTimerExpired = false;
  bool sleepTimerEndOfSong = false;
  int? _sleepTimerRemainingSongs;

  final List<Map> _queueList = [];
  final List<Map> _originalQueueList = [];
  final List<Map> _historyList = [];
  final BehaviorSubject<List<Map>> _queueMapStream =
      BehaviorSubject<List<Map>>.seeded([]);
  final QueueEntryIdManager _queueEntryIds = QueueEntryIdManager();
  int _currentQueueIndex = 0;
  int _currentLoadingIndex = -1;
  int _currentLoadingTransitionId = -1;
  bool _isUpdatingState = false;
  bool _pendingPlaybackStateUpdate = false;
  bool _userRequestedPause = false;
  int _songTransitionCounter = 0;

  bool _completionEventPending = false;
  bool _completionHandlerLoadStarted = false;
  String? _lastCompletedSongId;
  String? _playerInferredDurationSongId;
  bool _interruptedPlayingState = false;
  bool _hasPreloadedCurrentTrackEnd = false;
  bool _isFetchingAutoplay = false;
  bool _autoplayForcePlayPending = false;
  Completer<void>? _activeAutoplayCompleter;
  static const int _autoplayPrefetchThreshold = 3;

  String? _lastError;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  static const int _maxHistorySize = 50;
  static const int _queueLookahead = 3;
  static const int _maxConcurrentPreloads = 2;
  static const Duration _errorRetryDelay = Duration(seconds: 2);
  static const Duration _songTransitionTimeout = Duration(seconds: 30);
  static const Duration _debounceInterval = Duration(milliseconds: 150);
  static const Duration _positionDataThreshold = Duration(milliseconds: 100);
  static const Duration _playbackStateHeartbeat = Duration(seconds: 1);

  /// Dynamically adjusts position data emission frequency. When the app is in
  /// the background or screen is off, throttles to 1000ms (saving 20-30% battery),
  /// and returns to 100ms for silky 60fps sliders when user is actively in the app.
  static Duration get _dynamicPositionThreshold {
    try {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) {
        return const Duration(seconds: 1);
      }
    } catch (_) {}
    return _positionDataThreshold;
  }

  static const String _recentMediaIdPrefix = 'recent:';

  int _activePreloadCount = 0;
  final Set<String> _preloadingYtIds = <String>{};
  final Set<String> _preloadedYtIds = <String>{};
  Duration? _restoredPosition;
  int _lastSavedPositionMs = 0;

  late final Stream<PositionData> _positionDataStream =
      Rx.combineLatest4<
            Duration,
            Duration,
            Duration?,
            MediaItem?,
            PositionData
          >(
            audioPlayer.positionStream,
            audioPlayer.bufferedPositionStream,
            audioPlayer.durationStream,
            mediaItem,
            (position, bufferedPosition, duration, currentItem) {
              final itemDuration = currentItem?.duration;
              final effectiveDuration =
                  (itemDuration != null && itemDuration > Duration.zero)
                  ? itemDuration
                  : (duration ?? Duration.zero);
              final rawPosition =
                  (audioPlayer.audioSource == null && _restoredPosition != null)
                  ? _restoredPosition!
                  : position;
              final safePosition =
                  (effectiveDuration > Duration.zero &&
                      rawPosition > effectiveDuration)
                  ? effectiveDuration
                  : (rawPosition < Duration.zero ? Duration.zero : rawPosition);
              final rawBuffered =
                  (audioPlayer.audioSource == null && _restoredPosition != null)
                  ? _restoredPosition!
                  : bufferedPosition;
              final safeBuffered =
                  (effectiveDuration > Duration.zero &&
                      rawBuffered > effectiveDuration)
                  ? effectiveDuration
                  : (rawBuffered < Duration.zero ? Duration.zero : rawBuffered);
              _checkNearEndCompletion(rawPosition, effectiveDuration);

              return PositionData(
                safePosition,
                safeBuffered,
                effectiveDuration,
              );
            },
          )
          .distinct((prev, curr) {
            final threshold = _dynamicPositionThreshold;
            return (prev.position - curr.position).abs() < threshold &&
                prev.duration == curr.duration &&
                (prev.bufferedPosition - curr.bufferedPosition).abs() <
                    threshold;
          })
          .asBroadcastStream();

  Stream<PositionData> get positionDataStream => _positionDataStream;

  late final Stream<PlaybackState> _playbackStateStream = playbackState
      .distinct((prev, curr) {
        final thresholdMs = _dynamicPositionThreshold.inMilliseconds;
        final prevPositionBucket =
            prev.updatePosition.inMilliseconds ~/ thresholdMs;
        final currPositionBucket =
            curr.updatePosition.inMilliseconds ~/ thresholdMs;
        return prev.playing == curr.playing &&
            prev.processingState == curr.processingState &&
            prev.queueIndex == curr.queueIndex &&
            prev.speed == curr.speed &&
            prevPositionBucket == currPositionBucket;
      })
      .asBroadcastStream();

  Stream<PlaybackState> get playbackStateStream => _playbackStateStream;

  List<MediaControl> _controls(bool playing) {
    final hasMultipleTracks = _queueList.length > 1;

    return [
      if (hasMultipleTracks)
        MediaControl.skipToPrevious
      else
        MediaControl.rewind,
      if (playing) MediaControl.pause else MediaControl.play,
      if (hasMultipleTracks)
        MediaControl.skipToNext
      else
        MediaControl.fastForward,
    ];
  }

  final _processingStateMap = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  void _logStreamError(String message, Object error, StackTrace stackTrace) {
    logger.log(message, error: error, stackTrace: stackTrace);
  }

  void _setupEventSubscriptions() {
    audioPlayer.playbackEventStream
        .throttleTime(const Duration(milliseconds: 100))
        .listen(
          (event) {
            _updatePlaybackState();
          },
          onError: (error, stackTrace) {
            _logStreamError('Playback event stream error', error, stackTrace);
          },
        );

    audioPlayer.positionStream.listen((pos) {
      if (audioPlayer.playing) {
        _saveLastPositionThrottled(pos.inMilliseconds);
        final dur = audioPlayer.duration;
        if (dur != null && dur.inMilliseconds > 15000) {
          final progress = pos.inMilliseconds / dur.inMilliseconds;
          if (progress >= 0.85 && !_hasPreloadedCurrentTrackEnd) {
            _hasPreloadedCurrentTrackEnd = true;
            _preloadUpcomingSongs();
            if (playNextSongAutomatically.value) {
              unawaited(_backgroundAddSongsToQueue());
            }
          }
        }
      }
    });

    audioPlayer.processingStateStream.distinct().listen(
      _handleProcessingStateChange,
      onError: (error, stackTrace) {
        _logStreamError('Processing state stream error', error, stackTrace);
      },
    );

    audioPlayer.durationStream.listen(
      (duration) {
        if (_currentQueueIndex < _queueList.length && duration != null) {
          _updateCurrentMediaItemWithDuration(duration);
        }
      },
      onError: (error, stackTrace) {
        _logStreamError('Duration stream error', error, stackTrace);
      },
    );

    audioPlayer.playerStateStream
        .distinct()
        .throttleTime(const Duration(milliseconds: 100))
        .listen(
          (state) {
            listeningStatsService.handlePlayerStateForListeningStats(
              state,
              currentSong: currentSong,
            );
            if (state.processingState == ProcessingState.idle &&
                !state.playing &&
                _lastError != null) {
              Future.microtask(_handlePlaybackError);
            }
            _debouncedStateUpdate();
          },
          onError: (error, stackTrace) {
            _logStreamError('Player state stream error', error, stackTrace);
          },
        );

    Rx.combineLatest2(
          audioPlayer.currentIndexStream.distinct(),
          audioPlayer.sequenceStateStream.distinct(),
          (index, sequence) => {'index': index, 'sequence': sequence},
        )
        .throttleTime(const Duration(milliseconds: 100))
        .listen(
          (_) => _debouncedStateUpdate(),
          onError: (error, stackTrace) {
            _logStreamError('Current index stream error', error, stackTrace);
          },
        );

    playNextSongAutomatically.addListener(() {
      if (playNextSongAutomatically.value) {
        unawaited(_backgroundAddSongsToQueue());
      }
    });
  }

  void _debouncedStateUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceInterval, () {
      if (!_isUpdatingState) {
        _updatePlaybackState();
      }
    });
  }

  void _hydrateQueueEntryIds() {
    _queueEntryIds
      ..ensureIds(_queueList)
      ..ensureIds(_originalQueueList);
  }

  MediaItem _getMediaItemForQueue(Map song) {
    final ytid = _songYtid(song);
    return mapToMediaItem(
      song,
      onSquareArtworkReady: (squareUri) {
        final current = mediaItem.valueOrNull;
        if (current != null &&
            (current.extras?['ytid'] == ytid ||
                current.id == _songYtid(song)) &&
            current.artUri != squareUri) {
          mediaItem.add(current.copyWith(artUri: squareUri));
        }
      },
    ).copyWith(id: _queueEntryIds.ensureId(song));
  }

  List<MediaItem> _buildQueueMediaItems() =>
      _queueList.map(_getMediaItemForQueue).toList(growable: false);

  bool _shouldUpdateDuration(Duration? currentDuration, Duration nextDuration) {
    if (currentDuration == null || currentDuration <= Duration.zero) {
      return nextDuration > Duration.zero;
    }
    // If the song already has a known metadata duration, protect it from
    // player stream estimation bugs (e.g. AVPlayer on iOS doubling/distorting AAC duration).
    final diff = (currentDuration - nextDuration).abs();
    if (diff > const Duration(seconds: 3)) {
      return false;
    }
    return !durationEquals(currentDuration, nextDuration);
  }

  bool _isCurrentMediaItemMatchingSong(
    MediaItem? currentItem,
    MediaItem currentQueueMediaItem,
    String? currentSongYtid,
  ) {
    if (currentItem == null) return false;

    if (currentItem.id == currentQueueMediaItem.id) {
      return true;
    }

    return currentSongYtid != null &&
        currentSongYtid.isNotEmpty &&
        currentItem.extras?['ytid']?.toString() == currentSongYtid;
  }

  void _updateCurrentMediaItemWithDuration(Duration duration) {
    try {
      final queueIndex = _currentQueueIndex;
      if (queueIndex < 0 || queueIndex >= _queueList.length) return;

      final currentSong = _queueList[queueIndex];
      final currentMediaItem = _getMediaItemForQueue(currentSong);
      final currentSongYtid = _songYtid(currentSong);
      final currentItem = mediaItem.valueOrNull;
      final isMatchingCurrentItem = _isCurrentMediaItemMatchingSong(
        currentItem,
        currentMediaItem,
        currentSongYtid,
      );

      final activeItem = isMatchingCurrentItem ? currentItem : currentMediaItem;
      final durationWasMissing =
          currentSong['duration'] == null || currentSong['duration'] <= 0;
      final knownDuration =
          activeItem?.duration ??
          (currentSong['duration'] != null && currentSong['duration'] > 0
              ? Duration(seconds: currentSong['duration'])
              : null);
      final shouldUpdate = _shouldUpdateDuration(knownDuration, duration);
      final effectiveDuration = shouldUpdate
          ? duration
          : (knownDuration ?? duration);

      if (shouldUpdate) {
        if (currentItem != null && isMatchingCurrentItem) {
          mediaItem.add(currentItem.copyWith(duration: duration));
        } else {
          mediaItem.add(currentMediaItem.copyWith(duration: duration));
        }
      }

      // Persist duration into queue item if it was missing
      if (durationWasMissing) {
        _playerInferredDurationSongId = _songYtid(currentSong);
        currentSong['duration'] = effectiveDuration.inSeconds;
      }

      listeningStatsService.updateListeningSessionDuration(
        currentSongYtid,
        effectiveDuration,
      );

      final existingQueue = queue.valueOrNull;
      if (existingQueue != null && queueIndex < existingQueue.length) {
        final queueItem = existingQueue[queueIndex];
        if (_shouldUpdateDuration(queueItem.duration, duration)) {
          final updatedQueue = List<MediaItem>.from(existingQueue);
          updatedQueue[queueIndex] = queueItem.copyWith(duration: duration);
          queue.add(updatedQueue);
        }
        return;
      }

      final rebuiltQueue = _buildQueueMediaItems();
      if (queueIndex < rebuiltQueue.length) {
        final queueItem = rebuiltQueue[queueIndex];
        if (_shouldUpdateDuration(queueItem.duration, duration)) {
          rebuiltQueue[queueIndex] = queueItem.copyWith(duration: duration);
        }
      }
      queue.add(rebuiltQueue);
    } catch (e, stackTrace) {
      logger.log(
        'Error updating media item with duration',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void resetListeningStatsSession({
    bool countCurrentTick = false,
    bool flushStats = true,
  }) {
    listeningStatsService.finishListeningSession(
      countCurrentTick: countCurrentTick,
      flushStats: flushStats,
    );
  }

  void startListeningStatsSessionIfNeeded() {
    listeningStatsService.startListeningSessionIfNeeded(
      currentSong: currentSong,
      isPlaying: audioPlayer.playing,
    );
  }

  Future<void> _initialize() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _setupAudioInterruptionHandling(session);

      // Always set loop mode to off - we handle all repeating through _handleSongCompletion
      // This ensures ProcessingState.completed is always fired for song transitions
      await audioPlayer.setLoopMode(LoopMode.off);

      // Apply stored shuffle mode to audio player
      await audioPlayer.setShuffleModeEnabled(shuffleNotifier.value);

      // Initialize equalizer once at startup on Android
      if (Platform.isAndroid) {
        unawaited(_ensureEqualizerConfigured());
      }

      // Restore last played playback session so Mini Player and queue are ready
      await _restoreLastPlaybackSession();
    } catch (e, stackTrace) {
      logger.log(
        'Error initializing audio session',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _setupAudioInterruptionHandling(AudioSession session) {
    session.becomingNoisyEventStream.listen((_) async {
      logger.log('[PLAYER] becoming_noisy: pausing audio with smooth fade');
      if (audioPlayer.playing) {
        try {
          await audioPlayer.setVolume(0.5);
          await Future.delayed(const Duration(milliseconds: 100));
          await audioPlayer.setVolume(0.1);
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (_) {}
      }
      await pause();
      try {
        await audioPlayer.setVolume(1);
      } catch (_) {}
    });

    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        _interruptedPlayingState = audioPlayer.playing;
        logger.log(
          '[PLAYER] audio_interruption begin: type=${event.type}, wasPlaying=$_interruptedPlayingState',
        );
        switch (event.type) {
          case AudioInterruptionType.duck:
            if (audioPlayer.playing) {
              await audioPlayer.setVolume(0.2);
            }
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (audioPlayer.playing) {
              await pause();
            }
            break;
        }
      } else {
        logger.log(
          '[PLAYER] audio_interruption end: type=${event.type}, resume=$_interruptedPlayingState',
        );
        switch (event.type) {
          case AudioInterruptionType.duck:
            await audioPlayer.setVolume(1);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_interruptedPlayingState) {
              _interruptedPlayingState = false;
              await play();
            }
            break;
        }
      }
    });
  }

  void _saveLastPositionThrottled(int positionMs) {
    if ((positionMs - _lastSavedPositionMs).abs() < 3000) return;
    _lastSavedPositionMs = positionMs;
    try {
      unawaited(Hive.box('userNoBackup').put('lastPositionMs', positionMs));
    } catch (_) {}
  }

  void saveCurrentPlaybackState() {
    try {
      final box = Hive.box('userNoBackup');
      final current = currentSong;
      if (current != null && _songYtid(current) != null) {
        unawaited(box.put('lastPlayedSong', cloneMap(current)));
      }
      if (_queueList.isNotEmpty) {
        unawaited(box.put('lastPlaybackQueue', cloneMaps(_queueList)));
      }
      if (_originalQueueList.isNotEmpty) {
        unawaited(box.put('lastOriginalQueue', cloneMaps(_originalQueueList)));
      }
      unawaited(box.put('lastQueueIndex', _currentQueueIndex));
      final pos = audioPlayer.audioSource != null
          ? audioPlayer.position.inMilliseconds
          : (_restoredPosition?.inMilliseconds ?? 0);
      unawaited(box.put('lastPositionMs', pos));
    } catch (e, stackTrace) {
      logger.log(
        'Error saving playback state',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _restoreLastPlaybackSession() async {
    try {
      final box = Hive.box('userNoBackup');
      final savedSong = box.get('lastPlayedSong') as Map?;
      final rawQueue = box.get('lastPlaybackQueue') as List?;
      final rawOriginalQueue = box.get('lastOriginalQueue') as List?;
      final savedQueueIndex = box.get('lastQueueIndex') as int? ?? 0;
      final savedPositionMs = box.get('lastPositionMs') as int? ?? 0;

      final songToRestore =
          savedSong ??
          (userRecentlyPlayed.value.isNotEmpty
              ? (userRecentlyPlayed.value.first is Map
                    ? userRecentlyPlayed.value.first as Map
                    : null)
              : null);
      if (songToRestore == null) return;

      final normalised = _normaliseResumableSong(songToRestore);
      if (normalised == null) return;

      _queueList.clear();
      _originalQueueList.clear();

      if (rawQueue != null && rawQueue.isNotEmpty) {
        for (final item in rawQueue) {
          if (item is Map) {
            final n = _normaliseResumableSong(item);
            if (n != null) {
              _queueList.add(_queueEntryIds.createSong(n));
            }
          }
        }
      }
      if (_queueList.isEmpty) {
        _queueList.add(_queueEntryIds.createSong(normalised));
      }

      if (rawOriginalQueue != null && rawOriginalQueue.isNotEmpty) {
        for (final item in rawOriginalQueue) {
          if (item is Map) {
            final n = _normaliseResumableSong(item);
            if (n != null) {
              _originalQueueList.add(n);
            }
          }
        }
      }
      if (_originalQueueList.isEmpty) {
        _originalQueueList.addAll(cloneMaps(_queueList));
      }

      _currentQueueIndex = savedQueueIndex.clamp(0, _queueList.length - 1);
      _hydrateQueueEntryIds();

      final activeSong = _queueList[_currentQueueIndex];
      final restoredMediaItem = _getMediaItemForQueue(activeSong);
      mediaItem.add(restoredMediaItem);
      _updateQueueMediaItems();

      final trackDuration = restoredMediaItem.duration ?? Duration.zero;
      final savedPosition = Duration(milliseconds: savedPositionMs);
      // If position was at the very end (> 95% of duration or within 3 seconds), reset to start
      final isNearEnd =
          trackDuration > const Duration(seconds: 10) &&
          (savedPosition >= trackDuration - const Duration(seconds: 3) ||
              savedPosition.inMilliseconds >
                  (trackDuration.inMilliseconds * 0.95));
      final effectivePosition = isNearEnd ? Duration.zero : savedPosition;
      _restoredPosition = effectivePosition;

      playbackState.add(
        PlaybackState(
          controls: _controls(false),
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: AudioProcessingState.ready,
          updatePosition: effectivePosition,
          bufferedPosition: effectivePosition,
          queueIndex: _currentQueueIndex,
        ),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error restoring last playback session',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _ensureEqualizerConfigured({bool force = false}) async {
    if (_equalizerInitialized) return true;

    final now = DateTime.now();
    if (!force && now.isBefore(_equalizerRetryNotBefore)) {
      return false;
    }

    if (!force && audioPlayer.audioSource == null) {
      return false;
    }

    final inFlight = _equalizerInitFuture;
    if (inFlight != null) {
      return inFlight;
    }

    _equalizerInitFuture = _configureEqualizer();
    try {
      return await _equalizerInitFuture!;
    } finally {
      _equalizerInitFuture = null;
    }
  }

  Future<bool> _configureEqualizer() async {
    if (!Platform.isAndroid) return false;
    try {
      final params = await _androidEqualizer.parameters.timeout(
        const Duration(seconds: 3),
      );

      final savedGains = equalizerBandGains.value;
      if (savedGains.isNotEmpty) {
        for (var i = 0; i < params.bands.length && i < savedGains.length; i++) {
          final clamped = savedGains[i].clamp(
            params.minDecibels,
            params.maxDecibels,
          );
          await params.bands[i].setGain(clamped);
        }
      }

      await _androidEqualizer.setEnabled(equalizerEnabled.value);
      _equalizerInitialized = true;
      _equalizerRetryNotBefore = DateTime.fromMillisecondsSinceEpoch(0);
      return true;
    } catch (e, stackTrace) {
      _equalizerRetryNotBefore = DateTime.now().add(
        const Duration(seconds: 10),
      );
      logger.log(
        'Equalizer initialization deferred',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<AndroidEqualizerParameters?> getEqualizerParameters() async {
    if (!Platform.isAndroid) return null;
    final initialized = await _ensureEqualizerConfigured();
    if (!initialized) return null;
    try {
      return await _androidEqualizer.parameters.timeout(
        const Duration(seconds: 2),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Failed to get equalizer parameters',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    final initialized = await _ensureEqualizerConfigured(force: true);
    if (!initialized) return;
    try {
      await _androidEqualizer.setEnabled(enabled);
      equalizerEnabled.value = enabled;
      unawaited(addOrUpdateData<bool>('settings', 'equalizerEnabled', enabled));
    } catch (e, stackTrace) {
      logger.log(
        'Failed to set equalizer enabled state',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> setEqualizerBandGain(int index, double gain) async {
    if (!Platform.isAndroid) return;
    final initialized = await _ensureEqualizerConfigured(force: true);
    if (!initialized) return;

    try {
      final params = await _androidEqualizer.parameters;
      if (index < 0 || index >= params.bands.length) {
        return;
      }

      final clamped = gain.clamp(params.minDecibels, params.maxDecibels);
      await params.bands[index].setGain(clamped);

      final gains = params.bands.map((band) => band.gain).toList();
      equalizerBandGains.value = gains;
      unawaited(
        addOrUpdateData<List<double>>('settings', 'equalizerBandGains', gains),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Failed to set equalizer band gain',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> resetEqualizerBands() async {
    if (!Platform.isAndroid) return;
    final initialized = await _ensureEqualizerConfigured(force: true);
    if (!initialized) return;

    try {
      final params = await _androidEqualizer.parameters;
      for (final band in params.bands) {
        await band.setGain(0);
      }
      final gains = List<double>.filled(params.bands.length, 0);
      equalizerBandGains.value = gains;
      unawaited(
        addOrUpdateData<List<double>>('settings', 'equalizerBandGains', gains),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Failed to reset equalizer bands',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  bool _hasSignificantPositionChange(
    Duration currentPosition,
    Duration lastUpdatePosition,
    DateTime lastUpdateTime,
    DateTime now,
    double speed,
  ) {
    final expectedPosition =
        lastUpdatePosition + (now.difference(lastUpdateTime)) * speed;
    return (currentPosition - expectedPosition).abs() >
        const Duration(milliseconds: 500);
  }

  void _updatePlaybackState() {
    if (_isUpdatingState) {
      _pendingPlaybackStateUpdate = true;
      return;
    }

    _isUpdatingState = true;

    try {
      final now = DateTime.now();
      final currentPosition =
          (audioPlayer.audioSource == null && _restoredPosition != null)
          ? _restoredPosition!
          : audioPlayer.position;
      final isPlaying = audioPlayer.playing;
      final currentState = playbackState.valueOrNull;
      final newProcessingState =
          (audioPlayer.audioSource == null && _restoredPosition != null)
          ? AudioProcessingState.ready
          : (_processingStateMap[audioPlayer.processingState] ??
                AudioProcessingState.idle);
      final bufferedPosition =
          (audioPlayer.audioSource == null && _restoredPosition != null)
          ? _restoredPosition!
          : audioPlayer.bufferedPosition;

      final shouldEmitProgressTick =
          currentState != null &&
          isPlaying &&
          now.difference(currentState.updateTime) >= _playbackStateHeartbeat;
      final hasBufferedPositionChange =
          currentState == null ||
          (bufferedPosition - currentState.bufferedPosition).abs() >=
              const Duration(seconds: 1);

      final shouldUpdate =
          currentState == null ||
          currentState.playing != isPlaying ||
          currentState.processingState != newProcessingState ||
          currentState.queueIndex != _currentQueueIndex ||
          currentState.speed != audioPlayer.speed ||
          shouldEmitProgressTick ||
          hasBufferedPositionChange ||
          (_hasSignificantPositionChange(
            currentPosition,
            currentState.updatePosition,
            currentState.updateTime,
            now,
            currentState.speed,
          ));

      if (shouldUpdate) {
        final currentItem = mediaItem.valueOrNull;
        final itemDuration = currentItem?.duration;
        final safePosition =
            (itemDuration != null &&
                itemDuration > Duration.zero &&
                currentPosition > itemDuration)
            ? itemDuration
            : (currentPosition < Duration.zero
                  ? Duration.zero
                  : currentPosition);
        final safeBuffered =
            (itemDuration != null &&
                itemDuration > Duration.zero &&
                bufferedPosition > itemDuration)
            ? itemDuration
            : (bufferedPosition < Duration.zero
                  ? Duration.zero
                  : bufferedPosition);

        playbackState.add(
          PlaybackState(
            controls: _controls(isPlaying),
            systemActions: const {
              MediaAction.seek,
              MediaAction.seekForward,
              MediaAction.seekBackward,
              MediaAction.setShuffleMode,
              MediaAction.setRepeatMode,
            },
            androidCompactActionIndices: const [0, 1, 2],
            processingState: newProcessingState,
            playing: isPlaying,
            updatePosition: safePosition,
            bufferedPosition: safeBuffered,
            speed: audioPlayer.speed,
            queueIndex:
                _currentQueueIndex >= 0 &&
                    _currentQueueIndex < _queueList.length
                ? _currentQueueIndex
                : null,
            updateTime: now,
            repeatMode: repeatNotifier.value,
            shuffleMode: shuffleNotifier.value
                ? AudioServiceShuffleMode.all
                : AudioServiceShuffleMode.none,
          ),
        );
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error updating playback state',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isUpdatingState = false;
      if (_pendingPlaybackStateUpdate) {
        _pendingPlaybackStateUpdate = false;
        _updatePlaybackState();
      }
    }
  }

  void _handleProcessingStateChange(ProcessingState state) {
    try {
      if (state == ProcessingState.completed) {
        if (sleepTimerEndOfSong) {
          sleepTimerExpired = true;
          sleepTimerEndOfSong = false;
          _sleepTimerRemainingSongs = null;
          stop();
          sleepTimerNotifier.value = null;
          return;
        }

        if (_sleepTimerRemainingSongs != null &&
            _sleepTimerRemainingSongs! > 0) {
          _sleepTimerRemainingSongs = _sleepTimerRemainingSongs! - 1;
          if (_sleepTimerRemainingSongs! <= 0) {
            sleepTimerExpired = true;
            _sleepTimerRemainingSongs = null;
            stop();
            sleepTimerNotifier.value = null;
            return;
          } else {
            sleepTimerNotifier.value = Duration(
              milliseconds: -_sleepTimerRemainingSongs!,
            );
          }
        }

        listeningStatsService.finishListeningSession(
          countCurrentTick: true,
          wasPlaying: true,
        );

        if (!sleepTimerExpired && !_completionEventPending) {
          _completionEventPending = true;

          Future.microtask(() async {
            try {
              if (!sleepTimerExpired && _completionEventPending) {
                await _handleSongCompletion();
              }
            } finally {
              // Only reset if still marked as pending (another event didn't override)
              if (_completionEventPending) {
                _completionEventPending = false;
                _completionHandlerLoadStarted = false;
              }
              // else {
              //   logger.log(
              //     '[COMPLETION] Flag already false in finally block (was overridden)',
              //     null,
              //     null,
              //   );
              // }
            }
          });
        }
      } else if (state == ProcessingState.ready) {
        _completionEventPending = false;
        _completionHandlerLoadStarted = false;

        // Clear the expired flag so future song completions are not
        // blocked after a sleep timer fired in a previous session.
        // Do NOT touch sleepTimerEndOfSong here — 'ready' fires not
        // only for new songs but also on buffering recovery within the
        // same song, which would cancel an active "end of song" timer.
        sleepTimerExpired = false;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error handling processing state change',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  bool _isSongAvailableOffline(Map song) {
    final audioPath = song['audioPath']?.toString();
    if (audioPath != null &&
        audioPath.isNotEmpty &&
        File(audioPath).existsSync()) {
      return true;
    }
    final ytid = canonicalSongId(song);
    if (ytid != null && ytid.isNotEmpty) {
      final offline = getOfflineSongByYtid(ytid);
      if (offline.isNotEmpty) {
        final path = offline['audioPath']?.toString();
        if (path != null && path.isNotEmpty && File(path).existsSync()) {
          return true;
        }
      }
    }
    return false;
  }

  bool _canRetryPlayback() =>
      hasNext ||
      (repeatNotifier.value == AudioServiceRepeatMode.all &&
          _queueList.isNotEmpty) ||
      playNextSongAutomatically.value;

  void _handlePlaybackError() {
    _consecutiveErrors++;
    logger.log(
      '[PLAYER] stream_error: $_lastError (consecutive: $_consecutiveErrors)',
      error: _lastError,
    );

    if (isNetworkError(_lastError)) {
      // The device appears to be offline or network connection was lost.
      // Do NOT rapidly cascade-skip through online tracks in the queue.
      // Only skip if the next track is downloaded/offline-ready.
      final nextIdx = _currentQueueIndex + 1;
      final hasOfflineNext =
          nextIdx < _queueList.length &&
          _isSongAvailableOffline(_queueList[nextIdx]);
      if (hasOfflineNext) {
        logger.log(
          '[PLAYER] Network offline, but next track is available offline. Skipping to next.',
        );
        Future.delayed(_errorRetryDelay, skipToNext);
      } else {
        logger.log(
          '[PLAYER] Network offline and next track requires internet. Pausing playback and waiting for reconnect.',
        );
        _consecutiveErrors = 0;
        _pausedDueToNetwork = true;
        pause();
        _startNetworkRecoveryCheck();
      }
      return;
    }

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      logger.log(
        '[PLAYER] Max consecutive errors ($_maxConsecutiveErrors) reached. Stopping playback.',
      );
      stop();
      return;
    }

    if (_canRetryPlayback()) {
      logger.log(
        '[PLAYER] Skipping failed track to next available queue item in ${_errorRetryDelay.inSeconds}s',
      );
      Future.delayed(_errorRetryDelay, skipToNext);
    } else {
      _lastError = null;
    }
  }

  bool _pausedDueToNetwork = false;
  Timer? _networkRecoveryTimer;

  void _startNetworkRecoveryCheck() {
    _networkRecoveryTimer?.cancel();
    _networkRecoveryTimer = Timer.periodic(const Duration(seconds: 4), (
      timer,
    ) async {
      if (!_pausedDueToNetwork) {
        timer.cancel();
        return;
      }
      try {
        final result = await InternetAddress.lookup(
          'google.com',
        ).timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          logger.log('[PLAYER] Network recovered! Auto-resuming playback.');
          timer.cancel();
          _networkRecoveryTimer = null;
          _pausedDueToNetwork = false;
          _lastError = null;
          if (audioPlayer.audioSource == null &&
              _currentQueueIndex >= 0 &&
              _currentQueueIndex < _queueList.length) {
            final resumePos = audioPlayer.position;
            await _playFromQueue(
              _currentQueueIndex,
              initialSeek: resumePos > Duration.zero ? resumePos : null,
            );
          } else {
            await play();
          }
        }
      } catch (_) {
        // Still offline, will retry next tick
      }
    });
  }

  void _cancelNetworkRecovery() {
    _pausedDueToNetwork = false;
    _networkRecoveryTimer?.cancel();
    _networkRecoveryTimer = null;
  }

  Future<void> _handleSongCompletion() async {
    try {
      if (_currentQueueIndex >= 0 && _currentQueueIndex < _queueList.length) {
        final finishedSong = _queueList[_currentQueueIndex];
        _lastCompletedSongId = canonicalSongId(finishedSong);
        logger.log(
          '[PLAYER] track_complete: ytid=${finishedSong['ytid'] ?? finishedSong['id']}',
        );
        _addToHistory(finishedSong);
      }

      // Determine what to play next based on queue position and repeat mode
      if (repeatNotifier.value == AudioServiceRepeatMode.one) {
        // Repeat single song - play current song again
        await playAgain();
      } else {
        // For all other cases (next song, repeat all, auto-play), skipToNext handles it
        await skipToNext();
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error handling song completion',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _checkNearEndCompletion(Duration position, Duration effectiveDuration) {
    if (effectiveDuration <= const Duration(seconds: 2)) return;
    if (_completionEventPending || _currentLoadingIndex != -1) return;
    final currentSongId = currentSong == null
        ? null
        : canonicalSongId(currentSong!);
    if (currentSongId != null && currentSongId == _lastCompletedSongId) {
      return;
    }

    final diffMs = (effectiveDuration - position).inMilliseconds;
    final isNearEnd = diffMs <= 350 && diffMs >= -2000;

    // Protection against 2x duration inflation bug on iOS:
    // If duration was doubled by AVPlayer/codec, physical audio ends at ~50% of effectiveDuration!
    final halfDurationMs = effectiveDuration.inMilliseconds ~/ 2;
    final diffHalfMs = (halfDurationMs - position.inMilliseconds).abs();
    final isNearHalfEnd =
        diffHalfMs <= 500 &&
        (!audioPlayer.playing ||
            audioPlayer.processingState == ProcessingState.completed);

    if (isNearEnd || isNearHalfEnd) {
      if (isNearHalfEnd) {
        _correctInflatedDuration(position, effectiveDuration);
      }
      logger.log(
        'End of song detected (isNearEnd: $isNearEnd, isNearHalfEnd: $isNearHalfEnd, pos: ${position.inSeconds}s, dur: ${effectiveDuration.inSeconds}s)',
      );
      _completionEventPending = true;
      Future.microtask(() async {
        try {
          if (!sleepTimerExpired) {
            await _handleSongCompletion();
          }
        } finally {
          if (_completionEventPending) {
            _completionEventPending = false;
            _completionHandlerLoadStarted = false;
          }
        }
      });
    }
  }

  void _correctInflatedDuration(
    Duration physicalEnd,
    Duration reportedDuration,
  ) {
    if (physicalEnd <= const Duration(seconds: 2) ||
        reportedDuration <= physicalEnd) {
      return;
    }

    final queueIndex = _currentQueueIndex;
    if (queueIndex < 0 || queueIndex >= _queueList.length) return;

    final song = _queueList[queueIndex];
    final metadataDuration = song['duration'];
    final isPlayerInferred = _playerInferredDurationSongId == _songYtid(song);
    if (metadataDuration is num && metadataDuration > 0 && !isPlayerInferred) {
      return;
    }

    final currentItem = mediaItem.valueOrNull;
    if (currentItem != null &&
        _isCurrentMediaItemMatchingSong(
          currentItem,
          _getMediaItemForQueue(song),
          _songYtid(song),
        )) {
      mediaItem.add(currentItem.copyWith(duration: physicalEnd));
    }

    song['duration'] = physicalEnd.inSeconds;
    _playerInferredDurationSongId = null;
    final existingQueue = queue.valueOrNull;
    if (existingQueue != null && queueIndex < existingQueue.length) {
      final updatedQueue = List<MediaItem>.from(existingQueue);
      updatedQueue[queueIndex] = updatedQueue[queueIndex].copyWith(
        duration: physicalEnd,
      );
      queue.add(updatedQueue);
    }

    logger.log(
      '[PLAYER] corrected inflated duration: '
      'reported=${reportedDuration.inSeconds}s actual=${physicalEnd.inSeconds}s',
    );
  }

  /// Public/internal trigger for autoplay background prefetch.
  Future<void> _backgroundAddSongsToQueue({bool forcePlayIfEnd = false}) =>
      _checkAndTriggerAutoplayPrefetch(forcePlayIfEnd: forcePlayIfEnd);

  /// Checks queue remaining thresholds, enforces repeat precedence, and
  /// seamlessly prefetches and appends additional radio tracks to the queue.
  Future<void> _checkAndTriggerAutoplayPrefetch({
    bool forcePlayIfEnd = false,
  }) async {
    if (offlineMode.value) return;

    // Strict repeat precedence:
    // Repeat One: current track repeats, no radio expansion
    // Repeat All: queue loops, no radio expansion
    if (repeatNotifier.value == AudioServiceRepeatMode.one ||
        repeatNotifier.value == AudioServiceRepeatMode.all) {
      return;
    }

    // Autoplay must be enabled unless forcing play at queue end
    if (!playNextSongAutomatically.value && !forcePlayIfEnd) {
      return;
    }

    // Check remaining tracks in queue: remaining = (total - 1) - current
    final queueLength = _queueList.length;
    final remaining = (queueLength - 1) - _currentQueueIndex;

    // Only prefetch when remaining tracks <= threshold or when queue is exhausted
    if (remaining > _autoplayPrefetchThreshold && !forcePlayIfEnd) {
      return;
    }

    // In-flight guard: wait on active fetch if forcePlay is required
    if (_isFetchingAutoplay) {
      if (forcePlayIfEnd) {
        _autoplayForcePlayPending = true;
        _emitOptimisticLoadingState(queueIndex: _currentQueueIndex);
        if (_activeAutoplayCompleter != null) {
          try {
            await _activeAutoplayCompleter!.future.timeout(
              const Duration(seconds: 10),
            );
          } catch (_) {}
        }
      }
      return;
    }

    _isFetchingAutoplay = true;
    _activeAutoplayCompleter = Completer<void>();
    final shouldForcePlay = forcePlayIfEnd || _autoplayForcePlayPending;
    _autoplayForcePlayPending = false;

    if (shouldForcePlay) {
      _emitOptimisticLoadingState(queueIndex: _currentQueueIndex);
    }

    logger.log(
      '[AUTOPLAY] queueRemaining=$remaining fetching=true threshold=$_autoplayPrefetchThreshold forcePlay=$shouldForcePlay',
    );

    try {
      // If not forcing play at end of song, only add songs if we're still playing or loading
      if (!shouldForcePlay &&
          !audioPlayer.playing &&
          audioPlayer.processingState != ProcessingState.loading &&
          audioPlayer.processingState != ProcessingState.buffering) {
        return;
      }

      final baseSong = _getCurrentSongForRecommendations();
      final currentYtid = baseSong != null
          ? (canonicalSongId(baseSong) ?? '')
          : '';

      final currentSession = radioService.currentSession;
      final isCurrentSongAutoPicked =
          currentSong != null && (currentSong!['isAutoPicked'] == true);

      // Re-seed radio if no session or if the user changed the track manually to a different seed
      if (currentYtid.isNotEmpty &&
          (currentSession == null ||
              (!isCurrentSongAutoPicked &&
                  currentSession.seedId != currentYtid))) {
        radioService.setSession(
          RadioSession(
            seedId: currentYtid,
            seedTitle: baseSong?['title']?.toString() ?? '',
            type: RadioType.song,
            playlistId: 'RDAMVM$currentYtid',
            seenTrackIds: _queueList
                .map(canonicalSongId)
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toSet(),
          ),
        );
      }

      final existingIds = _queueList
          .map(canonicalSongId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final songsToAdd = await radioService.getMoreRadioSongs(
        existingQueueIds: existingIds,
      );

      // Secondary fallback if RadioService returned empty
      if (songsToAdd.isEmpty && currentYtid.isNotEmpty) {
        try {
          await getSimilarSong(
            currentYtid,
          ).timeout(const Duration(seconds: 8), onTimeout: () {});
          final songToAdd = nextRecommendedSong;
          if (songToAdd != null) {
            nextRecommendedSong = null;
            final sid = canonicalSongId(songToAdd) ?? '';
            if (sid.isNotEmpty && !existingIds.contains(sid)) {
              songsToAdd.add(songToAdd);
            }
          }
        } catch (_) {}
      }

      final playNextNow = shouldForcePlay || _autoplayForcePlayPending;
      _autoplayForcePlayPending = false;

      if (songsToAdd.isNotEmpty) {
        final startIndex = _queueList.length;
        for (var i = 0; i < songsToAdd.length; i++) {
          final queueSong = _queueEntryIds.createSong(songsToAdd[i]);
          queueSong['isAutoPicked'] = true;
          _queueList.add(queueSong);
        }

        if (_currentQueueIndex < 0) {
          _currentQueueIndex = 0;
        }

        _updateQueueMediaItems();
        _cleanupOldPreloadedSongs();
        saveCurrentPlaybackState();

        logger.log(
          '[AUTOPLAY] added=${songsToAdd.length} queueSize=${_queueList.length}',
        );

        if (playNextNow && !_userRequestedPause) {
          await _playFromQueue(startIndex);
        }
      } else {
        logger.log('[AUTOPLAY] No additional radio songs could be resolved');
        if (playNextNow) {
          await stop();
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        '[RADIO_ERROR] Error in autoplay background prefetch',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isFetchingAutoplay = false;
      if (_activeAutoplayCompleter != null &&
          !_activeAutoplayCompleter!.isCompleted) {
        _activeAutoplayCompleter!.complete();
      }
      _activeAutoplayCompleter = null;
    }
  }

  Map? _getCurrentSongForRecommendations() {
    if (currentSong != null) {
      return currentSong;
    }

    final currentMediaItem = mediaItem.valueOrNull;

    if (currentMediaItem == null || currentMediaItem.id.isEmpty) {
      logger.log('No current media item available');
      return null;
    }

    return mediaItemToMap(currentMediaItem);
  }

  void _addToHistory(Map song) {
    try {
      _historyList.insert(0, cloneMap(song));

      if (_historyList.length > _maxHistorySize) {
        _historyList.removeRange(_maxHistorySize, _historyList.length);
      }
    } catch (e, stackTrace) {
      logger.log('Error adding to history', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> addToQueue(Map song, {bool playNext = false}) async {
    try {
      final songData = cloneMap(song);
      final rawId = canonicalSongId(songData);
      if (rawId == null) {
        logger.log('[PLAYER] Invalid song data for queue: missing id');
        return;
      }
      songData['id'] = rawId;
      songData['ytid'] = rawId;

      logger.log(
        '[PLAYER] queue_add: ytid=$rawId, title=${songData['title'] ?? ''}, playNext=$playNext',
      );

      int insertIndex;

      if (playNext) {
        insertIndex = _currentQueueIndex + 1;
        if (insertIndex < 0) insertIndex = 0;
        if (insertIndex > _queueList.length) {
          insertIndex = _queueList.length;
        }
      } else {
        insertIndex = _queueList.length;
      }

      final queueSong = _queueEntryIds.createSong(songData);
      queueSong['isManuallyAdded'] = true;
      _queueList.insert(insertIndex, queueSong);

      if (_currentQueueIndex < 0) {
        _currentQueueIndex = 0;
      }

      _updateQueueMediaItems();
      _cleanupOldPreloadedSongs();
      saveCurrentPlaybackState();

      if (!audioPlayer.playing && _queueList.length == 1) {
        await _playFromQueue(0);
      }
    } catch (e, stackTrace) {
      logger.log('Error adding to queue', error: e, stackTrace: stackTrace);
    }
  }

  void _cleanupOldPreloadedSongs() {
    Future.microtask(() async {
      try {
        final queueYtIds = _queueList
            .map((song) => song['ytid']?.toString())
            .where((ytid) => ytid != null)
            .toSet();

        final oldPreloadedSongs = _preloadedYtIds
            .where((ytid) => !queueYtIds.contains(ytid))
            .toList();

        for (final ytid in oldPreloadedSongs) {
          _preloadedYtIds.remove(ytid);
        }

        final stalePreloadingEntries = _preloadingYtIds
            .where((ytid) => !queueYtIds.contains(ytid))
            .toList();

        for (final ytid in stalePreloadingEntries) {
          _preloadingYtIds.remove(ytid);
        }

        if (oldPreloadedSongs.isNotEmpty || stalePreloadingEntries.isNotEmpty) {
          logger.log(
            'Cleaned up ${oldPreloadedSongs.length + stalePreloadingEntries.length} old preload entries',
          );
        }
      } catch (e, stackTrace) {
        logger.log(
          'Error cleaning up preloaded songs',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<void> addPlaylistToQueue(
    List<Map> songs, {
    bool replace = false,
    int? startIndex,
    bool shuffle = false,
  }) async {
    try {
      final manuallyAddedSongs = replace ? _getUnplayedManualSongs() : <Map>[];
      if (replace) {
        _queueList.clear();
        _originalQueueList.clear();
        _currentQueueIndex = 0;
        _currentLoadingIndex = -1;
        _currentLoadingTransitionId = -1;
        _resetPreloadingState();
        radioService.resetSession();
        shuffleNotifier.value = shuffle;
        unawaited(Hive.box('settings').put('shuffleEnabled', shuffle));
        await audioPlayer.setShuffleModeEnabled(shuffle);
      }

      int? targetQueueIndex;

      final playableSongs = songs
          .where((s) {
            return canonicalSongId(s) != null;
          })
          .map((s) {
            final id = canonicalSongId(s)!;
            final copy = Map<String, dynamic>.from(s);
            copy['id'] = id;
            copy['ytid'] = id;
            return copy;
          })
          .toList();

      if (replace && shuffle) {
        _originalQueueList.addAll(cloneMaps(playableSongs));
        final shuffledSongs = List<Map>.from(playableSongs)..shuffle();
        if (startIndex != null &&
            startIndex >= 0 &&
            startIndex < playableSongs.length) {
          final requestedSongYtid = playableSongs[startIndex]['ytid']
              ?.toString();
          final foundIdx = shuffledSongs.indexWhere(
            (s) => s['ytid']?.toString() == requestedSongYtid,
          );
          if (foundIdx > 0) {
            final picked = shuffledSongs.removeAt(foundIdx);
            shuffledSongs.insert(0, picked);
          }
        }
        for (final song in shuffledSongs) {
          _queueList.add(_queueEntryIds.createSong(song));
        }
        targetQueueIndex = 0;
      } else {
        for (var i = 0; i < songs.length; i++) {
          final rawSong = songs[i];
          final id = canonicalSongId(rawSong);
          if (id != null) {
            final song = Map<String, dynamic>.from(rawSong)
              ..['id'] = id
              ..['ytid'] = id;
            _queueList.add(_queueEntryIds.createSong(song));

            if (replace && startIndex == i) {
              targetQueueIndex = _queueList.length - 1;
            }
          }
        }
      }

      if (replace && manuallyAddedSongs.isNotEmpty) {
        // Always insert after the starting song index
        final insertIndex = (targetQueueIndex ?? 0) + 1;
        final safeInsertIndex = insertIndex > _queueList.length
            ? _queueList.length
            : insertIndex;
        _queueList.insertAll(safeInsertIndex, manuallyAddedSongs);
      }

      _hydrateQueueEntryIds();
      _updateQueueMediaItems();
      saveCurrentPlaybackState();

      if (targetQueueIndex != null) {
        await _playFromQueue(targetQueueIndex);
      } else if (startIndex != null &&
          startIndex < _queueList.length &&
          !replace) {
        await _playFromQueue(startIndex);
      } else if (replace && _queueList.isNotEmpty) {
        await _playFromQueue(0);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error adding playlist to queue',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> removeFromQueue(int index) async {
    try {
      if (index < 0 || index >= _queueList.length) return;

      final removedSong = _queueList[index];
      final removedQueueEntryId = _queueEntryIds.ensureId(removedSong);
      logger.log(
        '[PLAYER] queue_remove: index=$index, ytid=${removedSong['ytid'] ?? removedSong['id']}',
      );
      _queueList.removeAt(index);

      if (shuffleNotifier.value && _originalQueueList.isNotEmpty) {
        _originalQueueList.removeWhere(
          (s) => _queueEntryIds.ensureId(s) == removedQueueEntryId,
        );
      }

      if (index == _currentLoadingIndex) {
        _currentLoadingIndex = -1;
        _currentLoadingTransitionId = -1;
      } else if (index < _currentLoadingIndex) {
        _currentLoadingIndex--;
      }

      if (index < _currentQueueIndex) {
        _currentQueueIndex--;
      } else if (index == _currentQueueIndex) {
        if (_queueList.isEmpty) {
          await stop();
        } else {
          if (_currentQueueIndex >= _queueList.length) {
            _currentQueueIndex = _queueList.length - 1;
          }
          await _playFromQueue(_currentQueueIndex);
        }
      }

      _hydrateQueueEntryIds();
      _updateQueueMediaItems();
      saveCurrentPlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error removing from queue', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    try {
      _queueEntryIds.ensureIds(_queueList);

      if (oldIndex < 0 ||
          oldIndex >= _queueList.length ||
          newIndex < 0 ||
          newIndex > _queueList.length - 1) {
        return;
      }

      logger.log('[PLAYER] queue_reorder: old=$oldIndex, new=$newIndex');

      final song = _queueList.removeAt(oldIndex);
      _queueList.insert(newIndex, song);

      if (oldIndex == _currentQueueIndex) {
        _currentQueueIndex = newIndex;
      } else if (oldIndex < _currentQueueIndex &&
          newIndex >= _currentQueueIndex) {
        _currentQueueIndex--;
      } else if (oldIndex > _currentQueueIndex &&
          newIndex <= _currentQueueIndex) {
        _currentQueueIndex++;
      }

      // Also update _currentLoadingIndex if the currently-loading song is being reordered
      if (oldIndex == _currentLoadingIndex) {
        _currentLoadingIndex = newIndex;
      } else if (oldIndex < _currentLoadingIndex &&
          newIndex >= _currentLoadingIndex) {
        _currentLoadingIndex--;
      } else if (oldIndex > _currentLoadingIndex &&
          newIndex <= _currentLoadingIndex) {
        _currentLoadingIndex++;
      }

      _updateQueueMediaItems();
      saveCurrentPlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error reordering queue', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> reorderQueueById(String queueEntryId, int targetIndex) async {
    try {
      _queueEntryIds.ensureIds(_queueList);

      final oldIndex = _queueList.indexWhere(
        (s) => _queueEntryIds.ensureId(s) == queueEntryId,
      );
      if (oldIndex == -1) return;

      // Clamp target index to valid range (allow insert at end)
      if (targetIndex < 0) targetIndex = 0;
      if (targetIndex > _queueList.length) targetIndex = _queueList.length;

      logger.log(
        '[PLAYER] queue_reorder_by_id: entryId=$queueEntryId, old=$oldIndex, new=$targetIndex',
      );

      final song = _queueList.removeAt(oldIndex);
      var newIndex = targetIndex;
      if (newIndex > _queueList.length) newIndex = _queueList.length;
      _queueList.insert(newIndex, song);

      if (oldIndex == _currentQueueIndex) {
        _currentQueueIndex = newIndex;
      } else if (oldIndex < _currentQueueIndex &&
          newIndex >= _currentQueueIndex) {
        _currentQueueIndex--;
      } else if (oldIndex > _currentQueueIndex &&
          newIndex <= _currentQueueIndex) {
        _currentQueueIndex++;
      }

      if (oldIndex == _currentLoadingIndex) {
        _currentLoadingIndex = newIndex;
      } else if (oldIndex < _currentLoadingIndex &&
          newIndex >= _currentLoadingIndex) {
        _currentLoadingIndex--;
      } else if (oldIndex > _currentLoadingIndex &&
          newIndex <= _currentLoadingIndex) {
        _currentLoadingIndex++;
      }

      _updateQueueMediaItems();
      saveCurrentPlaybackState();
    } catch (e, stackTrace) {
      logger.log(
        'Error reordering queue by id',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void clearQueue() {
    try {
      logger.log('[PLAYER] queue_clear');
      final currentSong =
          _currentQueueIndex >= 0 && _currentQueueIndex < _queueList.length
          ? cloneMap(_queueList[_currentQueueIndex])
          : null;

      _queueList.clear();
      _originalQueueList.clear();

      if (currentSong != null) {
        _queueList.add(currentSong);
        _originalQueueList.add(cloneMap(currentSong));
      }

      _currentQueueIndex = 0;
      _currentLoadingIndex = -1;
      _currentLoadingTransitionId = -1;
      _resetPreloadingState();
      radioService.resetSession();
      _updateQueueMediaItems();
      _updatePlaybackState();
      saveCurrentPlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error clearing queue', error: e, stackTrace: stackTrace);
    }
  }

  void _updateQueueMediaItems() {
    try {
      _queueEntryIds.ensureIds(_queueList);

      final mediaItems = _buildQueueMediaItems();
      queue.add(mediaItems);

      _queueMapStream.add(List.unmodifiable(_queueList));

      if (_currentQueueIndex < mediaItems.length) {
        final currentMediaItem = mediaItems[_currentQueueIndex];
        mediaItem.add(currentMediaItem);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error updating queue media items',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _emitOptimisticLoadingState({
    Map? song,
    int? queueIndex,
    bool includeMediaItem = false,
    String? mediaId,
  }) {
    try {
      if (includeMediaItem && song != null) {
        final ytid = _songYtid(song);
        var immediateMediaItem = mapToMediaItem(
          song,
          onSquareArtworkReady: (squareUri) {
            final current = mediaItem.valueOrNull;
            if (current != null &&
                (current.extras?['ytid'] == ytid || current.id == mediaId) &&
                current.artUri != squareUri) {
              mediaItem.add(current.copyWith(artUri: squareUri));
            }
          },
        );
        if (mediaId != null) {
          immediateMediaItem = immediateMediaItem.copyWith(id: mediaId);
        }
        Future.microtask(() {
          mediaItem.add(immediateMediaItem);
        });
      }

      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.pause,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: AudioProcessingState.loading,
          queueIndex:
              queueIndex ??
              (_currentQueueIndex < _queueList.length
                  ? _currentQueueIndex
                  : null),
          updateTime: DateTime.now(),
        ),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error emitting optimistic loading state',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _playFromQueue(int index, {Duration? initialSeek}) async {
    if (index < 0 || index >= _queueList.length) {
      logger.log('Invalid queue index: $index');
      return;
    }

    // If already loading any song, skip the request
    // UNLESS we're in the middle of handling a completion event (allow one load attempt)
    if (_currentLoadingIndex == index && !_completionEventPending) {
      return;
    }

    if (_currentLoadingIndex >= 0 &&
        _completionEventPending &&
        !_completionHandlerLoadStarted) {
      _completionHandlerLoadStarted = true;
    } else if (_currentLoadingIndex >= 0 &&
        _completionEventPending &&
        _completionHandlerLoadStarted) {
      return;
    }

    // Start new transition
    _songTransitionCounter++;
    final currentTransitionId = _songTransitionCounter;
    _currentLoadingIndex = index;
    _currentLoadingTransitionId = currentTransitionId;
    _userRequestedPause = false;

    try {
      final previousQueueIndex = _currentQueueIndex;
      final previousMediaItem = mediaItem.valueOrNull;
      _currentQueueIndex = index;

      final currentSong = _queueList[_currentQueueIndex];
      final currentMediaItem = _getMediaItemForQueue(currentSong);
      final uniqueId = currentMediaItem.id;

      await Future.microtask(() {
        mediaItem.add(currentMediaItem);
      });

      _emitOptimisticLoadingState(
        queueIndex: _currentQueueIndex,
        mediaId: uniqueId,
      );

      final success = await playSong(
        _queueList[index],
        mediaId: uniqueId,
        transitionId: currentTransitionId,
        initialSeek: initialSeek,
      );

      // Only process result if this is still the current transition
      if (currentTransitionId == _currentLoadingTransitionId) {
        if (success) {
          _consecutiveErrors = 0;
          _preloadUpcomingSongs();
          // Trigger background song addition if auto-play is enabled
          if (playNextSongAutomatically.value) {
            unawaited(_backgroundAddSongsToQueue());
          }
        } else {
          _currentQueueIndex = previousQueueIndex;
          if (previousMediaItem != null) {
            mediaItem.add(previousMediaItem);
          }
          _updatePlaybackState();
          _handlePlaybackError();
        }
      }
    } catch (e, stackTrace) {
      logger.log('Error playing from queue', error: e, stackTrace: stackTrace);
      _handlePlaybackError();
    } finally {
      // Only reset if this is still the transition that started it
      if (currentTransitionId == _currentLoadingTransitionId) {
        _currentLoadingIndex = -1;
        _currentLoadingTransitionId = -1;
      }
    }
  }

  void _preloadUpcomingSongs() {
    // Don't attempt to preload while offline mode is enabled
    if (offlineMode.value) return;

    Future.microtask(() async {
      try {
        final songsToPreload = <Map>[];

        for (var i = 1; i <= _queueLookahead; i++) {
          final nextIndex = _currentQueueIndex + i;
          if (nextIndex < _queueList.length) {
            final nextSong = _queueList[nextIndex];
            final ytid = nextSong['ytid'];

            if (ytid != null &&
                !isSongAlreadyOffline(ytid) &&
                !_preloadedYtIds.contains(ytid) &&
                !_preloadingYtIds.contains(ytid)) {
              songsToPreload.add(nextSong);
            }
          }
        }

        for (final song in songsToPreload) {
          ArtworkService.instance.resolveArtUri(song);
        }

        await _preloadSongsSequentially(songsToPreload);
      } catch (e, stackTrace) {
        logger.log(
          'Error in _preloadUpcomingSongs',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<void> _preloadSongsSequentially(List<Map> songsToPreload) async {
    for (final song in songsToPreload) {
      while (_activePreloadCount >= _maxConcurrentPreloads) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final ytid = song['ytid'];
      if (ytid == null || _preloadingYtIds.contains(ytid)) {
        continue;
      }

      unawaited(_preloadSingleSongControlled(song));
    }
  }

  Future<void> _preloadSingleSongControlled(Map nextSong) async {
    final ytid = nextSong['ytid'];
    if (ytid == null) return;

    _preloadingYtIds.add(ytid);
    _activePreloadCount++;
    String? preloadUrl;

    try {
      // Don't attempt to fetch remote streams while offline mode is enabled
      if (offlineMode.value) {
        logger.log('Offline mode enabled; skipping preload for $ytid');
        preloadUrl = null;
      } else {
        // fetchSongStreamUrl handles caching, freshness checks, and validation
        preloadUrl =
            await fetchSongStreamUrl(
              ytid,
              nextSong['isLive'] ?? false,
              title: nextSong['title']?.toString(),
              artist: nextSong['artist']?.toString(),
            ).timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                logger.log('Preload timeout for song $ytid');
                return null;
              },
            );
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error preloading song $ytid',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _preloadingYtIds.remove(ytid);
      if (_activePreloadCount > 0) {
        _activePreloadCount--;
      }
      if (preloadUrl != null && preloadUrl.isNotEmpty) {
        _preloadedYtIds.add(ytid);
      }
    }
  }

  Stream<List<Map>> get queueAsMapStream => _queueMapStream.stream;
  List<Map> get queueList => List.unmodifiable(_queueList);
  int get currentQueueIndex => _currentQueueIndex;
  Map? get currentSong =>
      _currentQueueIndex >= 0 && _currentQueueIndex < _queueList.length
      ? _queueList[_currentQueueIndex]
      : null;

  bool get hasNext => _currentQueueIndex < _queueList.length - 1;

  bool get hasPrevious =>
      _currentQueueIndex > 0 ||
      _historyList.isNotEmpty ||
      (repeatNotifier.value == AudioServiceRepeatMode.all &&
          _queueList.length > 1);

  String _recentMediaId(String ytid) => '$_recentMediaIdPrefix$ytid';

  String? _ytidFromMediaId(String mediaId) {
    if (mediaId.startsWith(_recentMediaIdPrefix)) {
      return mediaId.substring(_recentMediaIdPrefix.length);
    }
    return mediaId.isEmpty ? null : mediaId;
  }

  String? _songYtid(Map song) {
    return canonicalSongId(song);
  }

  Map? _firstPlayableSong(Iterable songs) {
    for (final song in songs.whereType<Map>()) {
      if (_songYtid(song) != null) {
        return song;
      }
    }
    return null;
  }

  Map? _findSongInList(Iterable songs, String ytid) {
    for (final song in songs.whereType<Map>()) {
      if (_songYtid(song) == ytid) {
        return song;
      }
    }
    return null;
  }

  Map? _findSongByYtid(String? ytid) {
    if (ytid == null || ytid.isEmpty) return null;

    final activeSong = currentSong;
    if (_songYtid(activeSong ?? const {}) == ytid) {
      return activeSong;
    }

    for (final source in [
      _queueList,
      userRecentlyPlayed.value,
      userOfflineSongs.value,
      userLikedSongsList.value,
    ]) {
      final song = _findSongInList(source, ytid);
      if (song != null) return song;
    }

    return null;
  }

  Map? _latestResumableSong() {
    final activeSong = currentSong;
    if (activeSong != null && _songYtid(activeSong) != null) {
      return activeSong;
    }

    final activeMediaItem = mediaItem.valueOrNull;
    final activeYtid = activeMediaItem?.extras?['ytid']?.toString();
    final activeMediaSong = _findSongByYtid(activeYtid);
    if (activeMediaSong != null) return activeMediaSong;
    if (activeYtid != null &&
        activeYtid.isNotEmpty &&
        activeMediaItem != null) {
      return mediaItemToMap(activeMediaItem);
    }

    return _firstPlayableSong(userRecentlyPlayed.value) ??
        _firstPlayableSong(userOfflineSongs.value) ??
        _firstPlayableSong(userLikedSongsList.value);
  }

  Map<String, dynamic>? _normaliseResumableSong(Map song) {
    final ytid = _songYtid(song);
    if (ytid == null) return null;

    final normalised = cloneMap(song);
    normalised['id'] = ytid;
    normalised['ytid'] = ytid;
    normalised['highResImage'] ??=
        normalised['image'] ?? normalised['lowResImage'] ?? '';
    normalised['lowResImage'] ??= normalised['highResImage'];
    normalised['isLive'] ??= false;
    return normalised;
  }

  MediaItem? _mediaItemForResumption(Map song) {
    final normalisedSong = _normaliseResumableSong(song);
    if (normalisedSong == null) return null;

    final ytid = normalisedSong['ytid'].toString();
    final artist = normalisedSong['artist']?.toString().trim() ?? '';
    return mapToMediaItem(normalisedSong).copyWith(
      id: _recentMediaId(ytid),
      displayTitle: normalisedSong['title']?.toString(),
      displaySubtitle: artist.isEmpty ? 'Catchify' : artist,
    );
  }

  Future<void> _playResumableSong(Map song) async {
    final normalisedSong = _normaliseResumableSong(song);
    if (normalisedSong == null) return;

    await playPlaylistSong(
      playlist: {
        'title': 'Catchify',
        'source': 'system-recent',
        'list': [normalisedSong],
      },
      songIndex: 0,
    );
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    try {
      return await AndroidAutoService.getChildren(
        parentMediaId,
        queue.valueOrNull,
      );
    } catch (e, stackTrace) {
      logger.log('Error in getChildren', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final song = _findSongByYtid(_ytidFromMediaId(mediaId));
    return song == null ? null : _mediaItemForResumption(song);
  }

  @override
  Future<void> prepareFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final item = await getMediaItem(mediaId);
    if (item == null) return;

    mediaItem.add(item);
    queue.add([item]);
    playbackState.add(
      PlaybackState(
        controls: _controls(false),
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        queueIndex: 0,
        updateTime: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final result = await AndroidAutoService.handlePlayRequest(
        mediaId,
        extras,
      );
      if (result != null) {
        await addPlaylistToQueue(
          result.songs,
          replace: true,
          startIndex: result.startIndex,
        );
        return;
      }

      final song = _findSongByYtid(_ytidFromMediaId(mediaId));
      if (song != null) {
        await _playResumableSong(song);
        return;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error handling playFromMediaId',
        error: e,
        stackTrace: stackTrace,
      );
    }

    await super.playFromMediaId(mediaId, extras);
  }

  @override
  Future<void> onTaskRemoved() async {
    try {
      await stop();
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e, stackTrace) {
      logger.log('Error in onTaskRemoved', error: e, stackTrace: stackTrace);
    }
    await super.onTaskRemoved();
  }

  @override
  Future<void> play() async {
    _cancelNetworkRecovery();
    _userRequestedPause = false;
    try {
      logger.log('[PLAYER] play');
      if (audioPlayer.processingState == ProcessingState.completed) {
        await playAgain();
        return;
      }
      if (audioPlayer.audioSource == null) {
        if (_queueList.isNotEmpty &&
            _currentQueueIndex >= 0 &&
            _currentQueueIndex < _queueList.length) {
          final initialSeek = _restoredPosition;
          _restoredPosition = null;
          await _playFromQueue(_currentQueueIndex, initialSeek: initialSeek);
          return;
        }
        final recentSong = _latestResumableSong();
        if (recentSong != null) {
          await _playResumableSong(recentSong);
          return;
        }
      }
      // Do NOT await play(): its future only completes when playback pauses/
      // stops/finishes (just_audio semantics), which would defer the resume
      // below until the song ended - losing the whole session.
      unawaited(
        audioPlayer.play().catchError((Object e, StackTrace stackTrace) {
          logger.log(
            'Error starting playback',
            error: e,
            stackTrace: stackTrace,
          );
          _lastError = e.toString();
        }),
      );
      listeningStatsService.resumeListeningSession(currentSong: currentSong);
      _updatePlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error in play()', error: e, stackTrace: stackTrace);
      _lastError = e.toString();
    }
  }

  @override
  Future<void> pause() async {
    try {
      logger.log('[PLAYER] pause');
      _userRequestedPause = true;
      listeningStatsService.recordListeningSessionProgress(
        wasPlaying: audioPlayer.playing,
      );
      unawaited(listeningStatsService.flush());
      await audioPlayer.pause();
      saveCurrentPlaybackState();
      _updatePlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error in pause()', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> stop() async {
    _cancelNetworkRecovery();
    logger.log('[PLAYER] stop');
    _debounceTimer?.cancel();
    _completionEventPending = false;
    _currentLoadingIndex = -1;
    _currentLoadingTransitionId = -1;
    _lastError = null;
    _consecutiveErrors = 0;
    _userRequestedPause = false;
    try {
      listeningStatsService.finishListeningSession(
        countCurrentTick: true,
        wasPlaying: audioPlayer.playing,
      );
      await audioPlayer.stop();
      _resetPreloadingState();
      saveCurrentPlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error in stop()', error: e, stackTrace: stackTrace);
    }
    await super.stop();
  }

  /// Returns unplayed manually added songs after the current queue index.
  List<Map> _getUnplayedManualSongs() {
    return _queueList
        .skip(_currentQueueIndex >= 0 ? _currentQueueIndex + 1 : 0)
        .where(
          (song) =>
              song['isManuallyAdded'] == true && song['isAutoPicked'] != true,
        )
        .toList();
  }

  void _resetPreloadingState() {
    _activePreloadCount = 0;
    _preloadingYtIds.clear();
    _preloadedYtIds.clear();
    _isFetchingAutoplay = false;
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      final trackDuration =
          mediaItem.valueOrNull?.duration ?? audioPlayer.duration;
      var targetPosition = position;
      if (targetPosition < Duration.zero) {
        targetPosition = Duration.zero;
      } else if (trackDuration != null &&
          trackDuration > Duration.zero &&
          targetPosition > trackDuration) {
        targetPosition = trackDuration;
      }

      if (audioPlayer.audioSource == null) {
        _restoredPosition = targetPosition;
        _saveLastPositionThrottled(targetPosition.inMilliseconds);
        _updatePlaybackState();
        return;
      }

      listeningStatsService.recordListeningSessionProgress(
        wasPlaying: audioPlayer.playing,
      );
      await audioPlayer.seek(targetPosition);
      unawaited(listeningStatsService.flush());
      _saveLastPositionThrottled(targetPosition.inMilliseconds);
    } catch (e, stackTrace) {
      logger.log('Error in seek()', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> fastForward() {
    final target = audioPlayer.position + const Duration(seconds: 15);
    final trackDuration =
        mediaItem.valueOrNull?.duration ?? audioPlayer.duration;
    final clamped =
        (trackDuration != null &&
            trackDuration > Duration.zero &&
            target > trackDuration)
        ? trackDuration
        : target;
    return seek(clamped);
  }

  @override
  Future<void> rewind() {
    final target = audioPlayer.position - const Duration(seconds: 15);
    final clamped = target < Duration.zero ? Duration.zero : target;
    return seek(clamped);
  }

  Future<bool> _resolveOfflineAndSetPaths(Map songData) async {
    try {
      final ytid = canonicalSongId(songData);
      if (ytid != null) {
        final offlineSong = getOfflineSongByYtid(ytid);
        if (offlineSong.isNotEmpty) {
          final audioPath = offlineSong['audioPath']?.toString();
          if (audioPath != null && audioPath.isNotEmpty) {
            final f = File(audioPath);
            if (await f.exists()) {
              songData['audioPath'] = audioPath;
              final storedArtworkPath = offlineSong['artworkPath']?.toString();
              final artworkCandidates = <String>[
                if (storedArtworkPath != null && storedArtworkPath.isNotEmpty)
                  storedArtworkPath,
                FilePaths.getArtworkPath(ytid),
              ];
              for (final artworkPath in artworkCandidates) {
                final artworkFile = File(artworkPath);
                if (await artworkFile.exists() &&
                    await artworkFile.length() > 0) {
                  songData['artworkPath'] = artworkFile.path;
                  break;
                }
              }
              return true;
            }
          }
        }
      }
    } catch (e, st) {
      logger.log(
        'Error while checking offline songs',
        error: e,
        stackTrace: st,
      );
    }

    // Fallback: prefer an existing local `audioPath` on the passed song
    // object if the file exists.
    try {
      final path = songData['audioPath']?.toString();
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (await f.exists()) return true;
      }
    } catch (_) {}

    return false;
  }

  /// Check if the given transitionId is stale (outdated by a newer request).
  bool _isStaleTransition(int? transitionId) {
    return transitionId != null && transitionId != _currentLoadingTransitionId;
  }

  Future<bool> playSong(
    Map song, {
    String? mediaId,
    int? transitionId,
    Duration? initialSeek,
  }) async {
    try {
      final songData = cloneMap(song);

      final canonicalId = canonicalSongId(songData);
      if (canonicalId == null) {
        logger.log('[PLAYER] Invalid song data: missing ytid');
        return false;
      }
      _lastCompletedSongId = null;
      _hasPreloadedCurrentTrackEnd = false;
      _userRequestedPause = false;
      songData['id'] = canonicalId;
      songData['ytid'] = canonicalId;

      logger.log(
        '[PLAYER] play: ytid=${songData['ytid']}, title=${songData['title'] ?? ''}',
      );

      _lastError = null;
      if (audioPlayer.playing) {
        listeningStatsService.recordListeningSessionProgress(
          wasPlaying: audioPlayer.playing,
        );
        await audioPlayer.pause();
      }

      // Transparently ensure the track streams the official YouTube Music audio track
      try {
        final officialId = await resolveOfficialAudioYtId(
          songData['ytid'].toString(),
          title: songData['title']?.toString(),
          artist: songData['artist']?.toString(),
        );
        if (officialId != songData['ytid']) {
          logger.log(
            'Resolved track ${songData['ytid']} to official YouTube Music audio: $officialId',
          );
          songData['ytid'] = officialId;
          final qIndex = _currentQueueIndex;
          if (qIndex >= 0 && qIndex < _queueList.length) {
            _queueList[qIndex]['ytid'] = officialId;
          }
        }
      } catch (_) {}

      // If duration is missing (e.g. from an older import or external source),
      // resolve accurate metadata duration to protect iOS AVPlayer from doubling duration.
      if (songData['duration'] == null || songData['duration'] <= 0) {
        try {
          final video = await ProxyManager()
              .getClientSync()
              .videos
              .get(songData['ytid'])
              .timeout(const Duration(seconds: 4));
          if (video.duration != null && video.duration! > Duration.zero) {
            songData['duration'] = video.duration!.inSeconds;
            final qIndex = _currentQueueIndex;
            if (qIndex >= 0 &&
                qIndex < _queueList.length &&
                _queueList[qIndex]['ytid'] == songData['ytid']) {
              _queueList[qIndex]['duration'] = video.duration!.inSeconds;
            }
          }
        } catch (_) {}
      }

      final playback = await _resolvePlaybackSource(songData);

      // Abort if a newer song was requested while we were fetching the stream URL.
      // This is the primary guard against the race condition where a slow streaming
      // load overrides a song the user already switched to.
      if (_isStaleTransition(transitionId)) {
        logger.log(
          'Song load superseded by newer request, aborting: ${songData['ytid']}',
        );
        return false;
      }

      if (playback == null) {
        _lastError = 'Failed to get song URL';
        return false;
      }

      _emitOptimisticLoadingState(
        song: songData,
        includeMediaItem: true,
        mediaId: mediaId,
      );

      final audioSource = await buildAudioSource(
        songData,
        playback.songUrl,
        playback.isOffline,
      );

      // Check again after building the audio source (SponsorBlock fetch can also be slow).
      if (_isStaleTransition(transitionId)) {
        logger.log(
          'Song load superseded after building audio source, aborting: ${songData['ytid']}',
        );
        return false;
      }

      if (audioSource == null) {
        logger.log('Failed to build audio source for ${songData['ytid']}');
        _lastError = 'Failed to build audio source';
        return false;
      }

      return await _setAudioSourceAndPlay(
        songData,
        audioSource,
        playback.songUrl,
        playback.isOffline,
        mediaId: mediaId,
        transitionId: transitionId,
        initialSeek: initialSeek,
      );
    } catch (e, stackTrace) {
      logger.log('Error playing song', error: e, stackTrace: stackTrace);
      _lastError = e.toString();
      return false;
    }
  }

  Future<_PlaybackSource?> _resolvePlaybackSource(Map songData) async {
    final isOffline = await _resolveOfflineAndSetPaths(songData);
    logger.log(
      '[PLAYER] stream_resolve: ytid=${songData['ytid']}, isOffline=$isOffline',
    );
    final songUrl = await _getPlaybackUrl(songData, isOffline);

    if (songUrl == null || songUrl.isEmpty) {
      if (!isOffline) {
        logger.log('[PLAYER] Failed to get song URL for ${songData['ytid']}');
        return null;
      }

      // If offline mode is enabled, do NOT fall back to online streams.
      // This prevents network requests while the user explicitly requested
      // offline-only operation.
      try {
        if (offlineMode.value) {
          logger.log(
            'Offline mode enabled and offline file missing for ${songData['ytid']}. Not falling back to online.',
          );
          return null;
        }
      } catch (_) {
        // If offlineMode isn't available for some reason, continue with fallback.
      }

      logger.log(
        'Offline file missing for ${songData['ytid']}, switching to online',
      );

      final onlineUrl = await fetchSongStreamUrl(
        songData['ytid'],
        songData['isLive'] ?? false,
        title: songData['title']?.toString(),
        artist: songData['artist']?.toString(),
      );

      if (onlineUrl == null || onlineUrl.isEmpty) {
        logger.log('Failed to get song URL for ${songData['ytid']}');
        return null;
      }

      return _PlaybackSource(songUrl: onlineUrl, isOffline: false);
    }

    return _PlaybackSource(songUrl: songUrl, isOffline: isOffline);
  }

  Future<String?> _getPlaybackUrl(Map song, bool isOffline) async {
    if (isOffline) {
      return _getOfflineSongUrl(song);
    }

    return fetchSongStreamUrl(
      song['ytid'],
      song['isLive'] ?? false,
      title: song['title']?.toString(),
      artist: song['artist']?.toString(),
    );
  }

  Future<String?> _getOfflineSongUrl(Map song) async {
    final audioPath = song['audioPath'];
    if (audioPath != null && audioPath.toString().isNotEmpty) {
      final file = File(audioPath.toString());
      if (await file.exists()) {
        return audioPath.toString();
      }
    }

    final songId = canonicalSongId(song);
    final offlineSong = userOfflineSongs.value.firstWhere(
      (s) => s['ytid'] == songId || s['id'] == songId,
      orElse: () => userLocalSongs.value.firstWhere(
        (s) => s['ytid'] == songId || s['id'] == songId,
        orElse: () => <String, dynamic>{},
      ),
    );

    if (offlineSong.isNotEmpty && offlineSong['audioPath'] != null) {
      final fallbackPath = offlineSong['audioPath'].toString();
      final fallbackFile = File(fallbackPath);
      if (await fallbackFile.exists()) {
        song['audioPath'] = fallbackPath;
        return fallbackPath;
      }
    }

    return null;
  }

  Future<bool> _setAudioSourceAndPlay(
    Map song,
    AudioSource audioSource,
    String songUrl,
    bool isOffline, {
    String? mediaId,
    bool allowOnlineRetry = true,
    int? transitionId,
    Duration? initialSeek,
  }) async {
    try {
      // Final staleness check before we touch the audio player.
      // If another song was requested between the URL fetch and here, abort.
      if (_isStaleTransition(transitionId)) {
        return false;
      }

      // Snapshot the pre-swap playing state now: by the time we're committed
      // to this transition (below), audioPlayer.playing reflects the new
      // source, not whatever session we're about to finish.
      final wasPlayingBeforeSwap = audioPlayer.playing;

      await audioPlayer
          .setAudioSource(audioSource, initialPosition: initialSeek)
          .timeout(_songTransitionTimeout);
      _restoredPosition = null;

      // Check once more after the async setAudioSource: a fast offline song
      // could have loaded and started playing while we were buffering/setting up.
      // If so, stop the source we just loaded and yield to the newer song.
      if (_isStaleTransition(transitionId)) {
        unawaited(audioPlayer.stop());
        return false;
      }

      if (audioPlayer.duration != null) {
        _updateCurrentMediaItemWithDuration(audioPlayer.duration!);
      }

      // Finish the old session and start the new one as one atomic pair, only
      // after every abort path above is cleared. Finishing before the staleness
      // re-check let a stale transition kill a newer transition's session.
      // Do this before awaiting play() so Wrapped starts counting from the
      // first moments of the new track, not after the async handoff.
      listeningStatsService
        ..finishListeningSession(
          countCurrentTick: true,
          wasPlaying: wasPlayingBeforeSwap,
        )
        ..startListeningSession(
          song,
          duration: mediaItem.valueOrNull?.duration ?? audioPlayer.duration,
        );

      if (_userRequestedPause) {
        logger.log(
          '[PLAYER] User requested pause during song load; staying paused',
        );
        await audioPlayer.pause();
        _updatePlaybackState();
        unawaited(updateRecentlyPlayed(song['ytid'], songFallback: song));
        return true;
      }

      unawaited(
        audioPlayer.play().catchError((Object e, StackTrace stackTrace) {
          logger.log(
            'Error starting playback',
            error: e,
            stackTrace: stackTrace,
          );
          _lastError = e.toString();
        }),
      );
      unawaited(updateRecentlyPlayed(song['ytid'], songFallback: song));

      if (!isOffline) {
        final cacheKey =
            'song_${song['ytid']}_${audioQualitySetting.value}_url';
        unawaited(addOrUpdateData<String>('cache', cacheKey, songUrl));
      }

      _updatePlaybackState();
      saveCurrentPlaybackState();

      Future.delayed(const Duration(seconds: 2), _preloadUpcomingSongs);

      return true;
    } catch (e, stackTrace) {
      final isNetOffline = isNetworkError(e);
      logger.log(
        'Error setting audio source',
        error: e,
        stackTrace: isNetOffline ? null : stackTrace,
      );

      if (isOffline) {
        // If offline mode is explicitly enabled, do not attempt any online
        // fallback — respect the user's offline-only preference.
        try {
          if (offlineMode.value) {
            return false;
          }
        } catch (_) {
          // If offlineMode isn't accessible, fallthrough to attempt fallback.
        }

        return _attemptOfflineFallback(
          song,
          mediaId: mediaId,
          transitionId: transitionId,
        );
      }

      // If offline, do NOT evict the cached stream URL (the URL itself is fine,
      // only the network is down), and do NOT attempt fetchSongStreamUrl (which would stall).
      if (allowOnlineRetry && !isNetOffline) {
        if (offlineMode.value) {
          _lastError = e.toString();
          return false;
        }
        final songId = song['ytid']?.toString();
        if (songId != null && songId.isNotEmpty) {
          final cacheKey = 'song_${songId}_${audioQualitySetting.value}_url';
          await deleteData('cache', cacheKey);

          final refreshedUrl = await fetchSongStreamUrl(
            songId,
            song['isLive'] ?? false,
            title: song['title']?.toString(),
            artist: song['artist']?.toString(),
          );

          if (refreshedUrl != null && refreshedUrl.isNotEmpty) {
            final refreshedSource = await buildAudioSource(
              song,
              refreshedUrl,
              false,
            );

            if (refreshedSource != null) {
              return _setAudioSourceAndPlay(
                song,
                refreshedSource,
                refreshedUrl,
                false,
                mediaId: mediaId,
                allowOnlineRetry: false,
                transitionId: transitionId,
              );
            }
          }
        }
      }

      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> _attemptOfflineFallback(
    Map song, {
    String? mediaId,
    int? transitionId,
  }) async {
    // Do not attempt any network calls when offline mode is enabled.
    if (offlineMode.value) return false;

    final onlineUrl = await fetchSongStreamUrl(
      song['ytid'],
      song['isLive'] ?? false,
      title: song['title']?.toString(),
      artist: song['artist']?.toString(),
    );
    if (onlineUrl != null && onlineUrl.isNotEmpty) {
      final onlineSource = await buildAudioSource(song, onlineUrl, false);
      if (onlineSource != null) {
        return _setAudioSourceAndPlay(
          song,
          onlineSource,
          onlineUrl,
          false,
          mediaId: mediaId,
          transitionId: transitionId,
        );
      }
    }
    return false;
  }

  Future<void> playNext(Map song) async {
    await addToQueue(song, playNext: true);
  }

  /// Starts an algorithmic song radio station for [seedSong] using YouTube Music's
  /// dedicated Automix endpoint (RDAMVM). Loads related tracks and starts playing.
  Future<bool> startSongRadio(Map seedSong) async {
    try {
      final radioQueue = await radioService.getRadioForSong(
        seedSong,
        limit: 30,
      );
      if (radioQueue.isEmpty) return false;

      await playAll(radioQueue);
      return true;
    } catch (e, stackTrace) {
      logger.log(
        '[RADIO_ERROR] Error starting song radio for ${seedSong['title']}',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Starts an algorithmic radio station for [artist].
  Future<bool> startArtistRadio(Map artist, {List<Map>? fallbackSongs}) async {
    try {
      final radioQueue = await radioService.getRadioForArtist(
        artist,
        fallbackSongs: fallbackSongs,
        limit: 30,
      );
      if (radioQueue.isEmpty) return false;

      await playAll(radioQueue);
      return true;
    } catch (e, stackTrace) {
      logger.log(
        '[RADIO_ERROR] Error starting artist radio for ${artist['title'] ?? artist['name']}',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Starts an algorithmic radio station seeded from [album].
  Future<bool> startAlbumRadio(Map album, {List<Map>? albumSongs}) async {
    try {
      final radioQueue = await radioService.getRadioForAlbum(
        album,
        albumSongs: albumSongs,
        limit: 30,
      );
      if (radioQueue.isEmpty) return false;

      await playAll(radioQueue);
      return true;
    } catch (e, stackTrace) {
      logger.log(
        '[RADIO_ERROR] Error starting album radio for ${album['title']}',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Plays a single song immediately by replacing the active queue with this song.
  Future<void> playNow(Map song) async {
    logger.log(
      '[PLAYER] play_now: ${song['title'] ?? song['ytid'] ?? song['id']}',
    );
    await addPlaylistToQueue([song], replace: true, startIndex: 0);
  }

  /// Plays all songs from a source list, replacing the active queue.
  Future<void> playAll(
    List<Map> songs, {
    int initialIndex = 0,
    bool shuffle = false,
  }) async {
    logger.log(
      '[PLAYER] play_all: count=${songs.length}, start=$initialIndex, shuffle=$shuffle',
    );
    await addPlaylistToQueue(
      songs,
      replace: true,
      startIndex: initialIndex,
      shuffle: shuffle,
    );
  }

  Future<void> playPlaylistSong({
    Map<dynamic, dynamic>? playlist,
    required int songIndex,
    bool shuffle = false,
  }) async {
    try {
      if (playlist != null && playlist['list'] != null) {
        await addPlaylistToQueue(
          List<Map>.from(playlist['list']),
          replace: true,
          startIndex: songIndex,
          shuffle: shuffle,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error playing playlist', error: e, stackTrace: stackTrace);
    }
  }

  Future<AudioSource?> buildAudioSource(
    Map song,
    String songUrl,
    bool isOffline,
  ) async {
    try {
      final tag = mapToMediaItem(song);

      if (isOffline) {
        return ProgressiveAudioSource(
          Uri.file(songUrl),
          tag: tag,
          duration: tag.duration,
          options: const ProgressiveAudioSourceOptions(
            darwinAssetOptions: DarwinAssetOptions(
              preferPreciseDurationAndTiming: true,
            ),
          ),
        );
      }

      final uri = Uri.parse(songUrl);
      final isHls =
          uri.path.toLowerCase().endsWith('.m3u8') ||
          uri.fragment.toLowerCase().endsWith('.m3u8');
      final isDash =
          uri.path.toLowerCase().endsWith('.mpd') ||
          uri.fragment.toLowerCase().endsWith('.mpd');

      final UriAudioSource audioSource;
      if (isDash) {
        audioSource = DashAudioSource(uri, tag: tag);
      } else if (isHls) {
        audioSource = HlsAudioSource(uri, tag: tag);
      } else {
        audioSource = ProgressiveAudioSource(
          uri,
          tag: tag,
          duration: tag.duration,
          options: const ProgressiveAudioSourceOptions(
            darwinAssetOptions: DarwinAssetOptions(
              preferPreciseDurationAndTiming: true,
            ),
          ),
        );
      }

      if (!sponsorBlockSupport.value) {
        return audioSource;
      }

      final spbAudioSource = await checkIfSponsorBlockIsAvailable(
        audioSource,
        song['ytid'],
      );
      return spbAudioSource ?? audioSource;
    } catch (e, stackTrace) {
      logger.log(
        'Error building audio source',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<AudioSource?> checkIfSponsorBlockIsAvailable(
    UriAudioSource audioSource,
    String songId,
  ) async {
    try {
      final segments = await getSkipSegments(songId);
      if (segments.isEmpty) return null;

      // Sort segments by start time
      segments.sort((a, b) => (a['start'] ?? 0).compareTo(b['start'] ?? 0));

      final children = <AudioSource>[];
      var lastEnd = 0;

      for (final segment in segments) {
        final start = segment['start'] ?? 0;
        final end = segment['end'] ?? 0;

        // Add the "good" part before this sponsor segment
        if (start > lastEnd) {
          children.add(
            ClippingAudioSource(
              child: audioSource,
              start: Duration(seconds: lastEnd),
              end: Duration(seconds: start),
            ),
          );
        }

        // Advance lastEnd, handling overlapping segments
        if (end > lastEnd) {
          lastEnd = end;
        }
      }

      // Add the final part from the last sponsor segment to the end of the song
      children.add(
        ClippingAudioSource(
          child: audioSource,
          start: Duration(seconds: lastEnd),
          // end: null means play until the end of the file
        ),
      );

      if (children.length == 1) {
        return children.first;
      }

      // ignore: deprecated_member_use
      return ConcatenatingAudioSource(children: children);
    } catch (e, stackTrace) {
      logger.log(
        'Error checking sponsor block',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> skipToSong(int newIndex) async {
    try {
      if (newIndex < 0 || newIndex >= _queueList.length) {
        logger.log('Invalid song index: $newIndex');
        return;
      }
      await _playFromQueue(newIndex);
    } catch (e, stackTrace) {
      logger.log('Error skipping to song', error: e, stackTrace: stackTrace);
    }
  }

  /// Intelligently play a song from a source (e.g., offline, liked songs) without
  /// destroying the existing queue:
  /// - If the song is already in the queue, jump to it
  /// - If not, add it and play it
  /// - Only add songs from the source that aren't already queued
  ///
  /// This preserves the user's curated queue while allowing them to play songs
  /// from any source without frustration.
  Future<void> playSongSmartly({
    required Map song,
    Map<dynamic, dynamic>? sourcePlaylist,
  }) async {
    try {
      final songYtid = song['ytid']?.toString();

      if (songYtid == null || songYtid.isEmpty) {
        // Fallback if no ytid
        await playSong(song);
        return;
      }

      // Check if song is already in queue
      final existingIndex = _queueList.indexWhere(
        (s) => s['ytid']?.toString() == songYtid,
      );
      if (existingIndex != -1) {
        // Song already in queue, just skip to it
        await skipToQueueItem(existingIndex);
        return;
      }

      // Song not in queue, add it and play it
      await addToQueue(song);

      final newIndex = _queueList.indexWhere(
        (s) => s['ytid']?.toString() == songYtid,
      );
      if (newIndex != -1) {
        await _playFromQueue(newIndex);
      }

      // If a source playlist is provided, also add new songs from it to queue
      // (songs not already there), for better discoverability
      if (sourcePlaylist != null && sourcePlaylist['list'] is List) {
        await addNewSongsToQueue(List<Map>.from(sourcePlaylist['list']));
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error playing song smartly',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Adds songs to the queue that aren't already there. Used to intelligently
  /// merge playlists without destroying the existing queue.
  Future<void> addNewSongsToQueue(List<Map> songs) async {
    try {
      final currentYtids = {
        for (final song in _queueList) song['ytid']?.toString(),
      };

      final newSongs = [
        for (final song in songs)
          if (!currentYtids.contains(song['ytid']?.toString())) song,
      ];

      if (newSongs.isNotEmpty) {
        await addPlaylistToQueue(newSongs);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error adding new songs to queue',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> skipToQueueItem(int index) => skipToSong(index);

  @override
  Future<void> skipToNext() async {
    try {
      logger.log(
        '[PLAYER] next: from=$_currentQueueIndex, queueLength=${_queueList.length}',
      );
      if (_currentQueueIndex < _queueList.length - 1) {
        await _playFromQueue(_currentQueueIndex + 1);
      } else if (repeatNotifier.value == AudioServiceRepeatMode.all &&
          _queueList.isNotEmpty) {
        await _playFromQueue(0);
      } else if (playNextSongAutomatically.value &&
          _currentLoadingIndex == -1) {
        // At end of queue with auto-play enabled - trigger background fetch and play
        logger.log('[PLAYER] queue_exhausted: auto-play triggering radio');
        await _backgroundAddSongsToQueue(forcePlayIfEnd: true);
      } else {
        logger.log('[PLAYER] queue_exhausted: stopping at end of queue');
        await stop();
      }

      _cleanupOldPreloadedSongs();
    } catch (e, stackTrace) {
      logger.log(
        'Error skipping to next song',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      logger.log(
        '[PLAYER] previous: from=$_currentQueueIndex, pos=${audioPlayer.position.inSeconds}s',
      );
      if (audioPlayer.position > const Duration(seconds: 3) || !hasPrevious) {
        await seek(Duration.zero);
        return;
      }

      if (_currentQueueIndex > 0) {
        await _playFromQueue(_currentQueueIndex - 1);
      } else if (_historyList.isNotEmpty) {
        // _historyList is newest-first (see _addToHistory's insert(0, ...)),
        // so the most recently played song is at index 0, not the end.
        final lastSong = cloneMap(_historyList.removeAt(0));
        _queueList.insert(0, lastSong);
        _currentQueueIndex = 0;
        _updateQueueMediaItems();
        await _playFromQueue(0);
      } else if (repeatNotifier.value == AudioServiceRepeatMode.all &&
          _queueList.length > 1) {
        await _playFromQueue(_queueList.length - 1);
      }

      _cleanupOldPreloadedSongs();
    } catch (e, stackTrace) {
      logger.log(
        'Error skipping to previous song',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> playAgain() async {
    try {
      listeningStatsService.finishListeningSession(
        countCurrentTick: true,
        wasPlaying: audioPlayer.playing,
      );
      await audioPlayer.seek(Duration.zero);
      unawaited(
        audioPlayer.play().catchError((Object e, StackTrace stackTrace) {
          logger.log('Error playing again', error: e, stackTrace: stackTrace);
        }),
      );
      final song = currentSong;
      if (song != null) {
        listeningStatsService.startListeningSession(
          song,
          duration: mediaItem.valueOrNull?.duration ?? audioPlayer.duration,
        );
        unawaited(updateRecentlyPlayed(song['ytid'], songFallback: song));
      }
    } catch (e, stackTrace) {
      logger.log('Error playing again', error: e, stackTrace: stackTrace);
    }
  }

  Map<Map, String> _buildIdMap(List<Map> songs) {
    return {for (final song in songs) song: _queueEntryIds.ensureId(song)};
  }

  void _enableShuffle(
    List<Map> unplayedManualSongs,
    Set<String> manualSongIds,
  ) {
    _originalQueueList
      ..clear()
      ..addAll(cloneMaps(_queueList));

    final currentSong =
        (_currentQueueIndex >= 0 && _currentQueueIndex < _queueList.length)
        ? _queueList[_currentQueueIndex]
        : _queueList.first;
    final currentQueueEntryId = _queueEntryIds.ensureId(currentSong);

    final queueIdMap = _buildIdMap(_queueList);
    _queueList
      ..removeWhere((song) => manualSongIds.contains(queueIdMap[song]))
      ..shuffle();

    final newCurrentIndex = _queueList.indexWhere(
      (song) => _queueEntryIds.ensureId(song) == currentQueueEntryId,
    );

    if (newCurrentIndex != -1 && newCurrentIndex != 0) {
      _queueList
        ..removeAt(newCurrentIndex)
        ..insert(0, currentSong);
    }

    _queueList.insertAll(_queueList.isNotEmpty ? 1 : 0, unplayedManualSongs);

    _currentQueueIndex = 0;
    _updateQueueMediaItems();
  }

  void _disableShuffle(
    List<Map> unplayedManualSongs,
    Set<String> manualSongIds,
  ) {
    if (_originalQueueList.isEmpty) return;

    final currentSong =
        (_currentQueueIndex >= 0 && _currentQueueIndex < _queueList.length)
        ? _queueList[_currentQueueIndex]
        : _queueList.first;
    final currentQueueEntryId = _queueEntryIds.ensureId(currentSong);

    final restoredQueue = cloneMaps(_originalQueueList);
    final restoredQueueIdMap = _buildIdMap(restoredQueue);
    restoredQueue.removeWhere(
      (song) => manualSongIds.contains(restoredQueueIdMap[song]),
    );

    _queueList
      ..clear()
      ..addAll(restoredQueue);

    _currentQueueIndex = _queueList.indexWhere(
      (song) => _queueEntryIds.ensureId(song) == currentQueueEntryId,
    );

    if (_currentQueueIndex == -1) {
      _currentQueueIndex = 0;
    }

    final insertIndex = _currentQueueIndex + 1;
    _queueList.insertAll(insertIndex, unplayedManualSongs);

    _originalQueueList.clear();
    _updateQueueMediaItems();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    try {
      final shuffleEnabled = shuffleMode != AudioServiceShuffleMode.none;
      final wasShuffled = shuffleNotifier.value;

      logger.log('[PLAYER] shuffle: $shuffleEnabled');
      shuffleNotifier.value = shuffleEnabled;
      unawaited(Hive.box('settings').put('shuffleEnabled', shuffleEnabled));
      await audioPlayer.setShuffleModeEnabled(shuffleEnabled);

      if (_queueList.isEmpty) {
        _updatePlaybackState();
        return;
      }

      if (shuffleEnabled && !wasShuffled) {
        _hydrateQueueEntryIds();
        final unplayedManualSongs = _getUnplayedManualSongs();
        final manualSongIds = unplayedManualSongs
            .map(_queueEntryIds.ensureId)
            .toSet();
        _enableShuffle(unplayedManualSongs, manualSongIds);
      } else if (!shuffleEnabled && wasShuffled) {
        _hydrateQueueEntryIds();
        final unplayedManualSongs = _getUnplayedManualSongs();
        final manualSongIds = unplayedManualSongs
            .map(_queueEntryIds.ensureId)
            .toSet();
        _disableShuffle(unplayedManualSongs, manualSongIds);
      }

      _updatePlaybackState();
    } catch (e, stackTrace) {
      logger.log(
        'Error setting shuffle mode',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    try {
      logger.log('[PLAYER] repeat: $repeatMode');
      repeatNotifier.value = repeatMode;
      unawaited(Hive.box('settings').put('repeatMode', repeatMode.index));

      // Always set loop mode to off - we handle all repeating through _handleSongCompletion
      // This ensures ProcessingState.completed is always fired for proper song transitions
      await audioPlayer.setLoopMode(LoopMode.off);
      _updatePlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error setting repeat mode', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> setSleepTimer(Duration duration) async {
    try {
      _sleepTimer?.cancel();
      sleepTimerExpired = false;
      sleepTimerEndOfSong = false;
      _sleepTimerRemainingSongs = null;
      sleepTimerNotifier.value = duration;

      _sleepTimer = Timer(duration, () async {
        sleepTimerExpired = true;
        await stop();
        sleepTimerNotifier.value = null;
      });
    } catch (e, stackTrace) {
      logger.log('Error setting sleep timer', error: e, stackTrace: stackTrace);
    }
  }

  void cancelSleepTimer() {
    try {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      sleepTimerExpired = false;
      sleepTimerEndOfSong = false;
      _sleepTimerRemainingSongs = null;
      sleepTimerNotifier.value = null;
    } catch (e, stackTrace) {
      logger.log(
        'Error canceling sleep timer',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> setSleepTimerEndOfSong() async {
    await setSleepTimerSongCount(1);
  }

  Future<void> setSleepTimerSongCount(int songCount) async {
    try {
      _sleepTimer?.cancel();
      sleepTimerExpired = false;
      sleepTimerEndOfSong = songCount <= 1;
      _sleepTimerRemainingSongs = songCount;
      sleepTimerNotifier.value = Duration(milliseconds: -songCount);
    } catch (e, stackTrace) {
      logger.log(
        'Error setting sleep timer song count',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    try {
      switch (name) {
        case 'clearQueue':
          clearQueue();
          break;
        case 'addToQueue':
          if (extras?['song'] != null) {
            await addToQueue(
              extras!['song'] as Map,
              playNext: extras['playNext'] ?? false,
            );
          }
          break;
        case 'removeFromQueue':
          if (extras?['index'] != null) {
            await removeFromQueue(extras!['index'] as int);
          }
          break;
        case 'reorderQueue':
          if (extras?['oldIndex'] != null && extras?['newIndex'] != null) {
            await reorderQueue(
              extras!['oldIndex'] as int,
              extras['newIndex'] as int,
            );
          }
          break;
        default:
          await super.customAction(name, extras);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in customAction: $name',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

class _PlaybackSource {
  const _PlaybackSource({required this.songUrl, required this.isOffline});

  final String songUrl;
  final bool isOffline;
}
