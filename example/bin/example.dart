import 'package:quick_listener/quick_listener.dart';

void main(List<String> arguments) async {
  QuickListener(["key1", "key2"]).broadcast(QuickListenerData("Hello, world!"));
  await countdown();

  QuickListener("key1").listen(
    (dynamic data) {
      print("key1 data: $data");
    },
    onError: (error) {
      print("key1 error: $error");
    },
  );

  QuickListener("key2").listen((dynamic data) {
    print("key2 data: $data");
  });

  QuickListener("key3").listen((dynamic data) {
    print("key3 data: $data");
  });

  await countdown();
  QuickListener(["key1", "key2"]).broadcast(QuickListenerData("Hello, world!"));
  await countdown();
  QuickListener("key2").broadcast("Hello, world! 2");
  await countdown();
  QuickListener("key1").broadcast("Hello, world! 1");
  await countdown();
  QuickListener(["key3"]).broadcast("Hello, world! 3L");
  await countdown();
  QuickListener(["key1"]).broadcast(RangeError("Error!"));
  await countdown(3);
  print("${getAllQuickListenerKeys()}");
  await countdown(1);
  QuickListener("key3").done();
  await countdown(3);
  print("${getAllQuickListenerKeys()}");
}

Future<void> countdown([int seconds = 1]) async {
  for (var i = 0; i < seconds; i++) {
    print("countdown: ${seconds - i}");
    await Future.delayed(Duration(seconds: 1));
  }

  print("countdown: 0");
}
