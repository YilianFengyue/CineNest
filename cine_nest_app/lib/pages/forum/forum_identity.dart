import 'dart:math';

import 'package:cine_nest/utils/storage.dart';

abstract final class ForumIdentity {
  static const _clientIdKey = 'forum_client_id';
  static const _nicknameKey = 'forum_nickname';

  static String get clientId {
    final cached = GStorage.localCache.get(_clientIdKey) as String?;
    if (cached != null && cached.isNotEmpty) return cached;
    final id =
        'phone-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
    GStorage.localCache.put(_clientIdKey, id);
    return id;
  }

  static String get nickname =>
      GStorage.localCache.get(_nicknameKey, defaultValue: '') as String;

  static Future<void> saveNickname(String value) =>
      GStorage.localCache.put(_nicknameKey, value.trim());
}
