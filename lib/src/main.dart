/// Main library for QuickListener.
library;

import 'dart:async';

List<String> _keys = [];
bool _debugMode = false;

int _nodeIdCounter = 0;
int _nextNodeId() => ++_nodeIdCounter;

int _broadcastIdCounter = 0;
int _nextBroadcastId() => ++_broadcastIdCounter;

final Map<int, BroadcastBarrier> _broadcastBarriers = {};
final Map<int, int> _listenerCounts = {};

StreamController<QuickListenerEvent> _controller = StreamController.broadcast();
StreamController<QuickListenerResponse> _responseController =
    StreamController.broadcast();

class BroadcastBarrier {
  int remaining;
  final Completer<void> completer = Completer<void>();

  BroadcastBarrier(this.remaining);

  void signal() {
    remaining--;
    if (remaining <= 0 && !completer.isCompleted) completer.complete();
  }
}

/// Get all keys currently active.
///
/// If a key is disposed of (using [QuickListener.done]), then it will be deactivated from the state and will not be listed here.
List<String> getAllQuickListenerKeys() {
  return _keys;
}

/// Enable debug logs or actions for QuickListener.
void enableQuickListenerDebugMode() {
  _debugMode = true;
  _debug("Debug mode enabled");
}

// Debug log function.
void _debug(Object? input) {
  if (_debugMode) print("[QuickListener] [${DateTime.now().toUtc()}] $input");
}

// Checks if the inputted object can be classified as an [Error] or [Exception].
bool _isError(Object? object) {
  return object is Error || object is Exception;
}

/// A specifier for the type of [QuickListenerEvent].
enum QuickListenerEventType {
  /// Normal event.
  data,

  /// Error event.
  error,

  /// Dispose event.
  done,
}

/// Called when a developer inputs an improper input for QuickListener's key/list of keys.
class QuickListenerTypeError extends TypeError {
  /// The type(s) expected.
  List<String>? expected;

  /// The type received.
  Type got;

  /// Called when a developer inputs an improper input for QuickListener's key/list of keys.
  QuickListenerTypeError({this.expected, required this.got});

  /// A string representation of this error.
  ///
  /// Shows the expected type(s), the received type, and a message to go along with it.
  @override
  String toString() {
    expected ??= ["null", "String", "List<String>"];
    return "QuickListenerTypeError: QuickListener input must be 1 of ${expected!.length} types: ${expected!.join(", ")}.\nExpected: ${expected!.join(" | ")}\nGot: $got";
  }
}

/// Define a [QuickListener] to either listen, broadcast, or close a key's stream.
///
/// [QuickListener]'s don't contain stream controllers. If you call [QuickListener.done], it'll close all listeners of that key, no matter what object it's using.
///
/// The only held state is the stream subscription created when [listen] is called, but this is disposed of cleanly when [done] is called on the key.
class QuickListener {
  /// The list that contains the keys for the object.
  ///
  /// This is null if the input is null.
  ///
  /// If the input is just one string, then this is set to an array with only that one string.
  List<String>? keys;

  final int id;

  // This is added to for each [listen] that's called.
  final List<StreamSubscription> _subscriptions = [];

