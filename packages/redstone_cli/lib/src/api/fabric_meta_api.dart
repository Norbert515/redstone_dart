import 'dart:convert';

import 'package:http/http.dart' as http;

import '../util/logger.dart';

/// Service for fetching Fabric version information from the Meta API.
/// API docs: https://meta.fabricmc.net/
class FabricMetaApi {
  static const String _baseUrl = 'https://meta.fabricmc.net/v2';

  /// Cached versions to avoid repeated API calls
  static List<GameVersion>? _gameVersionsCache;
  static List<LoaderVersion>? _loaderVersionsCache;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Get all supported Minecraft versions
  static Future<List<GameVersion>> getGameVersions() async {
    if (_isCacheValid() && _gameVersionsCache != null) {
      return _gameVersionsCache!;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/versions/game'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _gameVersionsCache = data.map((v) => GameVersion.fromJson(v)).toList();
        _cacheTime = DateTime.now();
        return _gameVersionsCache!;
      }
    } catch (e) {
      Logger.warning('Failed to fetch game versions from Fabric API: $e');
    }

    // Return fallback versions if API fails
    return _fallbackGameVersions;
  }

  /// Get all loader versions
  static Future<List<LoaderVersion>> getLoaderVersions() async {
    if (_isCacheValid() && _loaderVersionsCache != null) {
      return _loaderVersionsCache!;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/versions/loader'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _loaderVersionsCache =
            data.map((v) => LoaderVersion.fromJson(v)).toList();
        _cacheTime = DateTime.now();
        return _loaderVersionsCache!;
      }
    } catch (e) {
      Logger.warning('Failed to fetch loader versions from Fabric API: $e');
    }

    // Return fallback
    return _fallbackLoaderVersions;
  }

  /// Get the latest stable Minecraft version
  static Future<String> getLatestStableGameVersion() async {
    final versions = await getGameVersions();
    return versions.firstWhere((v) => v.stable, orElse: () => versions.first).version;
  }

  /// Get the latest stable loader version
  static Future<String> getLatestStableLoaderVersion() async {
    final versions = await getLoaderVersions();
    return versions.firstWhere((v) => v.stable, orElse: () => versions.first).version;
  }

  /// Get Fabric API version for a Minecraft version
  /// Note: Fabric API versions are on Maven, not Meta API
  /// We use a mapping for known versions + fallback pattern
  static Future<String> getFabricApiVersion(String mcVersion) async {
    // Known stable Fabric API versions
    const knownVersions = {
      '1.21.11': '0.139.4+1.21.11',
      '1.21.5': '0.119.5+1.21.5',
      '1.21.4': '0.115.2+1.21.4',
      '1.21.3': '0.110.5+1.21.3',
      '1.21.2': '0.106.1+1.21.2',
      '1.21.1': '0.107.0+1.21.1',
      '1.21': '0.100.8+1.21',
      '1.20.6': '0.100.0+1.20.6',
      '1.20.4': '0.97.2+1.20.4',
      '1.20.2': '0.91.6+1.20.2',
      '1.20.1': '0.92.2+1.20.1',
      '1.20': '0.83.0+1.20',
    };

    if (knownVersions.containsKey(mcVersion)) {
      return knownVersions[mcVersion]!;
    }

    // Try to construct a version string for unknown versions
    // This is a best-effort fallback
    Logger.warning(
        'Unknown Fabric API version for MC $mcVersion, using latest known pattern');
    return '0.139.4+$mcVersion';
  }

  /// Check if a Minecraft version is supported by Fabric
  static Future<bool> isVersionSupported(String mcVersion) async {
    final versions = await getGameVersions();
    return versions.any((v) => v.version == mcVersion);
  }

  /// Get recommended versions for a new project
  static Future<FabricVersions> getRecommendedVersions(
      {String? minecraftVersion}) async {
    final mcVersion =
        minecraftVersion ?? await getLatestStableGameVersion();
    final loaderVersion = await getLatestStableLoaderVersion();
    final fabricApiVersion = await getFabricApiVersion(mcVersion);

    return FabricVersions(
      minecraft: mcVersion,
      loader: loaderVersion,
      fabricApi: fabricApiVersion,
      loom: '1.14-SNAPSHOT', // Loom version is separate from Fabric API
    );
  }

  static bool _isCacheValid() {
    if (_cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!) < _cacheDuration;
  }

  /// Fallback game versions when API is unavailable
  static final List<GameVersion> _fallbackGameVersions = [
    GameVersion(version: '1.21.11', stable: true),
    GameVersion(version: '1.21.5', stable: true),
    GameVersion(version: '1.21.4', stable: true),
    GameVersion(version: '1.21.1', stable: true),
    GameVersion(version: '1.21', stable: true),
    GameVersion(version: '1.20.4', stable: true),
    GameVersion(version: '1.20.1', stable: true),
  ];

  /// Fallback loader versions when API is unavailable
  static final List<LoaderVersion> _fallbackLoaderVersions = [
    LoaderVersion(version: '0.18.2', stable: true),
  ];
}

/// Represents a Minecraft game version
class GameVersion {
  final String version;
  final bool stable;

  GameVersion({required this.version, required this.stable});

  factory GameVersion.fromJson(Map<String, dynamic> json) {
    return GameVersion(
      version: json['version'] as String,
      stable: json['stable'] as bool? ?? false,
    );
  }
}

/// Represents a Fabric Loader version
class LoaderVersion {
  final String version;
  final bool stable;

  LoaderVersion({required this.version, required this.stable});

  factory LoaderVersion.fromJson(Map<String, dynamic> json) {
    return LoaderVersion(
      version: json['version'] as String,
      stable: json['stable'] as bool? ?? false,
    );
  }
}

/// Bundle of all Fabric-related versions for a project
class FabricVersions {
  final String minecraft;
  final String loader;
  final String fabricApi;
  final String loom;

  FabricVersions({
    required this.minecraft,
    required this.loader,
    required this.fabricApi,
    required this.loom,
  });

  @override
  String toString() =>
      'FabricVersions(mc: $minecraft, loader: $loader, api: $fabricApi, loom: $loom)';
}
