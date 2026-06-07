class ImageResolver {
  const ImageResolver();

  String? poster({String? tmdbPoster, String? sourcePoster}) {
    if (_valid(tmdbPoster)) return tmdbPoster;
    if (_valid(sourcePoster)) return sourcePoster;
    return null;
  }

  String? backdrop({String? tmdbBackdrop, String? sourceBackdrop}) {
    if (_valid(tmdbBackdrop)) return tmdbBackdrop;
    if (_valid(sourceBackdrop)) return sourceBackdrop;
    return null;
  }

  bool _valid(String? url) {
    if (url == null) return false;
    final value = url.trim();
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
