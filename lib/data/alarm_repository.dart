import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm.dart';

/// 闹钟仓库：纯本地 JSON 持久化。
/// 数据量小（几十条以内），shared_preferences 足够，无需数据库。
class AlarmRepository {
  static const _storageKey = 'alarms_v2';

  final SharedPreferences _prefs;
  List<Alarm> _cache = const [];

  AlarmRepository._(this._prefs);

  static Future<AlarmRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = AlarmRepository._(prefs);
    repo._cache = repo._readAll();
    return repo;
  }

  List<Alarm> _readAll() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Alarm.fromJson)
          .whereType<Alarm>()
          .toList();
    } catch (_) {
      // 本地数据损坏时不抛出，按空列表处理，避免应用无法启动
      return [];
    }
  }

  List<Alarm> get alarms => List.unmodifiable(_cache);

  Future<void> save(Alarm alarm) async {
    final idx = _cache.indexWhere((a) => a.id == alarm.id);
    if (idx >= 0) {
      _cache = [..._cache]..[idx] = alarm;
    } else {
      _cache = [..._cache, alarm];
    }
    await _persist();
  }

  Future<void> remove(String id) async {
    _cache = _cache.where((a) => a.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    final raw = jsonEncode(_cache.map((a) => a.toJson()).toList());
    await _prefs.setString(_storageKey, raw);
  }

  Alarm? byId(String id) {
    for (final a in _cache) {
      if (a.id == id) return a;
    }
    return null;
  }
}
