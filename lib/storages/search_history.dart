import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _historyKey = 'search_history';

// 本地搜索历史（用户数据，与 Settings 的配置分开存）。
// 去重置顶、上限 [maxItems] 条；本地数据损坏时按空处理，不影响搜索。
class SearchHistory {
  static const maxItems = 10;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(String keyword) async {
    final word = keyword.trim();
    if (word.isEmpty) return;

    final history = await load();
    history.removeWhere((e) => e == word);
    history.insert(0, word);
    if (history.length > maxItems) {
      history.removeRange(maxItems, history.length);
    }
    await _save(history);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  static Future<void> _save(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(history));
  }
}
