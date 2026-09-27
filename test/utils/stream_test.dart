import 'dart:async';

import 'package:blt/utils/stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combineBoolStream：任一为 true 即为 true，全部 false 才为 false', () async {
    final s1 = StreamController<bool>();
    final s2 = StreamController<bool>();
    final values = <bool>[];
    final sub = combineBoolStream(s1.stream, s2.stream).listen(values.add);

    await pumpEventQueue();
    expect(values, [false]);

    s1.add(true);
    await pumpEventQueue();
    expect(values.last, true);

    s2.add(true);
    await pumpEventQueue();
    expect(values.last, true);

    s1.add(false);
    await pumpEventQueue();
    expect(values.last, true);

    s2.add(false);
    await pumpEventQueue();
    expect(values.last, false);

    s1.add(true);
    await pumpEventQueue();
    expect(values.last, true);

    await sub.cancel();
    await s1.close();
    await s2.close();
  });
}
