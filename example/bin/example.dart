import 'package:quick_listener/quick_listener.dart';

void main(List<String> arguments) async {
  if (arguments.contains("--debug"))enableQuickListenerDebugMode();
  print("Disposing an unused key");
  await QuickListener("key0").done();
  print("All keys: ${getAllQuickListenerKeys()}");

  print("Broadcasting to key1 without a listener");
  QuickListener("key1").broadcast(QuickListenerData("Hello, world!"));
  await countdown();

  print("Listening to key1 (onData and onError)");

  QuickListener("key1").listen(
    (data, respond) {
      print("key1 data: $data");
    },
    onError: (error, respond) {
      print("key1 error: $error");
    },
    onDone: () {
      print("key1 done");
    },
  );

  print("Listening to key2 (onData)");

  QuickListener("key2").listen((dynamic data, respond) {
    print("key2 data: $data");
  });

  print("Listening to key3 (onData, both typed and not typed)");

  QuickListener("key3").listen<int>((dynamic data, respond) {
    print("key3 data: $data (typed)");
  });

  QuickListener("key3").listen((dynamic data, respond) {
    print("key3 data: $data");
  });

  if (!arguments.contains("--no-repeated-broadcast-test")) {
    await countdown();
    print("Broadcasting to both key1 and key2");
    QuickListener("key1").broadcast(QuickListenerData("Hello, world!"));
    QuickListener("key2").broadcast(QuickListenerData("Hello, world! 2"));

    await countdown();
    print("Broadcasting to key2");
    QuickListener("key2").broadcast("Hello, world! 2.2");

    await countdown();
    QuickListener("key1").broadcast("Hello, world! 1.2");

    await countdown();
    QuickListener("key3").broadcast("Hello, world! 3");

    await countdown();
    QuickListener("key3").broadcast(3);

    await countdown();
    QuickListener("key3").done();
    await countdown();
  }

  print("Listening to key4 (onData) with response");

  QuickListener("key4").listen((data, respond) async {
    print("key4 data: $data");
    await countdown(3);
    respond();
  });

  if (!arguments.contains("--no-repeated-async-test")) {
    await countdown();
    print("Broadcasting to key4 and waiting for response");
    await QuickListener("key4").broadcast().waitForResponse();
    print("Received response from key4");

    await countdown(2);
    print("All keys: ${getAllQuickListenerKeys()}");
    print("Disposing key2");
    await QuickListener("key2").done();
    print("All keys: ${getAllQuickListenerKeys()}");

    (() async {
      print("Broadcasting on key5 in 3 seconds...");
      await countdown(3);
      QuickListener("key5").broadcast();
      await countdown(3);
      QuickListener("key5").broadcast();
      QuickListener("key5").broadcast(Error());
    })();

    print("Waiting for key5 to get new data...");
    final data = await QuickListener("key5").waitForNewData();
    print("Received data from key5: $data");

    print("Waiting for key5 to get a new event...");
    final event = await QuickListener("key5").waitForNewEvent();
    print("Received event from key5: $event");
  }

  print("All keys: ${getAllQuickListenerKeys()}");
  print("Disposing all keys...");
  await QuickListener().done();
  print("All keys: ${getAllQuickListenerKeys()}");
}

Future<void> countdown([int seconds = 1]) async {
  for (var i = 0; i < seconds; i++) {
    print("Countdown: ${seconds - i}");
    await Future.delayed(Duration(seconds: 1));
  }

  print("Countdown: 0");
  return;
}
