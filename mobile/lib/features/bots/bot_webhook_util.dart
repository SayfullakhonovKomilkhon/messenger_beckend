/// Normalizes bot webhook URL: host-only URLs get path `/webhook`.
class BotWebhookUtil {
  BotWebhookUtil._();

  static String normalizeWebhookUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return s;
    final path = uri.path;
    if (path.isEmpty || path == '/') {
      return uri.replace(path: '/webhook').toString();
    }
    return s;
  }
}
