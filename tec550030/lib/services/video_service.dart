import 'package:url_launcher/url_launcher.dart';

class VideoService {
  /// Replaced in tests, where no platform launcher exists.
  static Future<bool> Function(Uri) launcher = _launch;

  static Future<bool> _launch(Uri uri) async {
    // Prefer the YouTube app; fall back to the browser.
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
    return launchUrl(uri);
  }

  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launcher(uri);
    } catch (_) {
      return false;
    }
  }
}
