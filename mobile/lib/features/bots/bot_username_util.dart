/// Strips leading @ so API receives only the handle (backend allows [a-zA-Z0-9._-]).
String normalizeBotUsername(String? raw) {
  var s = (raw ?? '').trim();
  if (s.startsWith('@')) {
    s = s.substring(1).trim();
  }
  return s;
}
