import 'dart:async';

List<String> _keys = [];
StreamController<QuickListenerEvent> _controller = StreamController.broadcast();

/// Get all keys with a current state.
///
/// If a key is disposed of (using done()) then it will be removed from the state and will not be accessible here.
List<String> getAllQuickListenerKeys() {
  return _keys;
}

// Checks if the inputted object can be classified as an [Error] or [Exception].
bool _isError(dynamic object) {
  return object is Error || object is Exception;
}

/// A specifier
enum QuickListenerEventType {
  /// Normal event.
  data,

  /// Error event.
  error,

  /// Dispose event.
  done,
}

/// Called when a developer inputs an improper input for QuickListener's key/list of keys.
///
/// It extends TypeError instead of Error for more clarity.
class QuickListenerTypeError extends TypeError {
  /// The type(s) expected.
  List<String>? expected;

  /// The absolute type received.
  Type got;

  /// [got] is required, but [expected] is not.
  ///
  /// Expected defaults to [null], [String], or [List<String>].
  QuickListenerTypeError({this.expected, required this.got});

  /// A string representation of this error.
  ///
  /// Shows the expected type(s), the received absolute type, and a message to go along with it.
  @override
  String toString() {
    expected ??= ["null", "String", "List<String>"];
    return "QuickListenerTypeError: QuickListener input must be one of three types: ${expected!.join(", ")}.\nExpected: ${expected!.join(" | ")}\nGot: $got";
  }
}

/// Define a [QuickListener] to either listen, broadcast, or close a key's stream.
///
/// [QuickListener]'s don't carry state. If you call `QuickListener("MyKey").done()`, it'll close all listeners of that key, no matter what object it's on.
///
/// The only held state is the stream subscription created when [listen] is called, but this is disposed of cleanly when [done] is called on the key.
///
/// The [T] input is optional and is only for defining a type in [listen]'s [onData] input, so that the data is easier to work with.
class QuickListener<T> {
  /// The input given when the object is initialized.
  ///
  /// This must be a [String], [List<String>], or [null] value; otherwise, a [QuickListenerTypeError] is thrown.
  dynamic key;

  /// The list that contains the keys for the object.
  ///
  /// This is null if the input is null.
  ///
  /// If the input is just one string, then this is set to an array with only that one string.
  List<String>? keys;

  // This is added to for each [listen] that's called.
  final List<StreamSubscription> _subscriptions = [];

  /// Constructor for [QuickListener]. [key] is optional and defaults to [null].
  QuickListener([this.key]) {
    if (key == null) {
      keys = null;
    } else if (key is List) {
      if (key is List<String>) {
        keys = key;
      } else {
        throw QuickListenerTypeError(
          got: key.runtimeType,
          expected: ["List<String>"],
        );
      }
    } else if (key is String) {
      keys = [key];
    } else {
      throw QuickListenerTypeError(got: key.runtimeType);
    }

    _initialize();
  }

  /// Start listening to the keys specified.
  ///
  /// If you specified one key, it'll listen to that one key. If you specified multiple keys, it'll listen to all of your specified keys. If you didn't specify a key, it'll listen for anything.
  QuickListener listen(
    void Function(T data)? onData, {
    void Function(Object error)? onError,
    void Function()? onDone,
  }) {
    _subscriptions.add(
      _controller.stream.listen(
        (QuickListenerEvent input) {
          QuickListenerEventType event = input.event!;

          if (input.keys != null &&
              keys != null &&
              !input.keys!.any((element) => keys!.contains(element))) {
            return;
          }

          if (event == QuickListenerEventType.error) {
            if (onError != null) onError(input.data as Object);
            return;
          }
          if (event == QuickListenerEventType.done) {
            for (String key in keys!) {
              _keys.remove(key);
            }

            _dispose();
            return;
          }

          if (onData != null) onData(input.data);
        },
        cancelOnError: false,
        onError: (Object e) => throw e,
      ),
    );

    return this;
  }

  /// Broadcast any input to the specified key(s). If the specified key is not provided, it'll broadcast to all keys.
  ///
  /// [input] is sent as an error (thus triggering a listener's [onError]) when [input] can be classified as an [Error] or [Exception]. To manually override this, you can input a [QuickListenerData] object instead.
  QuickListener broadcast(dynamic input) {
    if (input is! QuickListenerData) {
      if (_isError(input)) {
        input = QuickListenerData.error(input);
      } else {
        input = QuickListenerData(input);
      }
    }

    try {
      if (input._error == true) throw Exception();
      _controller.sink.add(
        input._done == true
            ? QuickListenerEvent.done(keys: keys)
            : QuickListenerEvent(data: input.data, keys: keys),
      );
    } catch (e) {
      Object error = e;
      if (input._error == true) error = input.error!;

      try {
        _controller.sink.add(
          QuickListenerEvent(
            data: error,
            event: QuickListenerEventType.error,
            keys: keys,
          ),
        );
      } catch (_) {
        throw error;
      }
    }

    return this;
  }

  /// Closes down the key by removing it and its state, and disposing of all the listeners. It can be readded back later.
  void done() {
    broadcast(QuickListenerData.done());
  }

  // Remove each listener.
  void _dispose() {
    for (StreamSubscription subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  // Make sure each key's state exists in [_keys].
  void _initialize() {
    for (String key in (keys ?? [])) {
      if (!_keys.contains(key)) {
        _keys.add(key);
      }
    }
  }
}

/// An event object that is sent to the [_controller] by [broadcast].
class QuickListenerEvent {
  /// The event type being sent.
  QuickListenerEventType? event;

  /// The data being sent along with the event.
  dynamic data;

  /// The key(s) affected. Null if all.
  List? keys;

  /// The constructor for [QuickListenerEvent]. [event] defaults to [QuickListenerEventType.data], and [data] and [keys] are required.
  QuickListenerEvent({
    this.event = QuickListenerEventType.data,
    required this.data,
    required this.keys,
  });

  /// Simply sets [event] to [QuickListenerEventType.done]. [keys] is required.
  QuickListenerEvent.done({required this.keys}) {
    event = QuickListenerEventType.done;
  }
}

/// This is used for an easy way of transmitting data, errors, or "done" signals. You can input this into [QuickListener.broadcast] to override the default method, which is using any [Error] or [Exception] as an error.
class QuickListenerData {
  /// The included data in the base [QuickListenerData].
  dynamic data;

  /// The included error when an error is used.
  Object? error;

  bool _error = false; // True if an error is used.
  bool _done = false; // True if the done signal is used.

  /// The base constructor for [QuickListenerData]. [data] is required.
  ///
  /// This just sends a normal event.
  QuickListenerData(this.data);

  /// The error constructor for [QuickListenerData]. [error] is required.
  ///
  /// This sends an error instead of a normal event. [error] is an [Object?].
  QuickListenerData.error(this.error) {
    _error = true;
  }

  /// The done constructor for [QuickListenerData]. This sends the "done" event. It doesn't have any parameters.
  QuickListenerData.done() {
    _done = true;
  }
}
