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
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/widgets/confirmation_dialog.dart';

void showRemoveOfflinePlaylistDialog(BuildContext context, String playlistId) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage:
            context.l10n?.removeOfflinePlaylistConfirm ??
            'Are you sure you want to remove this offline playlist?',
        submitMessage: context.l10n?.remove ?? 'Remove',
        isDangerous: true,
        onCancel: () => Navigator.pop(context),
        onSubmit: () {
          unawaited(offlinePlaylistService.removeOfflinePlaylist(playlistId));
          Navigator.pop(context);
          showToast(
            context,
            context.l10n?.playlistRemovedFromOffline ??
                'Playlist removed from offline',
          );
        },
      );
    },
  );
}
