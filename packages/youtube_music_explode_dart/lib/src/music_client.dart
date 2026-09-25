import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_music_explode_dart/src/models/home_section.dart';

typedef _JsonMap = Map<String, dynamic>;

/// A canonical YouTube Music artist result.
class MusicArtist {
  const MusicArtist({required this.id, required this.name, this.thumbnailUrl});

  /// Canonical `UC...` artist channel id.
  final String id;

  /// Display name returned by YouTube Music.
  final String name;

  /// Artist avatar URL, when YouTube Music exposes one.
  final String? thumbnailUrl;
}

/// Kind of a release listed on a YouTube Music artist page.
enum MusicReleaseType { album, single, ep, other }

/// A release (album, single or EP) as listed on a YouTube Music artist page.
class MusicAlbum {
  const MusicAlbum(
    this.id,
    this.title, {
    this.thumbnailUrl,
    this.type = MusicReleaseType.other,
    this.year,
  });

  /// Browse id of the release, e.g. `MPREb_...`.
  final String id;

  /// Display title of the release.
  final String title;

  /// Release artwork URL, when YouTube Music exposes one.
  final String? thumbnailUrl;

  /// Whether YouTube Music lists this release as a single or an EP. Album
  /// shelves only label their entries in the full grid, so an unlabelled
  /// release is [MusicReleaseType.other].
  final MusicReleaseType type;

  /// Release year, when YouTube Music exposes one.
  final String? year;

  @override
  String toString() => 'MusicAlbum($id, $title)';
}

/// A YouTube Music release page: the release itself plus its tracks.
class MusicReleasePage {
  const MusicReleasePage({
    required this.id,
    required this.title,
    this.artist,
    this.artistId,
    this.thumbnailUrl,
    this.year,
    this.tracks = const [],
  });

  /// Browse id of the release, e.g. `MPREb_...`.
  final String id;

  /// Display title of the release.
  final String title;

  /// Artist credited for the release, when YouTube Music exposes one.
  final String? artist;

  /// Channel id of that artist, when its name links to its page.
  final String? artistId;

  /// Release artwork URL, when YouTube Music exposes one.
  final String? thumbnailUrl;

  /// Release year, when YouTube Music exposes one.
  final String? year;

  /// The tracks of the release, in order.
  final List<Video> tracks;
}

/// A YouTube Music playlist page: the playlist metadata plus its tracks.
class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.title,
    this.author,
    this.authorId,
    this.thumbnailUrl,
    this.year,
    this.tracks = const [],
  });

  /// Browse id of the playlist, e.g. `VLPL...` or `PL...`.
  final String id;

  /// Display title of the playlist.
  final String title;

  /// Artist or curator credited for the playlist (e.g. "Sony Music India", "YouTube Music").
  final String? author;

  /// Channel id of that curator, when YouTube Music exposes one.
  final String? authorId;

  /// Playlist artwork URL, when YouTube Music exposes one.
  final String? thumbnailUrl;

  /// Playlist subtitle/year, when YouTube Music exposes one.
  final String? year;

  /// The tracks of the playlist, in order.
  final List<Video> tracks;
}

/// The result of a YouTube Music radio / automix query with tracks and continuation token.
class MusicRadioResult {
  const MusicRadioResult({required this.tracks, this.continuation});

  /// The list of tracks in this radio batch.
  final List<Video> tracks;

  /// Continuation token for the next page of radio tracks, if available.
  final String? continuation;
}

/// A track of the artist page "Top songs" shelf.
class MusicTopSong {
  const MusicTopSong(this.video, this.playCount);

  /// The track itself.
  final Video video;

  /// Play count as displayed by YouTube Music, e.g. `1.2B plays`, when the
  /// shelf lists one.
  final String? playCount;
}

/// A YouTube Music artist page.
class MusicArtistProfile {
  const MusicArtistProfile({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.description,
    this.monthlyListeners,
    this.topSongs = const [],
    this.releases = const [],
    this.relatedArtists = const [],
  });

  /// Canonical `UC...` artist channel id, not necessarily the one the page was
  /// asked for: see [MusicClient.getArtistProfile].
  final String id;

  /// Display name returned by YouTube Music.
  final String name;

  /// Header artwork URL, when YouTube Music exposes one.
  final String? thumbnailUrl;

  /// Artist biography, when YouTube Music exposes one.
  final String? description;

  /// Monthly listeners as displayed by YouTube Music, e.g.
  /// `331M monthly audience`.
  final String? monthlyListeners;

  /// The tracks of the artist page "Top songs" shelf.
  final List<MusicTopSong> topSongs;

  /// Every release of the artist: albums, singles and EPs.
  final List<MusicAlbum> releases;

  /// Artists the "Fans might also like" shelf points to.
  final List<MusicArtist> relatedArtists;
}

/// Queries the YouTube Music (`WEB_REMIX`) browse endpoints.
class MusicClient {
  /// Initializes an instance of [MusicClient].
  const MusicClient(this._httpClient);

  final YoutubeHttpClient _httpClient;

