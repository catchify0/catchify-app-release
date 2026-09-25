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

class ProxyInfo {
  ProxyInfo({
    required this.source,
    required this.country,
    required this.address,
    this.isSsl,
  });
  final String address;
  final String country;
  final bool? isSsl;
  final String source;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProxyInfo &&
        other.address == address &&
        other.country == country;
  }

  @override
  int get hashCode => address.hashCode ^ country.hashCode;
}

enum ProxyMode { off, auto, countryMatch, custom }

extension ProxyModeExtension on ProxyMode {
  String get displayName {
    switch (this) {
      case ProxyMode.off:
        return 'Off';
      case ProxyMode.auto:
        return 'Smart Auto (On Error)';
      case ProxyMode.countryMatch:
        return 'Country Matched';
      case ProxyMode.custom:
        return 'Custom Proxy';
    }
  }

  String get description {
    switch (this) {
      case ProxyMode.off:
        return 'Direct connection only (fastest, default).';
      case ProxyMode.auto:
        return 'Direct by default; automatically engages proxy only when playback fails or is geo-blocked.';
      case ProxyMode.countryMatch:
        return 'Routes requests through a proxy matching your selected Music Region.';
      case ProxyMode.custom:
        return 'Routes all traffic through your own specified HTTP/SOCKS5 proxy server.';
    }
  }
}

class ProxyStatus {
  const ProxyStatus({
    required this.mode,
    this.isActive = false,
    this.address,
    this.country,
    this.latencyMs,
    this.message,
  });

  final ProxyMode mode;
  final bool isActive;
  final String? address;
  final String? country;
  final int? latencyMs;
  final String? message;
}
