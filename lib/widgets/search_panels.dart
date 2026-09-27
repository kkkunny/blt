import 'package:blt/consts/color.dart';
import 'package:blt/consts/search.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/focusable_chip.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

const _titleColor = Color(0xFF4A4F5A);
const _chipTextColor = Color(0xFF4A4F5A);

// 搜索 idle 面板：搜索历史 + 热门搜索。
//
// TV 上打字成本高，未搜索时整屏展示可一键搜索的词条；
// 历史为空时只显示热搜，两者都空时给一句引导。
class SearchIdlePanel extends StatelessWidget {
  final List<String> history;
  final List<String> hotWords;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearHistory;
  final bool autofocusFirst; // 进入页面时焦点落在第一个胶囊上

  const SearchIdlePanel({
    super.key,
    required this.history,
    required this.hotWords,
    required this.onSearch,
    required this.onClearHistory,
    this.autofocusFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    if (history.isEmpty && hotWords.isEmpty) {
      return Center(
        child: Text(
          '输入关键词开始搜索',
          style: TextStyle(fontSize: 28 * ui, color: Colors.grey.shade600),
        ),
      );
    }

    // 焦点按"有历史先落历史，否则落热搜"的顺序给第一个胶囊
    var needAutofocus = autofocusFirst;
    Widget chip(String word, {Widget? leading}) {
      final autofocus = needAutofocus;
      needAutofocus = false;
      return FocusableChip(
        label: word,
        leading: leading,
        autofocus: autofocus,
        onTap: () => onSearch(word),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 48 * ui, vertical: 24 * ui),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (history.isNotEmpty) ...[
            _buildTitle(
              context,
              Icons.history_rounded,
              '搜索历史',
              trailing: FocusableChip(
                label: '清空',
                leading: Icon(
                  Icons.delete_outline_rounded,
                  size: 22 * ui,
                  color: _chipTextColor,
                ),
                height: 48,
                fontSize: 20,
                radius: 24,
                padding: EdgeInsets.symmetric(horizontal: 20 * ui),
                onTap: onClearHistory,
              ),
            ),
            SizedBox(height: 18 * ui),
            Wrap(
              spacing: 16 * ui,
              runSpacing: 16 * ui,
              children: [for (final word in history) chip(word)],
            ),
            SizedBox(height: 36 * ui),
          ],
          if (hotWords.isNotEmpty) ...[
            _buildTitle(context, Icons.local_fire_department_rounded, '热门搜索'),
            SizedBox(height: 18 * ui),
            Wrap(
              spacing: 16 * ui,
              runSpacing: 16 * ui,
              children: [
                for (var i = 0; i < hotWords.length; i++)
                  chip(hotWords[i], leading: _buildRankBadge(context, i + 1)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTitle(
    BuildContext context,
    IconData icon,
    String title, {
    Widget? trailing,
  }) {
    final ui = context.ui;
    return Row(
      children: [
        Icon(icon, size: 30 * ui, color: biliPink),
        SizedBox(width: 10 * ui),
        Text(
          title,
          style: TextStyle(
            fontSize: 26 * ui,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  // 热搜名次徽标：前三名粉色渐变，其余浅灰
  Widget _buildRankBadge(BuildContext context, int rank) {
    final ui = context.ui;
    final top3 = rank <= 3;
    return Container(
      width: 32 * ui,
      height: 32 * ui,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: top3 ? pinkGradient : null,
        color: top3 ? null : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8 * ui),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 20 * ui,
          fontWeight: FontWeight.w700,
          color: top3 ? Colors.white : _titleColor,
        ),
      ),
    );
  }
}

// 搜索联想浮层：输入框下方浮出，最多 [maxItems] 条（避免被 TV 软键盘遮挡）
class SearchSuggestPanel extends StatelessWidget {
  static const maxItems = 5;

  final String keyword;
  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  const SearchSuggestPanel({
    super.key,
    required this.keyword,
    required this.suggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final items = suggestions.take(maxItems).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8 * ui, horizontal: 8 * ui),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24 * ui),
        boxShadow: [
          BoxShadow(
            color: biliPink.withValues(alpha: 0.18),
            blurRadius: 26 * ui,
            spreadRadius: 1 * ui,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            _SuggestRow(
              keyword: keyword,
              value: item,
              onTap: () => onSelected(item),
            ),
        ],
      ),
    );
  }
}

class _SuggestRow extends StatelessWidget {
  final String keyword;
  final String value;
  final VoidCallback onTap;

  const _SuggestRow({
    required this.keyword,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DpadFocusable(
        onSelect: onTap,
        builder: (context, isFocused, _) => buildPinkFocusEffect(
          ui: ui,
          radius: 16 * ui,
          borderWidth: 2 * ui,
          isFocused: isFocused,
          focusedBackgroundColor: Colors.white,
          child: Container(
            height: 64 * ui,
            padding: EdgeInsets.symmetric(horizontal: 18 * ui),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 26 * ui,
                  color: isFocused ? biliPink : Colors.grey.shade500,
                ),
                SizedBox(width: 12 * ui),
                Expanded(
                  child: Text.rich(
                    _highlight(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 命中输入内容的部分用粉色加粗
  TextSpan _highlight(BuildContext context) {
    final ui = context.ui;
    final base = TextStyle(fontSize: 24 * ui, color: Colors.black87);
    final matched = TextStyle(
      fontSize: 24 * ui,
      color: biliPink,
      fontWeight: FontWeight.w700,
    );
    final needle = keyword.trim().toLowerCase();
    final start = needle.isEmpty ? -1 : value.toLowerCase().indexOf(needle);
    if (start < 0) return TextSpan(text: value, style: base);

    final end = start + needle.length;
    return TextSpan(
      style: base,
      children: [
        if (start > 0) TextSpan(text: value.substring(0, start)),
        TextSpan(text: value.substring(start, end), style: matched),
        if (end < value.length) TextSpan(text: value.substring(end)),
      ],
    );
  }
}

// 结果头部：关键词 + 总数 + 排序/时长筛选（横向可滚动，焦点移动时自动带入视野）
class SearchResultHeader extends StatelessWidget {
  final String keyword;
  final int total;
  final bool searching; // 搜索中（新关键词的首屏请求还没回来）
  final SearchOrder order;
  final SearchDuration duration;
  final ValueChanged<SearchOrder> onOrderChanged;
  final ValueChanged<SearchDuration> onDurationChanged;
  final bool autofocusFirst; // 结果区首次出现时把焦点落在第一个筛选胶囊

  const SearchResultHeader({
    super.key,
    required this.keyword,
    required this.total,
    required this.order,
    required this.duration,
    required this.onOrderChanged,
    required this.onDurationChanged,
    this.searching = false,
    this.autofocusFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    var needAutofocus = autofocusFirst;
    Widget filterChip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      final autofocus = needAutofocus;
      needAutofocus = false;
      return _buildFilterChip(
        context,
        label: label,
        selected: selected,
        autofocus: autofocus,
        onTap: onTap,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * ui),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '「$keyword」',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28 * ui,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(width: 12 * ui),
              if (searching)
                Text(
                  '正在搜索…',
                  style: TextStyle(
                    fontSize: 22 * ui,
                    color: Colors.grey.shade600,
                  ),
                )
              else if (total > 0)
                Text(
                  '共 $total 条视频',
                  style: TextStyle(
                    fontSize: 22 * ui,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 12 * ui),
        // 高度留出光晕空间（14ui），避免滚动视口把焦点光晕裁掉
        SizedBox(
          height: 80 * ui,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 24 * ui, vertical: 14 * ui),
            children: [
              for (final item in SearchOrder.values)
                filterChip(
                  label: item.description,
                  selected: item == order,
                  onTap: () => onOrderChanged(item),
                ),
              _buildDivider(context),
              for (final item in SearchDuration.values)
                filterChip(
                  label: item.description,
                  selected: item == duration,
                  onTap: () => onDurationChanged(item),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool autofocus = false,
  }) {
    final ui = context.ui;
    return Padding(
      padding: EdgeInsets.only(right: 12 * ui),
      child: FocusableChip(
        label: label,
        selected: selected,
        autofocus: autofocus,
        height: 52,
        fontSize: 22,
        radius: 26,
        padding: EdgeInsets.symmetric(horizontal: 22 * ui),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final ui = context.ui;
    return SizedBox(
      width: 24 * ui,
      child: Center(
        child: Container(
          width: UiScale.border(1, ui),
          height: 28 * ui,
          color: Colors.black12,
        ),
      ),
    );
  }
}
