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

enum HomeContentType { songs, albums, artists, playlists, mixed, unknown }

class HomeSection {
  const HomeSection({
    required this.title,
    this.subtitle,
    required this.type,
    required this.contents,
    this.isChunkedSongs = false,
    this.browseId,
    this.params,
  });

  factory HomeSection.fromJson(Map<dynamic, dynamic> json) {
    final typeStr = json['type']?.toString();
    final type = HomeContentType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => HomeContentType.unknown,
    );

    final rawContents = json['contents'];
    final contents = <Map<String, dynamic>>[];
    if (rawContents is List) {
      for (final item in rawContents) {
        if (item is Map) {
          contents.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return HomeSection(
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      type: type,
      contents: contents,
      isChunkedSongs: json['isChunkedSongs'] == true,
      browseId: json['browseId']?.toString(),
      params: json['params']?.toString(),
    );
  }

  final String title;
  final String? subtitle;
  final HomeContentType type;
  final List<Map<String, dynamic>> contents;
  final bool isChunkedSongs;
  final String? browseId;
  final String? params;

  bool get isEmpty => contents.isEmpty;
  bool get isNotEmpty => contents.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'type': type.name,
      'contents': contents,
      'isChunkedSongs': isChunkedSongs,
      if (browseId != null) 'browseId': browseId,
      if (params != null) 'params': params,
    };
  }
}