  /// Define a [QuickListener] to either listen, broadcast, or close a key's stream.
  ///
  /// [QuickListener]'s don't contain stream controllers. If you call [QuickListener.done], it'll close all listeners of that key, no matter what object it's using.
  ///
  /// The only held state is the stream subscription created when [listen] is called, but this is disposed of cleanly when [done] is called on the key.
  QuickListener([Object? key]) : id = _nextNodeId() {
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

  /// Copy of [QuickListener.new], but more type-safe.
  /// This one is specifically for all keys to be enabled.
  factory QuickListener.all() {
    return QuickListener();
  }

  /// Copy of [QuickListener.new], but more type-safe.
  /// This one is specifically for [key] as a [String].
  factory QuickListener.single(String key) {
    return QuickListener(key);
  }

  /// Copy of [QuickListener.new], but more type-safe.
  /// This one is specifically for [key] as a `List<String`.
  factory QuickListener.multiple(List<String> key) {
    return QuickListener(key);
  }

  @override
  String toString() {
    return "QuickListener(keys: $keys)";
  }

  // This function isn't called directly; it's used to generate a function for the user to call to send a response.
  void Function([dynamic input]) _respond(bool error) {
    return ([dynamic input]) {
      _responseController.add(QuickListenerResponse(keys, input, error));
    };
  }

  void _addListener([bool remove = false]) {
    _listenerCounts.update(
      id,
      (value) => value <= 0 && remove ? 0 : (value + (remove ? -1 : 1)),
      ifAbsent: () => remove ? 0 : 1,
    );
  }

  /// Start listening to the keys specified.
  ///
  /// If you specified one key, it'll listen to that one key. If you specified multiple keys, it'll listen to all of your specified keys. If you didn't specify any keys, it'll listen for anything.
  ///
  /// When data is received, it is only passed into [onData] if it is an instance of [T].
  QuickListener listen<T>(
    FutureOr<void> Function(T? data, void Function([dynamic input]) respond)?
    onData, {
    FutureOr<void> Function(
      Object error,
      void Function([dynamic input]) respond,
    )?
    onError,
    FutureOr<void> Function(Object error)? onStreamError,
  }) {
    _addListener();
    _debug("Found ${_listenerCounts[id]} listeners for ID $id");

    _subscriptions.add(
      _controller.stream.listen(
        (QuickListenerEvent input) async {
          QuickListenerEventType event = input.type;

          if (input.keys != null &&
              keys != null &&
              !input.keys!.any((element) => keys!.contains(element))) {
            return;
          }

          try {
            if (event == QuickListenerEventType.error && input.error != null) {
              await onError?.call(input.error!, _respond(true));
              return;
            }

            if (event == QuickListenerEventType.done) {
              if (input.keys != null) {
                for (var x in input.keys!) {
                  keys?.remove(x);
                }
              } else {
                keys?.clear();
              }

              if (keys != null && keys!.isEmpty) {
                await done();
              }
            }

            await onData?.call(
              input.data is T ? input.data : null,
              _respond(false),
            );
          } finally {
            _broadcastBarriers[input.id]?.signal();
          }
        },
        cancelOnError: false,
        onError: onStreamError ?? (e) {},
      ),
    );

    return this;
  }

  /// Broadcast any input to the specified key(s). If a specified key(s) is not provided, it'll broadcast to all keys.
  ///
  /// [input] is sent as an error (thus triggering a listener's [StreamSubscription.onError]) when [input] can be classified as an [Error] or [Exception]. To manually override this, you can input a [QuickListenerData] object instead.
  Future<QuickListener> broadcastAndWait([dynamic input]) async {
    final bid = _nextBroadcastId();
    final count = _listenerCounts[bid] ?? 0;
    final barrier = BroadcastBarrier(count);

    _broadcastBarriers[bid] = barrier;
    _broadcast(bid, input);
    _debug("Broadcasting broadcast $bid from node $id");

    await barrier.completer.future.whenComplete(() {
      _broadcastBarriers.remove(bid);
    });

    return this;
  }

  /// Broadcast any input to the specified key(s). If a specified key(s) is not provided, it'll broadcast to all keys.
  ///
  /// [input] is sent as an error (thus triggering a listener's [StreamSubscription.onError]) when [input] can be classified as an [Error] or [Exception]. To manually override this, you can input a [QuickListenerData] object instead.
  ///
  /// This version simply calls [broadcastAndWait] and immediately returns.
  QuickListener broadcast([dynamic input]) {
    broadcastAndWait(input);
    return this;
  }

  /// Broadcast any input to the specified key(s). If a specified key(s) is not provided, it'll broadcast to all keys.
  ///
  /// [input] is sent as an error (thus triggering a listener's [StreamSubscription.onError]) when [input] can be classified as an [Error] or [Exception]. To manually override this, you can input a [QuickListenerData] object instead.
  QuickListener _broadcast(int id, dynamic input) {
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
            ? QuickListenerEvent.done(keys: keys, id: id)
            : QuickListenerEvent(
                data: input.data,
                error: null,
                keys: keys,
                id: id,
              ),
      );
    } catch (e) {
      Object error = e;
      if (input._error == true) error = input.error!;

      try {
        _controller.sink.add(
          QuickListenerEvent(
            data: null,
            error: error,
            type: QuickListenerEventType.error,
            keys: keys,
            id: id,
          ),
        );
      } catch (_) {
        throw error;
      }
    }

