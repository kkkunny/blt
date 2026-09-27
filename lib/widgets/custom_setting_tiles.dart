import 'package:blt/consts/color.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

// 设置面板：白色半透明圆角容器
class CustomSettingsPanel extends StatelessWidget {
  final List<Widget> children;

  const CustomSettingsPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20 * ui),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.06),
            blurRadius: 16 * ui,
            offset: Offset(0, 4 * ui),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 2 * ui,
                indent: 20 * ui,
                endIndent: 20 * ui,
                color: Colors.black.withValues(alpha: 0.05),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

// 设置项外框：焦点特效 + 图标 + 标题 + 尾部控件
class _SettingsTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget trailing;
  final VoidCallback onSelect;
  final bool autofocus;

  const _SettingsTile({
    required this.title,
    required this.trailing,
    required this.onSelect,
    this.leading,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return DpadFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      builder: pinkFocusEffect(ui: ui, radius: 16 * ui),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * ui, vertical: 14 * ui),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme(
                data: IconThemeData(size: 28 * ui, color: biliPink),
                child: leading!,
              ),
              SizedBox(width: 14 * ui),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24 * ui, color: Colors.black87),
              ),
            ),
            SizedBox(width: 16 * ui),
            trailing,
          ],
        ),
      ),
    );
  }
}

// 开关设置项
class CustomSettingsSwitchTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool autofocus;

  const CustomSettingsSwitchTile({
    super.key,
    this.leading,
    required this.title,
    required this.value,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return _SettingsTile(
      leading: leading,
      title: title,
      autofocus: autofocus,
      onSelect: () => onChanged(!value),
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 64 * ui,
        height: 36 * ui,
        padding: EdgeInsets.all(3 * ui),
        decoration: BoxDecoration(
          color: value ? biliPink : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(18 * ui),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 30 * ui,
            height: 30 * ui,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// 下拉选择设置项
class CustomSettingsDropdownTile<T> extends StatelessWidget {
  final Widget? leading;
  final String title;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final bool autofocus;

  const CustomSettingsDropdownTile({
    super.key,
    this.leading,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.autofocus = false,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) => _SettingsPickerSheet<T>(value: value, items: items),
    );
    if (selected != null && selected != value) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return _SettingsTile(
      leading: leading,
      title: title,
      autofocus: autofocus,
      onSelect: () => _openPicker(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24 * ui,
              fontWeight: FontWeight.w600,
              color: biliPink,
            ),
          ),
          SizedBox(width: 6 * ui),
          Icon(Icons.arrow_drop_down_rounded, size: 32 * ui, color: biliPink),
        ],
      ),
    );
  }
}

// 下拉选择弹窗
class _SettingsPickerSheet<T> extends StatelessWidget {
  final T value;
  final List<T> items;

  const _SettingsPickerSheet({required this.value, required this.items});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16 * ui),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20 * ui),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withValues(alpha: 0.15),
                blurRadius: 16 * ui,
                offset: Offset(0, 4 * ui),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(vertical: 14 * ui),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 560 * ui),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final item in items)
                  DpadFocusable(
                    autofocus: item == value,
                    onSelect: () => Navigator.of(context).pop(item),
                    builder: pinkFocusEffect(ui: ui, radius: 12 * ui),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24 * ui,
                        vertical: 12 * ui,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$item',
                              style: TextStyle(
                                fontSize: 22 * ui,
                                fontWeight: item == value
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: item == value
                                    ? biliPink
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (item == value)
                            Icon(
                              Icons.check_rounded,
                              size: 28 * ui,
                              color: biliPink,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
