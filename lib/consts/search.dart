// 搜索相关的选项枚举：value 为 B 站接口参数，description 为界面文案。
// 写法与 consts/settings.dart 中的 PlayerAspectMode 保持一致。

// 搜索排序方式（search/type 的 order 参数）
enum SearchOrder {
  totalrank('totalrank', '综合'),
  click('click', '最多播放'),
  pubdate('pubdate', '最新发布'),
  dm('dm', '最多弹幕'),
  stow('stow', '最多收藏');

  final String value;
  final String description;

  const SearchOrder(this.value, this.description);

  @override
  String toString() => description;
}

// 搜索时长筛选（search/type 的 duration 参数）
enum SearchDuration {
  all(0, '全部时长'),
  short(1, '10分钟以下'),
  medium(2, '10-30分钟'),
  long(3, '30-60分钟'),
  veryLong(4, '60分钟以上');

  final int value;
  final String description;

  const SearchDuration(this.value, this.description);

  @override
  String toString() => description;
}
