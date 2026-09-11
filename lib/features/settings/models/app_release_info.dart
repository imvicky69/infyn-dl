/// Metadata and download links for a GitHub release of Infyn DL.
class AppReleaseInfo {
  final String tagName;
  final String title;
  final String body;
  final DateTime? publishedAt;
  final String htmlUrl;
  final String? arm64ApkUrl;
  final String? universalApkUrl;
  final bool isUpdateAvailable;

  const AppReleaseInfo({
    required this.tagName,
    required this.title,
    required this.body,
    required this.publishedAt,
    required this.htmlUrl,
    required this.arm64ApkUrl,
    required this.universalApkUrl,
    required this.isUpdateAvailable,
  });

  /// The cleanest direct download URL available (prefers lightweight ARM64, falls back to universal).
  String get preferredDownloadUrl =>
      arm64ApkUrl ?? universalApkUrl ?? htmlUrl;

  /// Clean version string without leading 'v'.
  String get cleanVersion => tagName.replaceFirst(RegExp(r'^[vV]'), '');

  factory AppReleaseInfo.fromJson(
    Map<String, dynamic> json, {
    required String currentVersion,
  }) {
    final tag = json['tag_name']?.toString() ?? '';
    final title = json['name']?.toString() ?? tag;
    final body = json['body']?.toString() ?? '';
    final htmlUrl = json['html_url']?.toString() ??
        'https://github.com/imvicky69/infyn-dl/releases/latest';

    DateTime? published;
    if (json['published_at'] != null) {
      published = DateTime.tryParse(json['published_at'].toString());
    }

    String? arm64Url;
    String? universalUrl;

    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        final downloadUrl = asset['browser_download_url']?.toString();
        if (downloadUrl != null && name.endsWith('.apk')) {
          if (name.contains('arm64')) {
            arm64Url = downloadUrl;
          } else if (name.contains('universal') || name.contains('android')) {
            universalUrl = downloadUrl;
          } else {
            universalUrl ??= downloadUrl;
          }
        }
      }
    }

    final isNewer = compareVersions(tag, currentVersion) > 0;

    return AppReleaseInfo(
      tagName: tag,
      title: title.isNotEmpty ? title : tag,
      body: body,
      publishedAt: published,
      htmlUrl: htmlUrl,
      arm64ApkUrl: arm64Url,
      universalApkUrl: universalUrl,
      isUpdateAvailable: isNewer,
    );
  }

  /// Compares two semver strings (e.g. "1.0.4" vs "1.0.3").
  /// Returns > 0 if v1 > v2, < 0 if v1 < v2, 0 if equal.
  static int compareVersions(String v1, String v2) {
    final p1 = v1
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp(r'[-+]'))
        .first
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    final p2 = v2
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp(r'[-+]'))
        .first
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (int i = 0; i < maxLen; i++) {
      final n1 = i < p1.length ? p1[i] : 0;
      final n2 = i < p2.length ? p2[i] : 0;
      if (n1 != n2) {
        return n1.compareTo(n2);
      }
    }
    return 0;
  }
}
