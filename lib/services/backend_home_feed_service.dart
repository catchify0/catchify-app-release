import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:catchify/main.dart';
import 'package:catchify/models/home_section.dart';

class BackendHomeFeedService {
  static final Uri _endpoint = Uri.parse(
    'https://ios-catchify.onrender.com/home-feed',
  );

  Future<List<HomeSection>> fetchHomeFeed() async {
    try {
      final response = await http
          .get(_endpoint, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        logger.log('[BACKEND_HOME] unexpected status=${response.statusCode}');
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['status'] != 'success') {
        logger.log('[BACKEND_HOME] invalid response envelope');
        return const [];
      }

      final rawSections = decoded['data'];
      if (rawSections is! List) {
        logger.log('[BACKEND_HOME] invalid data payload');
        return const [];
      }

      final sections = <HomeSection>[];
      for (final rawSection in rawSections) {
        final section = _parseSection(rawSection);
        if (section != null && section.isNotEmpty) {
          sections.add(section);
        }
      }
      logger.log('[BACKEND_HOME] sections=${sections.length}');
      return sections;
    } catch (error, stackTrace) {
      logger.log(
        '[BACKEND_HOME] request failed; using existing home feed',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  HomeSection? _parseSection(dynamic rawSection) {
    if (rawSection is! Map) return null;
    final title = rawSection['title']?.toString().trim() ?? '';
    final rawContents = rawSection['contents'];
    if (title.isEmpty || rawContents is! List) return null;

    final contents = <Map<String, dynamic>>[];
    for (final rawItem in rawContents) {
      if (rawItem is! Map) continue;
      final playlistId = rawItem['playlistId']?.toString().trim() ?? '';
      final itemTitle = rawItem['title']?.toString().trim() ?? '';
      if (playlistId.isEmpty || itemTitle.isEmpty) continue;

      final thumbnails = rawItem['thumbnails'];
      String? image;
      if (thumbnails is List) {
        for (final thumbnail in thumbnails.reversed) {
          if (thumbnail is Map &&
              thumbnail['url']?.toString().isNotEmpty == true) {
            image = thumbnail['url'].toString();
            break;
          }
        }
      }

      contents.add({
        'ytid': playlistId,
        'title': itemTitle,
        'image': image,
        'highResImage': image,
        'lowResImage': image,
        'description': rawItem['description']?.toString() ?? '',
        'isPlaylist': true,
        'source': 'catchify-backend',
      });
    }

    return HomeSection(
      title: title,
      type: HomeContentType.playlists,
      contents: contents,
    );
  }
}
