/// Identifies the source of a media item.
enum MediaSourceType {
  local,
  youtube;

  String get value => name; // 'local' | 'youtube'

  static MediaSourceType fromValue(String? v) =>
      v == 'youtube' ? youtube : local;
}
