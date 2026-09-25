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

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:catchify/widgets/no_artwork_cube.dart';

class SongArtworkWidget extends StatelessWidget {
  const SongArtworkWidget({
    super.key,
    required this.size,
    required this.metadata,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 10.0,
    this.errorWidgetIconSize = 20.0,
  });

  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final MediaItem metadata;
  final double borderRadius;
  final double errorWidgetIconSize;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;

    if (metadata.artUri?.scheme == 'file') {
      String? localFilePath;
      try {
        localFilePath = metadata.artUri?.toFilePath();
      } catch (_) {}

      if (localFilePath != null &&
          File(localFilePath).existsSync() &&
          File(localFilePath).lengthSync() > 0) {
        return SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              File(localFilePath),
              fit: fit,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackNetworkImage(effectiveWidth, effectiveHeight),
            ),
          ),
        );
      }

      final extraArtwork =
          metadata.extras?['artworkPath']?.toString() ??
          metadata.extras?['artWorkPath']?.toString();
      if (extraArtwork != null &&
          !extraArtwork.startsWith('http') &&
          File(extraArtwork).existsSync() &&
          File(extraArtwork).lengthSync() > 0) {
        return SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              File(extraArtwork),
              fit: fit,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackNetworkImage(effectiveWidth, effectiveHeight),
            ),
          ),
        );
      }

      return _buildFallbackNetworkImage(effectiveWidth, effectiveHeight);
    }

    final imageUrl = metadata.artUri?.toString() ?? '';
    if (imageUrl.isEmpty || imageUrl.startsWith('file://')) {
      return _buildFallbackNetworkImage(effectiveWidth, effectiveHeight);
    }

    final targetMemWidth = (effectiveWidth * 2).round().clamp(64, 1280);
    final targetMemHeight = (effectiveHeight * 2).round().clamp(64, 1280);

    return CachedNetworkImage(
      width: effectiveWidth,
      height: effectiveHeight,
      memCacheWidth: targetMemWidth,
      memCacheHeight: targetMemHeight,
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image(
            image: imageProvider,
            fit: fit,
            width: effectiveWidth,
            height: effectiveHeight,
          ),
        );
      },
      placeholder: (context, url) => NullArtworkWidget(
        iconSize: errorWidgetIconSize,
        width: effectiveWidth,
        height: effectiveHeight,
        borderRadius: borderRadius,
      ),
      errorWidget: (context, url, error) =>
          _buildFallbackNetworkImage(effectiveWidth, effectiveHeight, url),
    );
  }

  Widget _buildFallbackNetworkImage(
    double effectiveWidth,
    double effectiveHeight, [
    String? failedUrl,
  ]) {
    final targetMemWidth = (effectiveWidth * 2).round().clamp(64, 1280);
    final targetMemHeight = (effectiveHeight * 2).round().clamp(64, 1280);
    var remoteUrl =
        metadata.extras?['highResImage']?.toString() ??
        metadata.extras?['image']?.toString() ??
        metadata.extras?['lowResImage']?.toString() ??
        '';

    if (failedUrl != null && failedUrl.contains('maxresdefault.jpg')) {
      remoteUrl = failedUrl.replaceFirst('maxresdefault.jpg', 'mqdefault.jpg');
    } else if (remoteUrl.contains('maxresdefault.jpg') &&
        failedUrl == remoteUrl) {
      remoteUrl = remoteUrl.replaceFirst('maxresdefault.jpg', 'mqdefault.jpg');
    }

    if (remoteUrl.isNotEmpty && remoteUrl.startsWith('http')) {
      return CachedNetworkImage(
        width: effectiveWidth,
        height: effectiveHeight,
        memCacheWidth: targetMemWidth,
        memCacheHeight: targetMemHeight,
        imageUrl: remoteUrl,
        imageBuilder: (context, imageProvider) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image(
              image: imageProvider,
              fit: fit,
              width: effectiveWidth,
              height: effectiveHeight,
            ),
          );
        },
        placeholder: (context, url) => NullArtworkWidget(
          iconSize: errorWidgetIconSize,
          width: effectiveWidth,
          height: effectiveHeight,
          borderRadius: borderRadius,
        ),
        errorWidget: (context, url, error) => NullArtworkWidget(
          iconSize: errorWidgetIconSize,
          width: effectiveWidth,
          height: effectiveHeight,
          borderRadius: borderRadius,
        ),
      );
    }
    return NullArtworkWidget(
      iconSize: errorWidgetIconSize,
      width: effectiveWidth,
      height: effectiveHeight,
      borderRadius: borderRadius,
    );
  }
}