    return this;
  }

  // Return a stream using `_controller` targeting the specified `QuickListenerEventType`.
  Stream<QuickListenerEvent> _getStream([
    List<QuickListenerEventType>? targets,
  ]) {
    return _controller.stream.where((x) {
      if (targets == null) return true;
      return targets.contains(x.type);
    });
  }

  /// Wait for new data. This is an asynchronous version of [QuickListener.listen].
  ///
  /// No error or done signal will be returned here.
  ///
  /// Timeouts are uncaught.
  Future<QuickListenerEvent> waitForNewData({Duration? timeout}) async {
    final stream = _getStream([QuickListenerEventType.data]);
    final result = timeout == null
        ? await stream.first
        : await stream.first.timeout(timeout);
    return result;
  }

  /// Wait for a new event. This is an asynchronous version of [QuickListener.listen].
  ///
  /// All signals will be returned here.
  ///
  /// Timeouts are uncaught.
  Future<QuickListenerEvent> waitForNewEvent({
    Duration? timeout,
    List<QuickListenerEventType> events = QuickListenerEventType.values,
  }) async {
    final stream = _getStream(events);
    final result = timeout == null
        ? await stream.first
        : await stream.first.timeout(timeout);
    return result;
  }

  /// Wait for a listener to respond. This is helpful for cross-state asynchronous tasks.
  ///
  /// If a listener never calls `respond`, this will never return, unless [timeout] is specified.
  ///
  /// Timeouts are uncaught.
  Future<QuickListenerResponse> waitForResponse({Duration? timeout}) {
    final completer = Completer<QuickListenerResponse>();
    late StreamSubscription subscription;

    subscription = _responseController.stream.listen((response) {
      final values = response.keys;
      final set = keys?.toSet();

      if (values == null || set == null || values.any(set.contains)) {
        completer.complete(response);
        subscription.cancel();
      }
    });

    if (timeout != null) {
      Future.delayed(timeout).then((_) {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.completeError(TimeoutException("waitForResponse"));
        }
      });
    }

    return completer.future;
  }

  /// Closes down the key by removing it and its state, and disposing of all the listeners. It can be re-added later.
  ///
  /// [referencedFromStream] is for internal use only.
  Future<void> done([bool referencedFromStream = false]) async {
    for (String key in keys ?? []) {
      _keys.remove(key);
    }

    if (_subscriptions.isNotEmpty)
      await Future.wait(_subscriptions.map((x) => x.cancel()));
    _subscriptions.clear();
    _addListener(true);
    _debug("Found ${_listenerCounts[id]} listeners for ID $id");

    if (!referencedFromStream) {
      await broadcastAndWait(QuickListenerData.done());
    }
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

/// An event object that is sent to the main controller via [QuickListener.broadcast].
class QuickListenerEvent {
  /// The event type being sent.
  final QuickListenerEventType type;

  /// The data being sent along with the event.
  final dynamic data;

  /// The optional error being sent along with the event.
  final Object? error;

  /// The key(s) affected. Null if all.
  final List? keys;

  /// ID of the broadcasting node.
  final int id;

  /// The event type being sent.
  ///
  /// This is deprecated, due to unclear naming. Use [QuickListenerEvent.type] instead.
  @Deprecated("Use type instead.")
  QuickListenerEventType? get event => type;

  /// An event object that is sent to the main controller via [QuickListener.broadcast].
  QuickListenerEvent({
    this.type = QuickListenerEventType.data,
    QuickListenerEventType? event,
    required this.data,
    required this.error,
    required this.keys,
    required this.id,
  });

  /// Simply sets [type] to [QuickListenerEventType.done].
  QuickListenerEvent.done({required this.keys, required this.id})
    : type = QuickListenerEventType.done,
      data = null,
      error = null;

  @override
  String toString() {
    return "QuickListenerEvent(keys: $keys, type: $type, data: $data)";
  }
}

/// This is used for an easy way of transmitting data, errors, or "done" signals.
/// You can input this into [QuickListener.broadcast] to override the default method, which is using any [Error] or [Exception] as an error.
class QuickListenerData {
  /// The included data in the base [QuickListenerData].
  final dynamic data;

  /// The included error when an error is used.
  final Object? error;

  final bool _error; // True if an error is used.
  final bool _done; // True if the done signal is used.

  /// This is used for an easy way of transmitting data, errors, or "done" signals.
  /// You can input this into [QuickListener.broadcast] to override the default method, which is using any [Error] or [Exception] as an error.
  QuickListenerData(this.data) : error = null, _error = false, _done = false;

  /// This is used for an easy way of transmitting data, errors, or "done" signals.
  /// You can input this into [QuickListener.broadcast] to override the default method, which is using any [Error] or [Exception] as an error.
  ///
  /// This sends an error instead of a regular data event.
  QuickListenerData.error(this.error)
    : data = null,
      _error = true,
      _done = false;

  /// This is used for an easy way of transmitting data, errors, or "done" signals.
  /// You can input this into [QuickListener.broadcast] to override the default method, which is using any [Error] or [Exception] as an error.
  ///
  /// This sends a done signal instead of a regular data event.
  QuickListenerData.done()
    : data = null,
      error = null,
      _error = false,
      _done = true;

  @override
  String toString() {
    return "QuickListenerData(type: ${_done ? "Done" : (_error ? "Error" : "Data")}, data: $data, error: $error)";
  }
}

/// A response for a data event or error event from any listeners.
///
/// This can optionally contain data.
class QuickListenerResponse {
  final List<String>? keys;
  final dynamic input;
  final bool error;

  /// A response for a data event or error event from any listeners.
  ///
  /// This can optionally contain data.
  const QuickListenerResponse(this.keys, this.input, this.error);

  @override
  String toString() {
    return "QuickListenerResponse(input: $input, error: $error)";
  }
}
