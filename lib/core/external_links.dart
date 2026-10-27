import 'package:url_launcher/url_launcher.dart';

/// Opens a URL outside the application, e.g. in the default browser.
///
/// Injectable so that widgets can be tested without a platform channel; see
/// [UrlOpener].
typedef UrlOpener = Future<bool> Function(Uri url);

/// Opens [url] in the platform's default handler for its scheme.
///
/// Returns false instead of throwing when no handler is available, e.g. on a
/// device without a browser.
Future<bool> openExternalUrl(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Exception {
    return false;
  }
}