  static const _remixContext = {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240101.01.00',
      'hl': 'en',
    },
  };

  /// Search filter that restricts results to artists only.
  static const _artistsSearchParams = 'EgWKAQIgAWoMEA4QChADEAQQCRAF';

  /// Search filter for the dedicated "Songs" shelf.
  static const _songsSearchParams = 'EgWKAQIIAWoMEA4QChADEAQQCRAF';

  /// Search filter for the dedicated "Albums" shelf.
  static const _albumsSearchParams = 'EgWKAQIYAWoMEA4QChADEAQQCRAF';

  /// Search filter for the dedicated "Playlists" shelf.
  static const _playlistsSearchParams = 'EgWKAQIoAWoMEA4QChADEAQQCRAF';

  /// Search filter for the dedicated "Videos" shelf.
  static const _videosSearchParams = 'EgWKAQIQAWoMEA4QChADEAQQCRAF';

  static const _artistPageType = 'MUSIC_PAGE_TYPE_ARTIST';

  /// Stands in for the channel of a track whose artist page is unknown.
  static const _unknownChannelId = 'UC0000000000000000000000';

  /// Matches the play count of a top song, e.g. `1.2B plays`. The client asks
  /// for `hl: en`, so the wording is stable.
  static final _playCountPattern = RegExp(
    r'^[\d.,]+\s?[KMB]?\s+plays$',
    caseSensitive: false,
  );

  /// Searches YouTube Music for canonical artist entries matching [query].
  Future<List<MusicArtist>> searchArtists(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final root = await _httpClient.sendPost('search', {
      'context': _remixContext,
      'query': normalizedQuery,
      'params': _artistsSearchParams,
    });

    final results = <MusicArtist>[];
    final seen = <String>{};
    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final endpoint = item
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint');
      final id = endpoint?.getValue<String>('browseId');
      if (id == null || !id.startsWith('UC') || !seen.add(id)) continue;

      final pageType = endpoint
          ?.getMap('browseEndpointContextSupportedConfigs')
          ?.getMap('browseEndpointContextMusicConfig')
          ?.getValue<String>('pageType');
      if (pageType != _artistPageType) continue;

      final name = _flexColumnText(item, 0) ?? '';
      if (name.trim().isEmpty) continue;

      results.add(
        MusicArtist(
          id: id,
          name: name.trim(),
          thumbnailUrl: _thumbnailUrl(item, 'thumbnail'),
        ),
      );
    }
    return results;
  }

  /// Searches the YouTube Music "Songs" shelf for [query].
  ///
  /// When supplied, [expectedArtist] and [expectedTitle] must loosely match
  /// the result's credited artist and title. This prevents common-title
  /// searches from returning the wrong recording.
  Future<Video?> searchSong(
    String query, {
    String? expectedArtist,
    String? expectedTitle,
    Duration? expectedDuration,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return null;

    final root = await _httpClient.sendPost('search', {
      'context': _remixContext,
      'query': normalizedQuery,
      'params': _songsSearchParams,
    }, validate: true);

    final isValidating = expectedArtist != null || expectedTitle != null;
    Video? fallback;
    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _trackVideoId(item);
      if (videoId == null) continue;

      final title = _flexColumnText(item, 0);
      if (title == null || title.isEmpty) continue;

      final subtitleParts = _splitBullets(_flexColumnText(item, 1));
      final artist = subtitleParts.isNotEmpty ? subtitleParts.first : '';

      final video = _trackVideo(
        item,
        videoId,
        title,
        artist,
        null,
        subtitleParts: subtitleParts,
      );
      fallback ??= video;

      final artistMatches =
          expectedArtist == null || _looselyMatch(artist, expectedArtist);
      final titleMatches =
          expectedTitle == null || _looselyMatch(title, expectedTitle);

      if (artistMatches && titleMatches) {
        if (expectedDuration == null) {
          return video;
        }
        // A known duration is part of the recording identity. Do not return a
        // title/artist match when its duration disproves that identity.
        if (video.duration != null &&
            _matchesDuration(video.duration!, expectedDuration)) {
          return video;
        }
      }
    }

    return isValidating ? null : fallback;
  }

  /// Fetches an official track from YouTube Music by its [videoId].
  Future<Video?> getSong(String videoId) async {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return null;

    try {
      final root = await _httpClient.sendPost('next', {
        'context': _remixContext,
        'videoId': cleanId,
        'enablePersistentPlaylistPanel': true,
        'isAudioOnly': true,
      }, validate: true);

      for (final item in _findRenderers(root, 'playlistPanelVideoRenderer')) {
        final vId = item.getValue<String>('videoId');
        if (vId != cleanId) continue;

        final title = _runsText(item.getMap('title'))?.trim();
        if (title == null || title.isEmpty) continue;

        final bylineMap =
            item.getMap('longBylineText') ?? item.getMap('shortBylineText');
        final bylineText = _runsText(bylineMap)?.trim();
        final subtitleParts = _splitBullets(bylineText);
        final artist = subtitleParts.isNotEmpty
            ? subtitleParts.first
            : (bylineText ?? '');

        final lengthText = _runsText(item.getMap('lengthText'))?.trim();
        final duration = _parseDuration(lengthText);
        final thumbUrl = _playlistPanelThumbnailUrl(item);

        return Video(
          VideoId(cleanId),
          title,
          artist,
          ChannelId.fromString(_unknownChannelId),
          null,
          null,
          null,
          '',
          duration,
          ThumbnailSet(cleanId),
          null,
          const Engagement(0, null, null),
          false,
          [
            if (thumbUrl != null && thumbUrl.isNotEmpty)
              (
                song: title,
                artist: artist,
                album: null,
                image: Uri.tryParse(thumbUrl),
              ),
          ],
        );
      }
    } catch (_) {}

    return null;
  }

  /// Searches the YouTube Music "Songs" shelf for [query], returning official
  /// song tracks up to [limit].
  Future<List<Video>> searchSongs(String query, {int limit = 25}) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final root = await _httpClient.sendPost('search', {
      'context': _remixContext,
      'query': normalizedQuery,
      'params': _songsSearchParams,
    }, validate: true);

    final results = <Video>[];
    final seen = <String>{};

    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _trackVideoId(item);
      if (videoId == null || !seen.add(videoId)) continue;

      final title = _flexColumnText(item, 0);
      if (title == null || title.isEmpty) continue;

      final subtitleParts = _splitBullets(_flexColumnText(item, 1));
      final artist = subtitleParts.isNotEmpty ? subtitleParts.first : '';

      final video = _trackVideo(
        item,
        videoId,
        title,
        artist,
        null,
        subtitleParts: subtitleParts,
      );

      // Skip short previews / ringtones (< 30s)
      if (video.duration != null &&
          video.duration!.inSeconds > 0 &&
          video.duration!.inSeconds < 30) {
        continue;
      }

      results.add(video);
      if (results.length >= limit) break;
    }

    return results;
  }

  /// Searches the YouTube Music "Videos" shelf for [query], returning music videos up to [limit].
  Future<List<Video>> searchVideos(String query, {int limit = 20}) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final root = await _httpClient.sendPost('search', {
      'context': _remixContext,
      'query': normalizedQuery,
      'params': _videosSearchParams,
    }, validate: true);

    final results = <Video>[];
    final seen = <String>{};

    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _trackVideoId(item);
      if (videoId == null || !seen.add(videoId)) continue;

      final title = _flexColumnText(item, 0);
      if (title == null || title.isEmpty) continue;

      final subtitleParts = _splitBullets(_flexColumnText(item, 1));
      final artist = subtitleParts.isNotEmpty ? subtitleParts.first : '';

      final video = _trackVideo(
        item,
        videoId,
        title,
        artist,
        null,
        subtitleParts: subtitleParts,
      );

      results.add(video);
      if (results.length >= limit) break;
    }

    return results;
  }

  /// Searches YouTube Music "Albums" shelf for [query], returning official
  /// albums up to [limit].
  Future<List<Map<String, dynamic>>> searchAlbums(
    String query, {
    int limit = 20,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final root = await _httpClient.sendPost('search', {
      'context': _remixContext,
      'query': normalizedQuery,
      'params': _albumsSearchParams,
    }, validate: true);

    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final browseId = item
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint')
          ?.getValue<String>('browseId');
      if (browseId == null ||
          !browseId.startsWith('MPREb_') ||
          !seen.add(browseId)) {
        continue;
      }

      final title = _flexColumnText(item, 0);
      if (title == null || title.isEmpty) continue;

      final subtitleParts = _splitBullets(_flexColumnText(item, 1));
      final artist = subtitleParts.length > 1
          ? subtitleParts[1]
          : (subtitleParts.isNotEmpty ? subtitleParts.first : '');
      final year = subtitleParts.isNotEmpty ? subtitleParts.last : null;
      final thumbUrl =
          _thumbnailUrl(item, 'thumbnail') ??
          _thumbnailUrl(item, 'thumbnailRenderer');

      results.add({
        'ytid': browseId,
        'title': title,
        'artist': artist,
        'year': year,
        'image': thumbUrl,
        'lowResImage': thumbUrl,
        'highResImage': thumbUrl,
        'isAlbum': true,
        'source': 'youtube-music-album',
        'list': [],
      });

      if (results.length >= limit) break;
    }

    return results;
  }

  /// Searches YouTube Music "Playlists" shelf for [query], returning curated & community
  /// playlists up to [limit].
  Future<List<Map<String, dynamic>>> searchPlaylists(
    String query, {
    int limit = 20,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final root = await _httpClient.sendPost('search', {
      'context': _remixContext,
      'query': normalizedQuery,
      'params': _playlistsSearchParams,
    }, validate: true);

    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      var browseId = item
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint')
          ?.getValue<String>('browseId');
      if (browseId == null) continue;
      if (browseId.startsWith('VL')) {
        browseId = browseId.substring(2);
      }
      if (!seen.add(browseId)) continue;

      final title = _flexColumnText(item, 0);
      if (title == null || title.isEmpty) continue;

      final lowerTitle = title.toLowerCase();
      if (lowerTitle.contains('whatsapp status') ||
          lowerTitle.contains('ringtone') ||
          lowerTitle.contains('status video') ||
          lowerTitle.contains('reels status') ||
          lowerTitle.contains('video song') ||
          lowerTitle.contains('1080p') ||
          lowerTitle.contains('4k video') ||
          lowerTitle.contains('trailer') ||
          lowerTitle.contains('teaser') ||
          lowerTitle.contains('mashup') ||
          lowerTitle.contains('bgm status')) {
        continue;
      }

      final subtitleParts = _splitBullets(_flexColumnText(item, 1));
      final author = subtitleParts.isNotEmpty ? subtitleParts.first : '';
      final thumbUrl =
          _thumbnailUrl(item, 'thumbnail') ??
          _thumbnailUrl(item, 'thumbnailRenderer');

      results.add({
        'ytid': browseId,
        'title': title,
        'author': author,
        'image': thumbUrl,
        'lowResImage': thumbUrl,
        'highResImage': thumbUrl,
        'isAlbum': false,
        'source': 'youtube-music-playlist',
        'list': [],
      });

      if (results.length >= limit) break;
    }

    return results;
  }

  /// Searches YouTube Music suggestions for [query], returning clean music-oriented query suggestions.
  Future<List<String>> getSearchSuggestions(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final root = await _httpClient.sendPost('music/get_search_suggestions', {
      'context': _remixContext,
      'input': normalizedQuery,
    }, validate: true);

    final suggestions = <String>[];
    final seen = <String>{};

    for (final item in _findRenderers(root, 'searchSuggestionRenderer')) {
      final text = _runsText(item.getMap('suggestion'))?.trim();
      if (text != null && text.isNotEmpty && seen.add(text.toLowerCase())) {
        suggestions.add(text);
      }
    }

    for (final item in _findRenderers(root, 'historySuggestionRenderer')) {
      final text = _runsText(item.getMap('suggestion'))?.trim();
      if (text != null && text.isNotEmpty && seen.add(text.toLowerCase())) {
        suggestions.add(text);
      }
    }

    return suggestions;
  }

  /// Fetches YouTube Music radio / automix tracks supporting seed videoId, playlistId,
  /// or continuation tokens for infinite pagination.
  Future<MusicRadioResult> getRadioTracks({
    String? videoId,
    String? playlistId,
    String? continuation,
    int limit = 25,
  }) async {
    final cleanVideoId = videoId?.trim();
    final cleanPlaylistId = playlistId?.trim();
    final cleanContinuation = continuation?.trim();

    if ((cleanVideoId == null || cleanVideoId.isEmpty) &&
        (cleanPlaylistId == null || cleanPlaylistId.isEmpty) &&
        (cleanContinuation == null || cleanContinuation.isEmpty)) {
      return const MusicRadioResult(tracks: []);
    }

    final Map<String, dynamic> body;
    if (cleanContinuation != null && cleanContinuation.isNotEmpty) {
      body = {
        'context': _remixContext,
        'continuation': cleanContinuation,
        'isAudioOnly': true,
      };
    } else {
      final resolvedPlaylistId =
          (cleanPlaylistId != null && cleanPlaylistId.isNotEmpty)
          ? cleanPlaylistId
          : (cleanVideoId != null ? 'RDAMVM$cleanVideoId' : null);

      body = {
        'context': _remixContext,
        if (cleanVideoId != null && cleanVideoId.isNotEmpty)
          'videoId': cleanVideoId,
        if (resolvedPlaylistId != null) 'playlistId': resolvedPlaylistId,
        'enablePersistentPlaylistPanel': true,
        'isAudioOnly': true,
      };
    }

    final root = await _httpClient.sendPost('next', body, validate: true);

    final results = <Video>[];
    final seen = <String>{};

    for (final item in _findRenderers(root, 'playlistPanelVideoRenderer')) {
      final vId = item.getValue<String>('videoId');
      if (vId == null || vId.isEmpty || !seen.add(vId)) continue;
      // Skip the seed track itself if requested with videoId
      if (cleanVideoId != null && vId == cleanVideoId) continue;

      final title = _runsText(item.getMap('title'))?.trim();
      if (title == null || title.isEmpty) continue;

      final bylineMap =
          item.getMap('longBylineText') ?? item.getMap('shortBylineText');
      final bylineText = _runsText(bylineMap)?.trim();
      final subtitleParts = _splitBullets(bylineText);
      final artist = subtitleParts.isNotEmpty
          ? subtitleParts.first
          : (bylineText ?? '');

      final lengthText = _runsText(item.getMap('lengthText'))?.trim();
      final duration = _parseDuration(lengthText);

      // Skip preview clips / ringtones (< 30s)
      if (duration != null &&
          duration.inSeconds > 0 &&
          duration.inSeconds < 30) {
        continue;
      }

      final thumbUrl = _playlistPanelThumbnailUrl(item);

      final video = Video(
        VideoId(vId),
        title,
        artist,
        ChannelId.fromString(_unknownChannelId),
        null,
        null,
        null,
        '',
        duration,
        ThumbnailSet(vId),
        null,
        const Engagement(0, null, null),
        false,
        [
          if (thumbUrl != null && thumbUrl.isNotEmpty)
            (
              song: title,
              artist: artist,
              album: null,
              image: Uri.tryParse(thumbUrl),
            ),
        ],
      );

      results.add(video);
      if (results.length >= limit) break;
    }

    final nextContinuation = _extractWatchContinuationToken(root);

    return MusicRadioResult(tracks: results, continuation: nextContinuation);
  }

  /// Extracts watch next continuation token from InnerTube response.
  String? _extractWatchContinuationToken(Map<String, dynamic> root) {
    // 1. Look for continuationItemRenderer in playlist panel or anywhere in tree
    for (final item in _findRenderers(root, 'continuationItemRenderer')) {
      final token = item
          .getMap('continuationEndpoint')
          ?.getMap('continuationCommand')
          ?.getValue<String>('token');
      if (token != null && token.isNotEmpty) return token;
    }
    // 2. Look for nextContinuationData in continuations
    for (final item in _findRenderers(root, 'nextContinuationData')) {
      final token = item.getValue<String>('continuation');
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  /// Fetches YouTube Music "Up Next" / Automix radio tracks for [videoId].
  ///
  /// Uses YouTube Music's dedicated `RDAMVM<videoId>` automix queue endpoint to
  /// deliver official related tracks, avoiding generic video clips and fan re-uploads.
  Future<List<Video>> getRadioSongs(String videoId, {int limit = 25}) async {
    final result = await getRadioTracks(videoId: videoId, limit: limit);
    return result.tracks;
  }

  bool _matchesDuration(Duration actual, Duration expected) {
    final diff = (actual.inSeconds - expected.inSeconds).abs();
    if (diff <= 12) return true;
    if (expected.inSeconds > 0) {
      final ratio = actual.inSeconds / expected.inSeconds;
      return ratio >= 0.82 && ratio <= 1.20;
    }
    return true;
  }

  /// Splits a `Song • Artist • Album` style subtitle line on its bullet
  /// separators.
  List<String> _splitBullets(String? text) {
    if (text == null) return const [];
    return text
        .split('•')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  /// Compares normalized word sets, allowing word-order and credit changes.
  bool _looselyMatch(String candidate, String expected) {
    final a = _wordsForMatch(candidate);
    final b = _wordsForMatch(expected);
    if (a.isEmpty || b.isEmpty) return true;
    // Expected words must all be present in the candidate. This permits
    // featured-artist/remix suffixes but rejects partial matches such as
    // "Taylor" for the expected artist "Taylor Swift".
    return b.every(a.contains);
  }

  Set<String> _wordsForMatch(String input) =>
      _foldDiacritics(input.toLowerCase())
          // Keep Unicode letters and numbers so non-Latin titles remain
          // matchable.
          .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toSet();

  /// Folds common Latin accents to improve matching across spellings.
  String _foldDiacritics(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_diacriticFold[char] ?? char);
    }
    return buffer.toString();
  }

  static const _diacriticFold = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ç': 'c',
    'ñ': 'n',
  };

  /// Returns a YouTube Music artist page: header details, top songs, the full
  /// discography and the artists it points to.
  ///
  /// [channelId] does not have to be the channel of the artist itself: the
  /// channel that uploads its videos — a label, a VEVO channel — answers with
  /// a partial page of the same artist, whose header still points at the
  /// canonical channel. [MusicArtistProfile.id] holds that one, so a caller
  /// that asked with an uploader can tell and read the real page instead.
  Future<MusicArtistProfile> getArtistProfile(dynamic channelId) async {
    final id = ChannelId.fromString(channelId).value;
    final root = await _browse(id);

    final header =
        _firstRenderer(root, 'musicImmersiveHeaderRenderer') ??
        _firstRenderer(root, 'musicVisualHeaderRenderer');
    final name = (_runsText(header?.getMap('title')) ?? '').trim();
    final canonicalId = _headerChannelId(header) ?? id;

    return MusicArtistProfile(
      id: canonicalId,
      name: name,
      thumbnailUrl: _thumbnailUrl(header, 'thumbnail'),
      description: _runsText(header?.getMap('description')),
      monthlyListeners: _runsText(header?.getMap('monthlyListenerCount')),
      topSongs: _parseTopSongs(root, channelId: canonicalId, author: name),
      releases: await _collectDiscography(root),
      relatedArtists: _collectRelatedArtists(
        root,
      ).where((artist) => artist.id != canonicalId).toList(),
    );
  }

  /// Channel the subscribe button of a page header subscribes to, which is the
  /// artist itself even on the page of a channel that only uploads for it.
  String? _headerChannelId(_JsonMap? header) {
    final channelId = header
        ?.getMap('subscriptionButton')
        ?.getMap('subscribeButtonRenderer')
        ?.getValue<String>('channelId');
    return (channelId != null && channelId.startsWith('UC')) ? channelId : null;
  }

  /// Returns a release with its tracks, credited to the artist its own header
  /// names.
  Future<MusicReleasePage> getAlbum(String albumBrowseId) async {
    final root = await _browse(albumBrowseId);
    final header =
        _firstRenderer(root, 'musicResponsiveHeaderRenderer') ??
        _firstRenderer(root, 'musicDetailHeaderRenderer');
    final albumArtist = _runsText(header?.getMap('straplineTextOne'))?.trim();
    final albumArtistId = _straplineChannelId(header);

    final videos = <Video>[];
    final seen = <String>{};
    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _trackVideoId(item);
      if (videoId == null || !seen.add(videoId)) continue;

      final title = _flexColumnText(item, 0);
      if (title == null || title.isEmpty) continue;

      videos.add(
        _trackVideo(item, videoId, title, albumArtist ?? '', albumArtistId),
      );
    }

    return MusicReleasePage(
      id: albumBrowseId,
      title: _runsText(header?.getMap('title'))?.trim() ?? '',
      artist: albumArtist,
      artistId: albumArtistId,
      thumbnailUrl: _thumbnailUrl(header, 'thumbnail'),
      year: _releaseYearOf(_subtitleParts(header)),
      tracks: videos,
    );
  }

  /// Returns a playlist with its tracks via YouTube Music.
  Future<MusicPlaylist> getPlaylist(String playlistId) async {
    final cleanId = playlistId.startsWith('VL')
        ? playlistId.substring(2)
        : playlistId;
    if (cleanId.startsWith('MPREb_')) {
      final album = await getAlbum(cleanId);
      return MusicPlaylist(
        id: album.id,
        title: album.title,
        author: album.artist,
        authorId: album.artistId,
        thumbnailUrl: album.thumbnailUrl,
        year: album.year,
        tracks: album.tracks,
      );
    }

    final browseId = 'VL$cleanId';
    final root = await _browse(browseId);
    final header =
        _firstRenderer(root, 'musicResponsiveHeaderRenderer') ??
        _firstRenderer(root, 'musicDetailHeaderRenderer') ??
        _firstRenderer(root, 'musicEditablePlaylistDetailHeaderRenderer');

    final rawPlaylistAuthor =
        _runsText(header?.getMap('straplineTextOne'))?.trim() ??
        _runsText(header?.getMap('subtitle'))?.trim();
    final playlistAuthor = _sanitizeCurator(rawPlaylistAuthor);
    final playlistAuthorId = _straplineChannelId(header);
    final playlistTitle = _runsText(header?.getMap('title'))?.trim() ?? '';
    final thumbUrl =
        _thumbnailUrl(header, 'thumbnail') ??
        _thumbnailUrl(header, 'thumbnailRenderer');

    final videos = <Video>[];
    final seen = <String>{};

    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _trackVideoId(item);
      if (videoId == null || !seen.add(videoId)) continue;

      final title = _flexColumnText(item, 0);
      if (title == null || title.isEmpty) continue;

      final trackAuthor = _flexColumnText(item, 1);
      final subtitleParts = _splitBullets(trackAuthor);
      final author = (trackAuthor != null && trackAuthor.isNotEmpty)
          ? trackAuthor
          : (playlistAuthor ?? '');

      videos.add(
        _trackVideo(
          item,
          videoId,
          title,
          author,
          null,
          subtitleParts: subtitleParts,
        ),
      );
    }

    return MusicPlaylist(
      id: cleanId,
      title: playlistTitle,
      author: playlistAuthor,
      authorId: playlistAuthorId,
      thumbnailUrl: thumbUrl,
      year: _releaseYearOf(_subtitleParts(header)),
      tracks: videos,
    );
  }

  /// Channel id behind the artist name of a release header, when it links to
  /// the page of that artist.
  String? _straplineChannelId(_JsonMap? header) {
    final runs = header?.getMap('straplineTextOne')?.getList('runs');
    for (final run in runs?.whereType<Map>() ?? const <Map>[]) {
      final browseId = run
          .cast<String, dynamic>()
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint')
          ?.getValue<String>('browseId');
      if (browseId != null && browseId.startsWith('UC')) return browseId;
    }
    return null;
  }

  Future<_JsonMap> _browse(String browseId, {String? params}) {
    return _httpClient.sendPost('browse', {
      'context': _remixContext,
      'browseId': browseId,
      if (params != null) 'params': params,
    });
  }

  /// Direct browse call to InnerTube with customizable [hl] (language) and [gl] (region),
  /// supporting continuation tokens and visitor data.
  Future<_JsonMap> browseEndpoint(
    String? browseId, {
    String? continuation,
    String? visitorData,
    String? params,
    String hl = 'en',
    String? gl,
  }) {
    final clientMap = <String, dynamic>{
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240101.01.00',
      'hl': hl,
      if (gl != null) 'gl': gl,
      if (visitorData != null) 'visitorData': visitorData,
    };

    final body = <String, dynamic>{
      'context': {'client': clientMap},
      if (browseId != null) 'browseId': browseId,
      if (continuation != null) 'continuation': continuation,
      if (params != null) 'params': params,
    };

    final headers = <String, String>{
      if (visitorData != null) 'X-Goog-Visitor-Id': visitorData,
    };

    return _httpClient.sendPost(
      'browse',
      body,
      headers: headers.isNotEmpty ? headers : null,
      validate: true,
    );
  }

  /// Fetches curated playlists from the YouTube Music home feed (e.g. FEmusic_home).
  Future<List<Map<String, dynamic>>> getHomePlaylists({
    String hl = 'en',
    String gl = 'IN',
    int limit = 20,
  }) async {
    try {
      final root = await browseEndpoint('FEmusic_home', hl: hl, gl: gl);
      final results = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final shelf in _findRenderers(root, 'musicCarouselShelfRenderer')) {
        final contents = shelf.getList('contents') ?? const [];
        for (final c in contents) {
          if (c is! Map) continue;
          final item = c.cast<String, dynamic>().getMap(
            'musicTwoRowItemRenderer',
          );
          if (item == null) continue;

          final browseEndpoint = item
              .getMap('navigationEndpoint')
              ?.getMap('browseEndpoint');
          final browseId = browseEndpoint?.getValue<String>('browseId');
          if (browseId == null || browseId.isEmpty) continue;

          final pageType = browseEndpoint
              ?.getMap('browseEndpointContextSupportedConfigs')
              ?.getMap('browseEndpointContextMusicConfig')
              ?.getValue<String>('pageType');

          // Ensure it is a playlist or radio mix
          if (pageType == 'MUSIC_PAGE_TYPE_PLAYLIST' ||
              browseId.startsWith('VL') ||
              browseId.startsWith('RDCLAK')) {
            final cleanId = browseId.startsWith('VL')
                ? browseId.substring(2)
                : browseId;
            if (!seen.add(cleanId)) continue;

            final title = _runsText(item.getMap('title')) ?? '';
            final subtitle = _sanitizeCurator(
              _runsText(item.getMap('subtitle')),
            )!;
            final thumbUrl = _thumbnailUrl(item, 'thumbnailRenderer');

            results.add({
              'ytid': cleanId,
              'title': title,
              'artist': subtitle,
              'image': thumbUrl,
              'lowResImage': thumbUrl,
              'highResImage': thumbUrl,
              'source': 'youtube-music-playlist',
              'pageType': pageType,
            });
            if (results.length >= limit) return results;
          }
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Fetches rich, dynamic shelves from the YouTube Music home feed (FEmusic_home).
  ///
  /// Parity with ytmusicapi: extracts section list shelves, follows continuations
  /// up to [maxShelves], and parses mixed songs/albums/artists/playlists without title-based assumptions.
  Future<List<HomeSection>> getHomeFeed({
    String hl = 'en',
    String? gl,
    int maxShelves = 16,
  }) async {
    try {
      final root = await browseEndpoint('FEmusic_home', hl: hl, gl: gl);
      final shelves = <HomeSection>[];

      _parseSectionList(root, shelves, maxShelves);

      final visitorData = root
          .getMap('responseContext')
          ?.getValue<String>('visitorData');
      var continuationToken = _extractContinuationToken(root);
      final seenTokens = <String>{};
      if (continuationToken != null) {
        seenTokens.add(continuationToken);
      }

      while (continuationToken != null &&
          continuationToken.isNotEmpty &&
          shelves.length < maxShelves) {
        try {
          final contRoot = await browseEndpoint(
            null,
            continuation: continuationToken,
            visitorData: visitorData,
            hl: hl,
            gl: gl,
          );

          final countBefore = shelves.length;
          _parseContinuationSectionList(contRoot, shelves, maxShelves);
          final addedInThisStep = shelves.length - countBefore;

          if (addedInThisStep == 0) {
            break;
          }

          final nextToken = _extractContinuationToken(contRoot);
          if (nextToken == null ||
              nextToken.isEmpty ||
              !seenTokens.add(nextToken)) {
            break;
          }
          continuationToken = nextToken;
        } catch (_) {
          break;
        }
      }

      return shelves;
    } catch (_) {
      return [];
    }
  }

  void _parseSectionList(
    Map<String, dynamic> root,
    List<HomeSection> shelves,
    int maxShelves,
  ) {
    final tabs = root
        .getMap('contents')
        ?.getMap('singleColumnBrowseResultsRenderer')
        ?.getList('tabs');
    final firstTab = (tabs != null && tabs.isNotEmpty && tabs.first is Map)
        ? (tabs.first as Map).cast<String, dynamic>()
        : null;
    final secList = firstTab
        ?.getMap('tabRenderer')
        ?.getMap('content')
        ?.getMap('sectionListRenderer');
    final sectionContents = secList?.getList('contents') ?? const [];

    for (final entry in sectionContents) {
      if (entry is! Map) continue;
      final entryMap = entry.cast<String, dynamic>();
      final rendererKey = entryMap.keys.firstOrNull;
      if (rendererKey == null) continue;
      final shelfRenderer = entryMap.getMap(rendererKey);
      if (shelfRenderer == null) continue;

      if (rendererKey == 'musicCarouselShelfRenderer' ||
          rendererKey == 'musicShelfRenderer' ||
          rendererKey == 'musicCardShelfRenderer' ||
          rendererKey == 'musicDescriptionShelfRenderer') {
        final parsed = _parseHomeShelf(shelfRenderer, rendererKey: rendererKey);
        if (parsed != null && parsed.isNotEmpty) {
          shelves.add(parsed);
          if (shelves.length >= maxShelves) break;
        }
      } else if (rendererKey == 'continuationItemRenderer') {
        // Handled by _extractContinuationToken
      }
    }
  }

  void _parseContinuationSectionList(
    Map<String, dynamic> contRoot,
    List<HomeSection> shelves,
    int maxShelves,
  ) {
    final secCont = contRoot
        .getMap('continuationContents')
        ?.getMap('sectionListContinuation');
    final sectionContents = secCont?.getList('contents') ?? const [];

    for (final entry in sectionContents) {
      if (entry is! Map) continue;
      final entryMap = entry.cast<String, dynamic>();
      final rendererKey = entryMap.keys.firstOrNull;
      if (rendererKey == null) continue;
      final shelfRenderer = entryMap.getMap(rendererKey);
      if (shelfRenderer == null) continue;

      if (rendererKey == 'musicCarouselShelfRenderer' ||
          rendererKey == 'musicShelfRenderer' ||
          rendererKey == 'musicCardShelfRenderer' ||
          rendererKey == 'musicDescriptionShelfRenderer') {
        final parsed = _parseHomeShelf(shelfRenderer, rendererKey: rendererKey);
        if (parsed != null && parsed.isNotEmpty) {
          shelves.add(parsed);
          if (shelves.length >= maxShelves) break;
        }
      } else if (rendererKey == 'continuationItemRenderer') {
        // Handled by _extractContinuationToken
      }
    }
  }

  String? _extractContinuationToken(Map<String, dynamic> root) {
    // 1. Check continuationContents.sectionListContinuation
    final contContents = root.getMap('continuationContents');
    if (contContents != null) {
      final secCont = contContents.getMap('sectionListContinuation');
      if (secCont != null) {
        final continuations = secCont.getList('continuations');
        if (continuations != null && continuations.isNotEmpty) {
          final first = continuations.first;
          if (first is Map) {
            final token = first
                .cast<String, dynamic>()
                .getMap('nextContinuationData')
                ?.getValue<String>('continuation');
            if (token != null && token.isNotEmpty) return token;
          }
        }
        final contents = secCont.getList('contents');
        if (contents != null) {
          for (final item in contents) {
            if (item is Map) {
              final cRenderer = item.cast<String, dynamic>().getMap(
                'continuationItemRenderer',
              );
              final token = cRenderer
                  ?.getMap('continuationEndpoint')
                  ?.getMap('continuationCommand')
                  ?.getValue<String>('token');
              if (token != null && token.isNotEmpty) return token;
            }
          }
        }
      }
    }

    // 2. Check initial browse contents
    final tabs = root
        .getMap('contents')
        ?.getMap('singleColumnBrowseResultsRenderer')
        ?.getList('tabs');
    if (tabs != null && tabs.isNotEmpty) {
      final firstTab = tabs.first;
      if (firstTab is Map) {
        final secList = firstTab
            .cast<String, dynamic>()
            .getMap('tabRenderer')
            ?.getMap('content')
            ?.getMap('sectionListRenderer');
        if (secList != null) {
          final continuations = secList.getList('continuations');
          if (continuations != null && continuations.isNotEmpty) {
            final first = continuations.first;
            if (first is Map) {
              final token = first
                  .cast<String, dynamic>()
                  .getMap('nextContinuationData')
                  ?.getValue<String>('continuation');
              if (token != null && token.isNotEmpty) return token;
            }
          }
          final contents = secList.getList('contents');
          if (contents != null) {
            for (final item in contents) {
              if (item is Map) {
                final cRenderer = item.cast<String, dynamic>().getMap(
                  'continuationItemRenderer',
                );
                final token = cRenderer
                    ?.getMap('continuationEndpoint')
                    ?.getMap('continuationCommand')
                    ?.getValue<String>('token');
                if (token != null && token.isNotEmpty) return token;
              }
            }
          }
        }
      }
    }

    return null;
  }

  HomeSection? _parseHomeShelf(
    Map<String, dynamic> shelf, {
    String rendererKey = 'musicCarouselShelfRenderer',
  }) {
    try {
      final header = shelf.getMap('header');
      final basicHeader =
          header?.getMap('musicCarouselShelfBasicHeaderRenderer') ??
          header?.getMap('musicCardShelfHeaderBasicRenderer');

      final title =
          _runsText(basicHeader?.getMap('title'))?.trim() ??
          _runsText(basicHeader?.getMap('strapline'))?.trim() ??
          _runsText(shelf.getMap('title'))?.trim() ??
          '';
      if (title.isEmpty) return null;

      final subtitle = _runsText(basicHeader?.getMap('strapline'))?.trim();
      final rawContents =
          shelf.getList('contents') ?? shelf.getList('items') ?? const [];
      if (rawContents.isEmpty) return null;

      // Extract shelf browse navigation if present
      final titleNav = basicHeader
          ?.getMap('title')
          ?.getList('runs')
          ?.firstOrNull;
      final browseEp = (titleNav is Map)
          ? titleNav
                .cast<String, dynamic>()
                .getMap('navigationEndpoint')
                ?.getMap('browseEndpoint')
          : null;
      final shelfBrowseId = browseEp?.getValue<String>('browseId');
      final shelfParams = browseEp?.getValue<String>('params');

      final items = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      var songCount = 0;
      var videoCount = 0;
      var albumCount = 0;
      var artistCount = 0;
      var playlistCount = 0;
      var hasResponsiveListItems = false;

      for (final c in rawContents) {
        if (c is! Map) continue;
        final cMap = c.cast<String, dynamic>();

        // 1. Song or video from musicResponsiveListItemRenderer
        final responsiveItem = cMap.getMap('musicResponsiveListItemRenderer');
        if (responsiveItem != null) {
          final song = _parseHomeSong(responsiveItem);
          if (song != null) {
            final ytid = song['ytid']?.toString();
            if (ytid != null && seenIds.add(ytid)) {
              items.add(song);
              if (song['contentType'] == 'video') {
                videoCount++;
              } else {
                songCount++;
              }
              hasResponsiveListItems = true;
            }
          }
          continue;
        }

        // 2. Card from musicTwoRowItemRenderer
        final twoRowItem = cMap.getMap('musicTwoRowItemRenderer');
        if (twoRowItem != null) {
          final nav = twoRowItem.getMap('navigationEndpoint');
          final browseEndpoint = nav?.getMap('browseEndpoint');
          final watchEndpoint = nav?.getMap('watchEndpoint');

          if (watchEndpoint != null && browseEndpoint == null) {
            final song = _parseHomeSong(twoRowItem);
            if (song != null) {
              final ytid = song['ytid']?.toString();
              if (ytid != null && seenIds.add(ytid)) {
                items.add(song);
                if (song['contentType'] == 'video') {
                  videoCount++;
                } else {
                  songCount++;
                }
              }
            }
            continue;
          }

          if (browseEndpoint != null) {
            final browseId = browseEndpoint.getValue<String>('browseId') ?? '';
            final pageType = browseEndpoint
                .getMap('browseEndpointContextSupportedConfigs')
                ?.getMap('browseEndpointContextMusicConfig')
                ?.getValue<String>('pageType');

            final isArtist =
                pageType == 'MUSIC_PAGE_TYPE_ARTIST' ||
                pageType == 'MUSIC_PAGE_TYPE_USER_CHANNEL' ||
                browseId.startsWith('UC');
            final subtitleStr =
                _runsText(
                  twoRowItem.getMap('subtitle'),
                )?.trim().toLowerCase() ??
                '';
            final isAlbum =
                pageType == 'MUSIC_PAGE_TYPE_ALBUM' ||
                pageType == 'MUSIC_PAGE_TYPE_AUDIOBOOK' ||
                browseId.startsWith('MPREb_') ||
                subtitleStr.contains('album') ||
                subtitleStr.contains('single') ||
                subtitleStr.contains('ep');

            if (isArtist) {
              final artist = _parseHomeArtist(twoRowItem);
              if (artist != null) {
                final ytid = artist['ytid']?.toString();
                if (ytid != null && seenIds.add(ytid)) {
                  items.add(artist);
                  artistCount++;
                }
              }
            } else if (isAlbum) {
              final album = _parseHomeAlbum(twoRowItem, title);
              if (album != null) {
                final ytid = album['ytid']?.toString();
                if (ytid != null && seenIds.add(ytid)) {
                  items.add(album);
                  albumCount++;
                }
              }
            } else {
              final playlist = _parseHomePlaylist(twoRowItem);
              if (playlist != null) {
                final ytid = playlist['ytid']?.toString();
                if (ytid != null && seenIds.add(ytid)) {
                  items.add(playlist);
                  playlistCount++;
                }
              }
            }
          }
        }
      }

      if (items.isEmpty) return null;

      final HomeContentType type;
      if (songCount > 0 &&
          albumCount == 0 &&
          artistCount == 0 &&
          playlistCount == 0 &&
          videoCount == 0) {
        type = HomeContentType.songs;
      } else if (albumCount > 0 &&
          songCount == 0 &&
          artistCount == 0 &&
          playlistCount == 0 &&
          videoCount == 0) {
        type = HomeContentType.albums;
      } else if (artistCount > 0 &&
          songCount == 0 &&
          albumCount == 0 &&
          playlistCount == 0 &&
          videoCount == 0) {
        type = HomeContentType.artists;
      } else if (playlistCount > 0 &&
          songCount == 0 &&
          albumCount == 0 &&
          artistCount == 0 &&
          videoCount == 0) {
        type = HomeContentType.playlists;
      } else {
        type = HomeContentType.mixed;
      }

      final titleLower = title.toLowerCase();
      final isChunkedSongs =
          (type == HomeContentType.songs || songCount >= (items.length / 2)) &&
          (hasResponsiveListItems ||
              titleLower.contains('quick picks') ||
              titleLower.contains('listen again') ||
              items.length >= 8);

      return HomeSection(
        title: title,
        subtitle: subtitle,
        type: type,
        contents: items,
        isChunkedSongs: isChunkedSongs,
        browseId: shelfBrowseId,
        params: shelfParams,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, String?> _thumbnailUrls(_JsonMap? node, String key) {
    if (node == null)
      return const {'image': null, 'lowResImage': null, 'highResImage': null};

    final target = node.getMap(key);
    final candidates = [
      target
          ?.getMap('musicThumbnailRenderer')
          ?.getMap('thumbnail')
          ?.getList('thumbnails'),
      target
          ?.getMap('croppedSquareThumbnailRenderer')
          ?.getMap('thumbnail')
          ?.getList('thumbnails'),
      target?.getMap('thumbnail')?.getList('thumbnails'),
      target?.getList('thumbnails'),
      node
          .getMap('musicThumbnailRenderer')
          ?.getMap('thumbnail')
          ?.getList('thumbnails'),
      node
          .getMap('croppedSquareThumbnailRenderer')
          ?.getMap('thumbnail')
          ?.getList('thumbnails'),
      node.getMap('thumbnail')?.getList('thumbnails'),
      node.getList('thumbnails'),
    ];

    List<dynamic>? thumbnails;
    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) {
        thumbnails = candidate;
        break;
      }
    }

    if (thumbnails == null || thumbnails.isEmpty) {
      return const {'image': null, 'lowResImage': null, 'highResImage': null};
    }

    final parsed = <_ThumbCandidate>[];
    for (final item in thumbnails) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final url = map.getValue<String>('url');
      if (url == null || url.trim().isEmpty) continue;
      final w = map.getValue<int>('width') ?? 0;
      final h = map.getValue<int>('height') ?? 0;
      final dim = w > h ? w : h;
      parsed.add(_ThumbCandidate(url, dim));
    }

    if (parsed.isEmpty) {
      return const {'image': null, 'lowResImage': null, 'highResImage': null};
    }

    parsed.sort((a, b) => a.dim.compareTo(b.dim));

    final low = parsed.first.url;
    final high = parsed.last.url;
    final mid = parsed[parsed.length ~/ 2].url;

    return {'image': mid, 'lowResImage': low, 'highResImage': high};
  }

  List<_JsonMap>? _flexColumnRuns(_JsonMap item, int index) {
    final columns = item.getList('flexColumns');
    if (columns == null || columns.length <= index) return null;
    final column = columns[index];
    if (column is! Map) return null;
    final runs = column
        .cast<String, dynamic>()
        .getMap('musicResponsiveListItemFlexColumnRenderer')
        ?.getMap('text')
        ?.getList('runs');
    return runs
        ?.whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  _ParsedRuns _parseItemRuns(List<_JsonMap>? runs) {
    if (runs == null || runs.isEmpty) return const _ParsedRuns();

    final artists = <Map<String, dynamic>>[];
    String? artistId;
    String? albumName;
    String? albumId;
    String? views;
    String? year;
    Duration? duration;

    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];
      final text = run['text']?.toString().trim() ?? '';
      if (text.isEmpty ||
          text == '•' ||
          text == ',' ||
          text == '&' ||
          text == '/' ||
          text == '\u2022') {
        continue;
      }

      final browseEndpoint = run
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint');
      final browseId = browseEndpoint?.getValue<String>('browseId');

      if (browseId != null && browseId.isNotEmpty) {
        if (browseId.startsWith('MPRE') ||
            browseId.contains('release_detail')) {
          albumName = text;
          albumId = browseId;
        } else {
          artists.add({'name': text, 'id': browseId});
          artistId ??= browseId;
        }
      } else {
        if (RegExp(r'^(\d+:)*\d+:\d+$').hasMatch(text)) {
          final parts = text.split(':');
          if (parts.length == 2) {
            final m = int.tryParse(parts[0]) ?? 0;
            final s = int.tryParse(parts[1]) ?? 0;
            duration = Duration(minutes: m, seconds: s);
          } else if (parts.length == 3) {
            final h = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            final s = int.tryParse(parts[2]) ?? 0;
            duration = Duration(hours: h, minutes: m, seconds: s);
          }
        } else if (RegExp(r'^\d{4}$').hasMatch(text)) {
          year = text;
        } else if (RegExp(
              r'\d+.*(play|view|stream)',
              caseSensitive: false,
            ).hasMatch(text) ||
            RegExp(
              r'^\d+(\.\d+)?[KMB]?\s*(plays|views)?$',
              caseSensitive: false,
            ).hasMatch(text)) {
          views = text;
        } else {
          final lower = text.toLowerCase();
          if (lower == 'song' ||
              lower == 'video' ||
              lower == 'single' ||
              lower == 'album' ||
              lower == 'ep') {
            continue;
          }
          artists.add({'name': text, 'id': null});
        }
      }
    }

    return _ParsedRuns(
      artists: artists,
      artistId: artistId,
      albumName: albumName,
      albumId: albumId,
      views: views,
      year: year,
      duration: duration,
    );
  }

  bool _extractIsExplicit(_JsonMap renderer) {
    final badges =
        renderer.getList('badges') ?? renderer.getList('subtitleBadges');
    if (badges != null) {
      for (final b in badges) {
        if (b is! Map) continue;
        final label = b
            .cast<String, dynamic>()
            .getMap('musicInlineBadgeRenderer')
            ?.getMap('accessibilityData')
            ?.getMap('accessibilityData')
            ?.getValue<String>('label');
        if (label != null && label.toLowerCase().contains('explicit')) {
          return true;
        }
        final iconType = b
            .cast<String, dynamic>()
            .getMap('musicInlineBadgeRenderer')
            ?.getMap('icon')
            ?.getValue<String>('iconType');
        if (iconType == 'MUSIC_EXPLICIT_BADGE') {
          return true;
        }
      }
    }
    return false;
  }

  String? _extractVideoType(_JsonMap renderer) {
    return renderer
            .getMap('overlay')
            ?.getMap('musicItemThumbnailOverlayRenderer')
            ?.getMap('content')
            ?.getMap('musicPlayButtonRenderer')
            ?.getMap('playNavigationEndpoint')
            ?.getMap('watchEndpoint')
            ?.getMap('watchEndpointMusicSupportedConfigs')
            ?.getMap('watchEndpointMusicConfig')
            ?.getValue<String>('musicVideoType') ??
        renderer
            .getMap('navigationEndpoint')
            ?.getMap('watchEndpoint')
            ?.getMap('watchEndpointMusicSupportedConfigs')
            ?.getMap('watchEndpointMusicConfig')
            ?.getValue<String>('musicVideoType');
  }

  Map<String, dynamic>? _parseHomeSong(Map<String, dynamic> renderer) {
    try {
      final videoId =
          _trackVideoId(renderer) ??
          renderer
              .getMap('navigationEndpoint')
              ?.getMap('watchEndpoint')
              ?.getValue<String>('videoId');
      if (videoId == null || videoId.isEmpty) return null;

      final rawTitle =
          _flexColumnText(renderer, 0) ??
          _runsText(renderer.getMap('title'))?.trim() ??
          '';
      if (rawTitle.isEmpty) return null;

      final col1Runs =
          _flexColumnRuns(renderer, 1) ??
          renderer
              .getMap('subtitle')
              ?.getList('runs')
              ?.whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();

      final parsedRuns = _parseItemRuns(col1Runs);
      final subtitleParts = _splitBullets(_flexColumnText(renderer, 1));
      final rawSubtitle = _runsText(renderer.getMap('subtitle'))?.trim() ?? '';

      var albumName = parsedRuns.albumName;
      var albumId = parsedRuns.albumId;
      final col2Runs = _flexColumnRuns(renderer, 2);
      if (col2Runs != null && col2Runs.isNotEmpty) {
        final firstRun = col2Runs.first;
        final albText = firstRun['text']?.toString().trim();
        final albId = firstRun
            .getMap('navigationEndpoint')
            ?.getMap('browseEndpoint')
            ?.getValue<String>('browseId');
        if (albText != null && albText.isNotEmpty) {
          albumName = albText;
          albumId = albId;
        }
      }

      final artistName = parsedRuns.artists.isNotEmpty
          ? parsedRuns.artists.map((a) => a['name']).join(', ')
          : (subtitleParts.isNotEmpty
                ? subtitleParts.first
                : (rawSubtitle.isNotEmpty ? rawSubtitle : ''));

      final thumbs = _thumbnailUrls(renderer, 'thumbnail');

      final durationSeconds =
          parsedRuns.duration?.inSeconds ??
          _findDuration(renderer, subtitleParts)?.inSeconds;

      final videoType = _extractVideoType(renderer);
      final isLive =
          videoType == 'MUSIC_VIDEO_TYPE_UGC' ||
          rawTitle.toLowerCase().contains('live') ||
          rawSubtitle.toLowerCase().contains('live');

      final isVideo =
          videoType == 'MUSIC_VIDEO_TYPE_OMV' ||
          videoType == 'MUSIC_VIDEO_TYPE_UGC';

      final playlistId =
          renderer
              .getMap('overlay')
              ?.getMap('musicItemThumbnailOverlayRenderer')
              ?.getMap('content')
              ?.getMap('musicPlayButtonRenderer')
              ?.getMap('playNavigationEndpoint')
              ?.getMap('watchEndpoint')
              ?.getValue<String>('playlistId') ??
          renderer
              .getMap('navigationEndpoint')
              ?.getMap('watchEndpoint')
              ?.getValue<String>('playlistId');

      return {
        'id': videoId,
        'ytid': videoId,
        'title': rawTitle,
        'artist': artistName,
        if (parsedRuns.artistId != null) 'artistId': parsedRuns.artistId,
        if (parsedRuns.artists.isNotEmpty) 'artists': parsedRuns.artists,
        if (albumName != null && albumName.isNotEmpty) 'album': albumName,
        if (albumId != null && albumId.isNotEmpty) 'albumId': albumId,
        if (parsedRuns.views != null) 'views': parsedRuns.views,
        if (playlistId != null && playlistId.isNotEmpty)
          'playlistId': playlistId,
        'image': thumbs['image'],
        'lowResImage': thumbs['lowResImage'],
        'highResImage': thumbs['highResImage'],
        if (durationSeconds != null) 'duration': durationSeconds,
        'isLive': isLive,
        'isExplicit': _extractIsExplicit(renderer),
        if (videoType != null) 'videoType': videoType,
        'source': 'youtube-music',
        'contentType': isVideo ? 'video' : 'song',
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _parseHomeAlbum(
    Map<String, dynamic> renderer,
    String shelfTitle,
  ) {
    try {
      final endpoint = renderer
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint');
      final browseId = endpoint?.getValue<String>('browseId');
      if (browseId == null || browseId.isEmpty) return null;

      final title = _runsText(renderer.getMap('title'))?.trim() ?? '';
      if (title.isEmpty) return null;

      final subtitleRuns = renderer
          .getMap('subtitle')
          ?.getList('runs')
          ?.whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final parsedRuns = _parseItemRuns(subtitleRuns);
      final rawSubtitle = _runsText(renderer.getMap('subtitle'))?.trim() ?? '';

      final thumbs = _thumbnailUrls(renderer, 'thumbnailRenderer');
      final audioPlaylistId = renderer
          .getMap('thumbnailOverlay')
          ?.getMap('musicItemThumbnailOverlayRenderer')
          ?.getMap('content')
          ?.getMap('musicPlayButtonRenderer')
          ?.getMap('playNavigationEndpoint')
          ?.getMap('watchPlaylistEndpoint')
          ?.getValue<String>('playlistId');

      final isSingle = rawSubtitle.toLowerCase().contains('single');
      final isEp = rawSubtitle.toLowerCase().contains('ep');
      final releaseType = isSingle ? 'single' : (isEp ? 'ep' : 'album');

      final artistName = parsedRuns.artists.isNotEmpty
          ? parsedRuns.artists.map((a) => a['name']).join(', ')
          : _sanitizeCurator(rawSubtitle, fallback: 'Official Album');

      return {
        'ytid': browseId,
        'browseId': browseId,
        'title': title,
        'artist': artistName,
        if (parsedRuns.artists.isNotEmpty) 'artists': parsedRuns.artists,
        if (parsedRuns.artistId != null) 'artistId': parsedRuns.artistId,
        if (parsedRuns.year != null) 'year': parsedRuns.year,
        'image': thumbs['image'],
        'lowResImage': thumbs['lowResImage'],
        'highResImage': thumbs['highResImage'],
        'isAlbum': true,
        'isSingle': isSingle,
        'type': releaseType,
        if (audioPlaylistId != null) 'audioPlaylistId': audioPlaylistId,
        'isExplicit': _extractIsExplicit(renderer),
        'source': 'youtube-music-album',
        'contentType': 'album',
        'list': [],
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _parseHomeArtist(Map<String, dynamic> renderer) {
    try {
      final endpoint = renderer
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint');
      final browseId = endpoint?.getValue<String>('browseId');
      if (browseId == null || browseId.isEmpty) return null;

      final title = _runsText(renderer.getMap('title'))?.trim() ?? '';
      if (title.isEmpty) return null;

      final subtitle = _runsText(renderer.getMap('subtitle'))?.trim() ?? '';
      final thumbs = _thumbnailUrls(renderer, 'thumbnailRenderer');

      return {
        'ytid': browseId,
        'browseId': browseId,
        'title': title,
        'image': thumbs['image'],
        'lowResImage': thumbs['lowResImage'],
        'highResImage': thumbs['highResImage'],
        'subscribers': subtitle,
        'isArtist': true,
        'source': 'youtube-artist',
        'contentType': 'artist',
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _parseHomePlaylist(Map<String, dynamic> renderer) {
    try {
      final endpoint = renderer
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint');
      var browseId = endpoint?.getValue<String>('browseId');
      if (browseId == null || browseId.isEmpty) return null;

      if (browseId.startsWith('VL')) {
        browseId = browseId.substring(2);
      }

      final title = _runsText(renderer.getMap('title'))?.trim() ?? '';
      if (title.isEmpty) return null;

      final subtitleRuns = renderer
          .getMap('subtitle')
          ?.getList('runs')
          ?.whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final parsedRuns = _parseItemRuns(subtitleRuns);
      final rawSubtitle = _runsText(renderer.getMap('subtitle'))?.trim() ?? '';

      final thumbs = _thumbnailUrls(renderer, 'thumbnailRenderer');

      String? count;
      final countMatch = RegExp(
        r'(\d+[\d,]*)\s*(songs|tracks)?',
        caseSensitive: false,
      ).firstMatch(rawSubtitle);
      if (countMatch != null) {
        count = countMatch.group(1);
      }

      final curator = parsedRuns.artists.isNotEmpty
          ? parsedRuns.artists.map((a) => a['name']).join(', ')
          : _sanitizeCurator(rawSubtitle, fallback: 'YouTube Music');

      return {
        'ytid': browseId,
        'playlistId': browseId,
        'title': title,
        'artist': curator,
        'author': curator,
        if (parsedRuns.artists.isNotEmpty) 'authors': parsedRuns.artists,
        if (parsedRuns.artists.isNotEmpty) 'artists': parsedRuns.artists,
        if (parsedRuns.artistId != null) 'authorId': parsedRuns.artistId,
        if (rawSubtitle.isNotEmpty) 'description': rawSubtitle,
        if (count != null) 'count': count,
        'image': thumbs['image'],
        'lowResImage': thumbs['lowResImage'],
        'highResImage': thumbs['highResImage'],
        'source': 'youtube-music-playlist',
        'contentType': 'playlist',
        'list': [],
      };
    } catch (_) {
      return null;
    }
  }

  /// Fetches official new album and single releases from YouTube Music (FEmusic_new_releases).
  Future<List<Map<String, dynamic>>> getNewReleases({
    String hl = 'en',
    String gl = 'IN',
    int limit = 24,
  }) async {
    try {
      final root = await browseEndpoint('FEmusic_new_releases', hl: hl, gl: gl);
      final results = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final item in _findRenderers(root, 'musicTwoRowItemRenderer')) {
        final browseEndpoint = item
            .getMap('navigationEndpoint')
            ?.getMap('browseEndpoint');
        final browseId = browseEndpoint?.getValue<String>('browseId');
        if (browseId == null ||
            !browseId.startsWith('MPREb_') ||
            !seen.add(browseId)) {
          continue;
        }

        final title = _runsText(item.getMap('title')) ?? '';
        if (title.isEmpty) continue;

        final subtitle = _runsText(item.getMap('subtitle')) ?? '';
        final thumbUrl = _thumbnailUrl(item, 'thumbnailRenderer');

        results.add({
          'ytid': browseId,
          'title': title,
          'artist': subtitle,
          'image': thumbUrl,
          'lowResImage': thumbUrl,
          'highResImage': thumbUrl,
          'isAlbum': true,
          'source': 'youtube-music-album',
        });
        if (results.length >= limit) return results;
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Fetches top artists from YouTube Music Charts (FEmusic_charts).
  Future<List<Map<String, dynamic>>> getChartsArtists({
    String hl = 'en',
    String gl = 'IN',
    int limit = 40,
  }) async {
    try {
      final root = await browseEndpoint('FEmusic_charts', hl: hl, gl: gl);
      final results = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final item in _findRenderers(
        root,
        'musicResponsiveListItemRenderer',
      )) {
        final browseEndpoint = item
            .getMap('navigationEndpoint')
            ?.getMap('browseEndpoint');
        final channelId = browseEndpoint?.getValue<String>('browseId');
        final pageType = browseEndpoint
            ?.getMap('browseEndpointContextSupportedConfigs')
            ?.getMap('browseEndpointContextMusicConfig')
            ?.getValue<String>('pageType');

        if (pageType == 'MUSIC_PAGE_TYPE_ARTIST' &&
            channelId != null &&
            seen.add(channelId)) {
          final name = _flexColumnText(item, 0);
          final subscribers = _flexColumnText(item, 1);
          final thumbUrl = _thumbnailUrl(item, 'thumbnail');

          results.add({
            'id': channelId,
            'name': name ?? '',
            'subscribers': subscribers,
            'image': thumbUrl,
          });
          if (results.length >= limit) return results;
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Fetches the language top weekly playlists from YouTube Music Charts (FEmusic_charts).
  Future<Map<String, String>> getLanguageTopWeeklyPlaylists({
    String hl = 'en',
    String gl = 'IN',
  }) async {
    try {
      // Force standard English so chart carousel titles and playlist names are consistent
      final root = await browseEndpoint('FEmusic_charts', gl: gl);
      final results = <String, String>{};

      for (final shelf in _findRenderers(root, 'musicCarouselShelfRenderer')) {
        final titleNode = shelf
            .getMap('header')
            ?.getMap('musicCarouselShelfBasicHeaderRenderer')
            ?.getMap('title');
        final shelfTitle = _runsText(titleNode)?.toLowerCase() ?? '';
        if (!shelfTitle.contains('language') &&
            !shelfTitle.contains('video chart')) {
          continue;
        }

        final contents = shelf.getList('contents') ?? const [];
        for (final c in contents) {
          if (c is! Map) continue;
          final item = c.cast<String, dynamic>().getMap(
            'musicTwoRowItemRenderer',
          );
          if (item == null) continue;

          final plTitle = _runsText(item.getMap('title')) ?? '';
          final browseId = item
              .getMap('navigationEndpoint')
              ?.getMap('browseEndpoint')
              ?.getValue<String>('browseId');

          if (browseId != null && browseId.isNotEmpty) {
            final cleanId = browseId.startsWith('VL')
                ? browseId.substring(2)
                : browseId;
            final match = RegExp(
              r'Top\s+Weekly\s+Videos\s+(.+)',
              caseSensitive: false,
            ).firstMatch(plTitle);
            if (match != null) {
              final langName = match.group(1)?.trim().toLowerCase() ?? '';
              results[langName] = cleanId;
            } else if (plTitle.toLowerCase().contains('trending 20')) {
              results['trending20'] = cleanId;
            } else if (plTitle.toLowerCase().contains('top 100')) {
              results['top100'] = cleanId;
              results['india'] = cleanId;
              results.putIfAbsent('hindi', () => cleanId);
            }
          }
        }
      }
      return results;
    } catch (_) {
      return {};
    }
  }

  /// Fetches the ranked songs from a YouTube Music chart playlist (e.g. Top Weekly Videos Tamil).
  Future<List<Map<String, dynamic>>> getChartPlaylistSongs(
    String playlistId, {
    int limit = 50,
    String hl = 'en',
    String gl = 'IN',
  }) async {
    try {
      final browseId = playlistId.startsWith('VL')
          ? playlistId
          : 'VL$playlistId';
      final root = await browseEndpoint(browseId, hl: hl, gl: gl);
      final results = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final item in _findRenderers(
        root,
        'musicResponsiveListItemRenderer',
      )) {
        final videoId = _trackVideoId(item);
        if (videoId == null || videoId.isEmpty || !seen.add(videoId)) continue;

        final rawTitle = _flexColumnText(item, 0) ?? '';
        final subtitleParts = _splitBullets(_flexColumnText(item, 1));
        final artist = subtitleParts.isNotEmpty ? subtitleParts.first : '';
        final thumbUrl =
            _thumbnailUrl(item, 'thumbnail') ??
            _thumbnailUrl(item, 'thumbnailRenderer');
        final duration = _findDuration(item, subtitleParts)?.inSeconds;

        final rank = results.length + 1;

        results.add({
          'id': results.length,
          'ytid': videoId,
          'title': rawTitle,
          'artist': artist,
          'image': thumbUrl,
          'lowResImage': thumbUrl,
          'highResImage': thumbUrl,
          'chartRank': rank,
          if (duration != null) 'duration': duration,
          'isLive': false,
          'source': 'youtube-music',
        });

        if (results.length >= limit) break;
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Fetches available moods and genres from YouTube Music (FEmusic_moods_and_genres).
  Future<List<Map<String, dynamic>>> getMoodsAndGenresList({
    String hl = 'en',
    String gl = 'IN',
  }) async {
    try {
      final root = await browseEndpoint(
        'FEmusic_moods_and_genres',
        hl: hl,
        gl: gl,
      );
      final results = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final btn in _findRenderers(root, 'musicNavigationButtonRenderer')) {
        final title = _runsText(btn.getMap('buttonText'))?.trim();
        final endpoint = btn.getMap('clickCommand')?.getMap('browseEndpoint');
        final browseId = endpoint?.getValue<String>('browseId');
        final params = endpoint?.getValue<String>('params');
        final color = btn.getMap('solid')?.getValue<int>('leftStripeColor');

        if (title != null &&
            title.isNotEmpty &&
            params != null &&
            seen.add(title.toLowerCase())) {
          results.add({
            'title': title,
            'browseId': browseId ?? 'FEmusic_moods_and_genres_category',
            'params': params,
            'color': color,
          });
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Fetches curated playlists for a specific mood/genre (e.g. 'Chill', 'Focus', 'Workout', 'Party', 'Feel good').
  Future<List<Map<String, dynamic>>> getMoodPlaylists({
    String mood = 'Chill',
    String? params,
    String hl = 'en',
    String gl = 'IN',
    int limit = 20,
  }) async {
    try {
      var targetParams = params;
      if (targetParams == null || targetParams.isEmpty) {
        final moodList = await getMoodsAndGenresList(hl: hl, gl: gl);
        final match = moodList.firstWhere((m) {
          final t = m['title'].toString().toLowerCase();
          final target = mood.toLowerCase();
          return t == target || t.contains(target) || target.contains(t);
        }, orElse: () => <String, dynamic>{});
        targetParams = match['params'] as String?;
      }

      if (targetParams == null || targetParams.isEmpty) {
        return [];
      }

      final root = await browseEndpoint(
        'FEmusic_moods_and_genres_category',
        params: targetParams,
        hl: hl,
        gl: gl,
      );

      final results = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final item in _findRenderers(root, 'musicTwoRowItemRenderer')) {
        final endpoint = item
            .getMap('navigationEndpoint')
            ?.getMap('browseEndpoint');
        var browseId = endpoint?.getValue<String>('browseId');
        if (browseId == null || browseId.isEmpty) continue;
        if (browseId.startsWith('VL')) {
          browseId = browseId.substring(2);
        }
        if (!seen.add(browseId)) continue;

        final title = _runsText(item.getMap('title')) ?? '';
        final subtitle = _sanitizeCurator(
          _runsText(item.getMap('subtitle')),
          fallback: 'Featured Playlist',
        )!;
        final thumbUrl = _thumbnailUrl(item, 'thumbnailRenderer');

        results.add({
          'ytid': browseId,
          'title': title,
          'artist': subtitle,
          'image': thumbUrl,
          'lowResImage': thumbUrl,
          'highResImage': thumbUrl,
          'source': 'youtube-music-playlist',
        });

        if (results.length >= limit) break;
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Fetches all shelves from a YouTube Music category browse page (FEmusic_moods_and_genres_category).
  ///
  /// Categorizes returned items into:
  /// - 'songs': pure studio audio songs from the "Songs" shelf
  /// - 'featuredPlaylists': official curated playlists (e.g. Kollywood Hitlist, Tollywood Hitlist)
  /// - 'communityPlaylists': community curated playlists
  /// - 'albums': official albums from the "Albums" shelf
  /// - 'otherPlaylists': any additional mood / genre playlists
  Future<Map<String, List<Map<String, dynamic>>>> getCategoryPageShelves({
    String mood = 'Tamil',
    String? params,
    String hl = 'en',
    String gl = 'IN',
  }) async {
    try {
      var targetParams = params;
      if (targetParams == null || targetParams.isEmpty) {
        final moodList = await getMoodsAndGenresList(hl: hl, gl: gl);
        final target = mood.trim().toLowerCase();
        final match = moodList.firstWhere((m) {
          final t = m['title'].toString().trim().toLowerCase();
          return t == target || t.contains(target) || target.contains(t);
        }, orElse: () => <String, dynamic>{});
        targetParams = match['params'] as String?;
      }

      if (targetParams == null || targetParams.isEmpty) {
        return {
          'songs': [],
          'featuredPlaylists': [],
          'communityPlaylists': [],
          'albums': [],
          'otherPlaylists': [],
        };
      }

      final root = await browseEndpoint(
        'FEmusic_moods_and_genres_category',
        params: targetParams,
        hl: hl,
        gl: gl,
      );

      final songs = <Map<String, dynamic>>[];
      final featuredPlaylists = <Map<String, dynamic>>[];
      final communityPlaylists = <Map<String, dynamic>>[];
      final albums = <Map<String, dynamic>>[];
      final otherPlaylists = <Map<String, dynamic>>[];

      final seenSongIds = <String>{};
      final seenPlIds = <String>{};
      final seenAlbumIds = <String>{};

      for (final shelf in _findRenderers(root, 'musicCarouselShelfRenderer')) {
        final titleNode = shelf
            .getMap('header')
            ?.getMap('musicCarouselShelfBasicHeaderRenderer')
            ?.getMap('title');
        final shelfTitle = _runsText(titleNode)?.toLowerCase() ?? '';

        final contents = shelf.getList('contents') ?? const [];
        for (final c in contents) {
          if (c is! Map) continue;
          final cMap = c.cast<String, dynamic>();

          // 1. Songs from musicResponsiveListItemRenderer
          final songItem = cMap.getMap('musicResponsiveListItemRenderer');
          if (songItem != null) {
            final videoId = _trackVideoId(songItem);
            if (videoId != null &&
                videoId.isNotEmpty &&
                seenSongIds.add(videoId)) {
              final rawTitle = _flexColumnText(songItem, 0) ?? '';
              final subtitleParts = _splitBullets(_flexColumnText(songItem, 1));
              final artist = subtitleParts.isNotEmpty
                  ? subtitleParts.first
                  : '';
              final thumbUrl =
                  _thumbnailUrl(songItem, 'thumbnail') ??
                  _thumbnailUrl(songItem, 'thumbnailRenderer');

              final duration = _findDuration(
                songItem,
                subtitleParts,
              )?.inSeconds;

              songs.add({
                'ytid': videoId,
                'id': videoId,
                'title': rawTitle,
                'artist': artist,
                'image': thumbUrl,
                'lowResImage': thumbUrl,
                'highResImage': thumbUrl,
                if (duration != null) 'duration': duration,
                'isLive': false,
                'source': 'youtube-music',
              });
            }
            continue;
          }

          // 2. Playlists / Albums from musicTwoRowItemRenderer
          final item = cMap.getMap('musicTwoRowItemRenderer');
          if (item == null) continue;

          final endpoint = item
              .getMap('navigationEndpoint')
              ?.getMap('browseEndpoint');
          var browseId = endpoint?.getValue<String>('browseId');
          if (browseId == null || browseId.isEmpty) continue;

          final title = _runsText(item.getMap('title')) ?? '';
          final subtitle = _runsText(item.getMap('subtitle')) ?? '';
          final thumbUrl =
              _thumbnailUrl(item, 'thumbnailRenderer') ??
              _thumbnailUrl(item, 'thumbnail');

          final pageType = endpoint
              ?.getMap('browseEndpointContextSupportedConfigs')
              ?.getMap('browseEndpointContextMusicConfig')
              ?.getValue<String>('pageType');

          final isAlbum =
              browseId.startsWith('MPREb_') ||
              pageType == 'MUSIC_PAGE_TYPE_ALBUM' ||
              shelfTitle.contains('album');

          if (isAlbum) {
            if (seenAlbumIds.add(browseId)) {
              albums.add({
                'ytid': browseId,
                'title': title,
                'artist': _sanitizeCurator(
                  subtitle,
                  fallback: 'Official Album',
                ),
                'image': thumbUrl,
                'lowResImage': thumbUrl,
                'highResImage': thumbUrl,
                'isAlbum': true,
                'source': 'youtube-music-album',
                'list': [],
              });
            }
          } else {
            if (browseId.startsWith('VL')) {
              browseId = browseId.substring(2);
            }
            if (!seenPlIds.add(browseId)) continue;

            final lowerTitle = title.toLowerCase();
            if (lowerTitle.contains('whatsapp status') ||
                lowerTitle.contains('ringtone') ||
                lowerTitle.contains('status video') ||
                lowerTitle.contains('reels status') ||
                lowerTitle.contains('video song') ||
                lowerTitle.contains('1080p') ||
                lowerTitle.contains('4k video') ||
                lowerTitle.contains('trailer') ||
                lowerTitle.contains('teaser') ||
                lowerTitle.contains('mashup') ||
                lowerTitle.contains('bgm status')) {
              continue;
            }

            final plMap = {
              'ytid': browseId,
              'title': title,
              'artist': _sanitizeCurator(
                subtitle,
                fallback: 'Featured Playlist',
              ),
              'image': thumbUrl,
              'lowResImage': thumbUrl,
              'highResImage': thumbUrl,
              'source': 'youtube-music-playlist',
            };

            if (shelfTitle.contains('featured') ||
                (shelfTitle.contains('playlist') &&
                    !shelfTitle.contains('community'))) {
              featuredPlaylists.add(plMap);
            } else if (shelfTitle.contains('community')) {
              communityPlaylists.add(plMap);
            } else {
              otherPlaylists.add(plMap);
            }
          }
        }
      }

      if (featuredPlaylists.isEmpty && otherPlaylists.isNotEmpty) {
        featuredPlaylists.addAll(otherPlaylists);
      }

      return {
        'songs': songs,
        'featuredPlaylists': featuredPlaylists,
        'communityPlaylists': communityPlaylists,
        'albums': albums,
        'otherPlaylists': otherPlaylists,
      };
    } catch (_) {
      return {
        'songs': [],
        'featuredPlaylists': [],
        'communityPlaylists': [],
        'albums': [],
        'otherPlaylists': [],
      };
    }
  }

  /// Fetches video chart playlists (e.g. "Trending 20 India", "Top 100 Music Videos India") from FEmusic_charts.
  Future<List<Map<String, dynamic>>> getChartTrendingPlaylists({
    String hl = 'en',
    String gl = 'IN',
  }) async {
    try {
      final root = await browseEndpoint('FEmusic_charts', hl: hl, gl: gl);
      final results = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final shelf in _findRenderers(root, 'musicCarouselShelfRenderer')) {
        final titleNode = shelf
            .getMap('header')
            ?.getMap('musicCarouselShelfBasicHeaderRenderer')
            ?.getMap('title');
        final shelfTitle = _runsText(titleNode)?.toLowerCase() ?? '';
        if (!shelfTitle.contains('video chart') &&
            !shelfTitle.contains('trending')) {
          continue;
        }

        final contents = shelf.getList('contents') ?? const [];
        for (final c in contents) {
          if (c is! Map) continue;
          final item = c.cast<String, dynamic>().getMap(
            'musicTwoRowItemRenderer',
          );
          if (item == null) continue;

          final plTitle = _runsText(item.getMap('title')) ?? '';
          var browseId = item
              .getMap('navigationEndpoint')
              ?.getMap('browseEndpoint')
              ?.getValue<String>('browseId');
          if (browseId == null || browseId.isEmpty) continue;
          if (browseId.startsWith('VL')) {
            browseId = browseId.substring(2);
          }
          if (!seen.add(browseId)) continue;

          final thumbUrl = _thumbnailUrl(item, 'thumbnailRenderer');
          results.add({
            'ytid': browseId,
            'title': plTitle,
            'artist': 'Top Charts',
            'image': thumbUrl,
            'lowResImage': thumbUrl,
            'highResImage': thumbUrl,
            'source': 'youtube-music-playlist',
          });
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Every release of the artist page: the grid behind each shelf's "More"
  /// button, plus the entries only shown inline.
  Future<List<MusicAlbum>> _collectDiscography(_JsonMap root) async {
    final grids = await Future.wait([
      for (final more in _collectMoreReleaseBrowses(root))
        _browse(
          more.$1,
          params: more.$2,
        ).catchError((_) => <String, dynamic>{}),
    ]);

    // Grids first: they label the release type, the inline previews of an
    // album shelf do not, and [_collectReleases] keeps the first entry seen.
    final releases = <String, MusicAlbum>{};
    for (final grid in grids) {
      _collectReleases(grid, releases);
    }
    _collectReleases(root, releases);
    return releases.values.toList();
  }

  List<MusicTopSong> _parseTopSongs(
    _JsonMap root, {
    required String channelId,
    required String author,
  }) {
    final shelf = _firstRenderer(root, 'musicShelfRenderer');
    if (shelf == null) return const [];

    final songs = <MusicTopSong>[];
    final seen = <String>{};
    for (final item in _findRenderers(
      shelf,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _trackVideoId(item);
      if (videoId == null || !seen.add(videoId)) continue;

      final title = _flexColumnText(item, 0);
      if (title == null || title.isEmpty) continue;

      final trackAuthor = _flexColumnText(item, 1);
      final subtitleParts = _splitBullets(trackAuthor);
      songs.add(
        MusicTopSong(
          _trackVideo(
            item,
            videoId,
            title,
            (trackAuthor == null || trackAuthor.isEmpty) ? author : trackAuthor,
            channelId,
            subtitleParts: subtitleParts,
          ),
          _playCountText(item),
        ),
      );
    }

    return songs;
  }

  /// One track row of a shelf or of a release, as a [Video]. Only the fields
  /// YouTube Music lists in a row are known, the rest is left empty.
  Video _trackVideo(
    _JsonMap item,
    String videoId,
    String title,
    String author,
    String? channelId, {
    List<String>? subtitleParts,
    String? fallbackThumbnailUrl,
  }) {
    var thumbUrl =
        _thumbnailUrl(item, 'thumbnail') ??
        _thumbnailUrl(item, 'thumbnailRenderer') ??
        fallbackThumbnailUrl;
    if (thumbUrl != null &&
        (thumbUrl.contains('youtube.com') || thumbUrl.contains('ytimg.com'))) {
      final uri = Uri.tryParse(thumbUrl);
      if (uri != null && uri.hasQuery) {
        thumbUrl = uri.replace(queryParameters: {}).toString();
      }
    }
    thumbUrl ??= 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
    return Video(
      VideoId(videoId),
      title,
      author,
      ChannelId.fromString(channelId ?? _unknownChannelId),
      null,
      null,
      null,
      '',
      _findDuration(item, subtitleParts),
      ThumbnailSet(videoId),
      null,
      const Engagement(0, null, null),
      false,
      [
        if (thumbUrl.isNotEmpty)
          (
            song: title,
            artist: author,
            album: null,
            image: Uri.tryParse(thumbUrl),
          ),
      ],
    );
  }

  Duration? _findDuration(_JsonMap item, [List<String>? subtitleParts]) {
    final fixed = _fixedColumnText(item);
    final fixedDur = _parseDuration(fixed);
    if (fixedDur != null) return fixedDur;

    if (subtitleParts != null) {
      for (final part in subtitleParts.reversed) {
        final d = _parseDuration(part);
        if (d != null && d.inSeconds > 0) return d;
      }
    }

    final subParts = _subtitleParts(item);
    for (final part in subParts.reversed) {
      final d = _parseDuration(part);
      if (d != null && d.inSeconds > 0) return d;
    }

    for (var i = 1; i < 5; i++) {
      final col = _flexColumnText(item, i);
      if (col == null) continue;
      final d = _parseDuration(col);
      if (d != null && d.inSeconds > 0) return d;
      final parts = _splitBullets(col);
      for (final p in parts.reversed) {
        final pd = _parseDuration(p);
        if (pd != null && pd.inSeconds > 0) return pd;
      }
    }

    return null;
  }

  /// The play count column of a top song, when the shelf lists one. Its
  /// position varies, so every column after the title is probed.
  String? _playCountText(_JsonMap item) {
    for (var index = 1; index < 4; index++) {
      final text = _flexColumnText(item, index);
      if (text != null && _playCountPattern.hasMatch(text)) return text;
    }
    return null;
  }

  void _collectReleases(dynamic root, Map<String, MusicAlbum> into) {
    for (final item in _findRenderers(root, 'musicTwoRowItemRenderer')) {
      final browseId = item
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint')
          ?.getValue<String>('browseId');
      if (browseId == null || !browseId.startsWith('MPRE')) continue;

      final title = _runsText(item.getMap('title'));
      // `Album • 2019`, `Single • 2021`, or just the year when the entry is an
      // inline preview.
      final subtitle = _subtitleParts(item);
      into.putIfAbsent(
        browseId,
        () => MusicAlbum(
          browseId,
          title?.trim() ?? '',
          thumbnailUrl: _thumbnailUrl(item, 'thumbnailRenderer'),
          type: _releaseTypeOf(subtitle),
          year: _releaseYearOf(subtitle),
        ),
      );
    }
  }

  /// Collects the artists of the "Fans might also like" shelf. They sit in the
  /// same rows as the releases, told apart by their channel browse id.
  List<MusicArtist> _collectRelatedArtists(dynamic root) {
    final artists = <String, MusicArtist>{};
    for (final item in _findRenderers(root, 'musicTwoRowItemRenderer')) {
      final endpoint = item
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint');
      final browseId = endpoint?.getValue<String>('browseId');
      if (browseId == null || !browseId.startsWith('UC')) continue;

      final pageType = endpoint
          ?.getMap('browseEndpointContextSupportedConfigs')
          ?.getMap('browseEndpointContextMusicConfig')
          ?.getValue<String>('pageType');
      if (pageType != _artistPageType) continue;

      final name = _runsText(item.getMap('title'))?.trim();
      if (name == null || name.isEmpty) continue;

      artists.putIfAbsent(
        browseId,
        () => MusicArtist(
          id: browseId,
          name: name,
          thumbnailUrl: _thumbnailUrl(item, 'thumbnailRenderer'),
        ),
      );
    }
    return artists.values.toList();
  }

  List<(String, String?)> _collectMoreReleaseBrowses(_JsonMap root) {
    final result = <(String, String?)>[];
    for (final header in _findRenderers(
      root,
      'musicCarouselShelfBasicHeaderRenderer',
    )) {
      final endpoint = header
          .getMap('moreContentButton')
          ?.getMap('buttonRenderer')
          ?.getMap('navigationEndpoint')
          ?.getMap('browseEndpoint');
      final browseId = endpoint?.getValue<String>('browseId');
      if (browseId == null || !browseId.startsWith('MPAD')) continue;
      result.add((browseId, endpoint?.getValue<String>('params')));
    }
    return result;
  }

  List<String> _subtitleParts(_JsonMap? item) {
    final subtitle = _runsText(item?.getMap('subtitle'));
    if (subtitle == null) return const [];
    return subtitle
        .split('•')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  MusicReleaseType _releaseTypeOf(List<String> subtitleParts) {
    for (final part in subtitleParts) {
      switch (part.toLowerCase()) {
        case 'album':
          return MusicReleaseType.album;
        case 'single':
          return MusicReleaseType.single;
        case 'ep':
          return MusicReleaseType.ep;
      }
    }
    return MusicReleaseType.other;
  }

  String? _releaseYearOf(List<String> subtitleParts) {
    for (final part in subtitleParts) {
      if (RegExp(r'^(19|20)\d{2}$').hasMatch(part)) return part;
    }
    return null;
  }

  String? _trackVideoId(_JsonMap item) {
    final playlistVid = item
        .getMap('playlistItemData')
        ?.getValue<String>('videoId');
    if (playlistVid != null && playlistVid.isNotEmpty) return playlistVid;

    return item
        .getMap('overlay')
        ?.getMap('musicItemThumbnailOverlayRenderer')
        ?.getMap('content')
        ?.getMap('musicPlayButtonRenderer')
        ?.getMap('playNavigationEndpoint')
        ?.getMap('watchEndpoint')
        ?.getValue<String>('videoId');
  }

  String? _flexColumnText(_JsonMap item, int index) {
    final columns = item.getList('flexColumns');
    if (columns == null || columns.length <= index) return null;
    final column = columns[index];
    if (column is! Map) return null;
    return _runsText(
      column
          .cast<String, dynamic>()
          .getMap('musicResponsiveListItemFlexColumnRenderer')
          ?.getMap('text'),
    );
  }

  String? _runsText(_JsonMap? node) {
    final runs = node?.getList('runs')?.whereType<Map>().parseRuns();
    return (runs == null || runs.isEmpty) ? null : runs;
  }

  String? _sanitizeCurator(
    String? text, {
    String fallback = 'Curated Playlist',
  }) {
    if (text == null) return fallback;
    var cleaned = text.trim();
    if (cleaned.isEmpty) return fallback;
    cleaned = cleaned
        .replaceAll(
          RegExp(r'\s*•\s*YouTube(?:\s*Music)?', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'YouTube(?:\s*Music)?\s*•\s*', caseSensitive: false),
          '',
        )
        .trim();
    final lower = cleaned.toLowerCase();
    if (lower == 'youtube music' || lower == 'youtube') {
      return fallback;
    }
    if (lower == 'youtube music charts') {
      return 'Top Charts';
    }
    return cleaned.isEmpty ? fallback : cleaned;
  }

  String? _fixedColumnText(_JsonMap item) {
    final columns = item.getList('fixedColumns');
    if (columns == null || columns.isEmpty) return null;
    final lastColumn = columns.last;
    if (lastColumn is! Map) return null;
    return lastColumn
        .cast<String, dynamic>()
        .getMap('musicResponsiveListItemFixedColumnRenderer')
        ?.getMap('text')
        ?.getList('runs')
        ?.whereType<Map>()
        .parseRuns();
  }

  /// The largest artwork URL under [key], which holds a thumbnail renderer:
  /// `thumbnail` on headers and list items, `thumbnailRenderer` on shelf rows.
  String? _thumbnailUrl(_JsonMap? node, String key) {
    if (node == null) return null;

    final target = node.getMap(key);
    final candidates = [
      target
          ?.getMap('musicThumbnailRenderer')
          ?.getMap('thumbnail')
          ?.getList('thumbnails'),
      target
          ?.getMap('croppedSquareThumbnailRenderer')
          ?.getMap('thumbnail')
          ?.getList('thumbnails'),
      target?.getMap('thumbnail')?.getList('thumbnails'),
      target?.getList('thumbnails'),
      node
          .getMap('musicThumbnailRenderer')
          ?.getMap('thumbnail')
          ?.getList('thumbnails'),
      node
          .getMap('croppedSquareThumbnailRenderer')
          ?.getMap('thumbnail')
          ?.getList('thumbnails'),
      node.getMap('thumbnail')?.getList('thumbnails'),
      node.getList('thumbnails'),
    ];

    List<dynamic>? thumbnails;
    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) {
        thumbnails = candidate;
        break;
      }
    }

    if (thumbnails == null || thumbnails.isEmpty) return null;

    String? bestUrl;
    var maxDim = -1;

    for (final item in thumbnails) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final url = map.getValue<String>('url');
      if (url == null || url.trim().isEmpty) continue;

      final width = map.getValue<int>('width') ?? 0;
      final height = map.getValue<int>('height') ?? 0;
      final dim = width > height ? width : height;

      final isSquareYtm =
          url.contains('googleusercontent.com') || url.contains('ggpht.com');

      if (bestUrl == null ||
          (isSquareYtm && !bestUrl.contains('googleusercontent.com')) ||
          (isSquareYtm && dim >= maxDim) ||
          (!isSquareYtm &&
              !bestUrl.contains('googleusercontent.com') &&
              dim >= maxDim)) {
        bestUrl = url;
        maxDim = dim;
      }
    }

    if (bestUrl != null &&
        (bestUrl.contains('youtube.com') || bestUrl.contains('ytimg.com'))) {
      final uri = Uri.tryParse(bestUrl);
      if (uri != null && uri.hasQuery) {
        bestUrl = uri.replace(queryParameters: {}).toString();
      }
    }
    return bestUrl;
  }

  String? _playlistPanelThumbnailUrl(_JsonMap? node) {
    return _thumbnailUrl(node, 'thumbnail');
  }

  Duration? _parseDuration(String? value) {
    if (value == null) return null;
    final clean = value.trim();
    if (!RegExp(r'^\d+:\d{2}(:\d{2})?$').hasMatch(clean)) return null;
    final parts = clean.split(':');
    if (parts.isEmpty || parts.length > 3) return null;

    var seconds = 0;
    for (final part in parts) {
      final n = int.tryParse(part.trim());
      if (n == null) return null;
      seconds = seconds * 60 + n;
    }
    return Duration(seconds: seconds);
  }

  _JsonMap? _firstRenderer(dynamic node, String rendererKey) {
    for (final renderer in _findRenderers(node, rendererKey)) {
      return renderer;
    }
    return null;
  }

  Iterable<_JsonMap> _findRenderers(dynamic node, String rendererKey) sync* {
    if (node is Map) {
      final match = node[rendererKey];
      if (match is Map) yield match.cast<String, dynamic>();
      for (final value in node.values) {
        yield* _findRenderers(value, rendererKey);
      }
    } else if (node is List) {
      for (final value in node) {
        yield* _findRenderers(value, rendererKey);
      }
    }
  }
}

extension _MapReader on Map<String, dynamic> {
  Map<String, dynamic>? getMap(String key) {
    final value = this[key];
    return value is Map ? value.cast<String, dynamic>() : null;
  }

  List<dynamic>? getList(String key) {
    final value = this[key];
    return value is List ? value : null;
  }

  T? getValue<T>(String key) {
    final value = this[key];
    return value is T ? value : null;
  }
}

extension _RunsParser on Iterable<Map<dynamic, dynamic>> {
  String parseRuns() {
    return map((run) => run['text']?.toString() ?? '').join();
  }
}

class _ThumbCandidate {
  const _ThumbCandidate(this.url, this.dim);
  final String url;
  final int dim;
}

class _ParsedRuns {
  const _ParsedRuns({
    this.artists = const [],
    this.artistId,
    this.albumName,
    this.albumId,
    this.views,
    this.year,
    this.duration,
  });

  final List<Map<String, dynamic>> artists;
  final String? artistId;
  final String? albumName;
  final String? albumId;
  final String? views;
  final String? year;
  final Duration? duration;
}
