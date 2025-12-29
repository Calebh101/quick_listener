/// Main library for QuickListener.
library;

import 'dart:async';

List<String> _keys = []; // Active keys
bool _debugMode = false; // Debug mode
final Map<int, BroadcastBarrier> _broadcastBarriers = {}; // Broadcast barriers active

int _nodeIdCounter = 0;
int _nextNodeId() => ++_nodeIdCounter;

int _broadcastIdCounter = 0;
int _nextBroadcastId() => ++_broadcastIdCounter;

StreamController<QuickListenerEvent> _controller = StreamController.broadcast(); // Main stream
StreamController<QuickListenerResponse> _responseController = StreamController.broadcast(); // A stream that only controls responses

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

/// A class to handle broadcasts and completions.
class BroadcastBarrier {
  /// The amount of listeners that still need to respond.
  int remaining;

  /// If the broadcast has been sent to listeners.
  bool broadcastFinished = false;

  /// This is completed when there are 0 listeners remaining.
  final Completer<void> completer = Completer<void>();

  /// A class to handle broadcasts and completions.
  BroadcastBarrier() : remaining = 0;

  /// This is called when a listener has received the broadcast.
  void received(int id) {
    remaining++;
  }

  /// This is called when a listener has finished the broadcast.
  void signal(int id) {
    remaining--;
    _tryComplete();
  }

  /// This is called by the broadcasting node to tell the barrier that the broadcast has been sent.
  void finishBroadcast() {
    broadcastFinished = true;
    _tryComplete();
  }

  // Complete if the required conditions are met.
  void _tryComplete() {
    if (broadcastFinished && remaining == 0 && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  String toString() {
    return "BroadcastBarrier(remaining: $remaining, completed: ${completer.isCompleted})";
  }
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

/// Define a [QuickListener] to either listen, broadcast, or close a key's stream.
///
/// [QuickListener]'s don't contain stream controllers. If you call [QuickListener.done], it'll close all listeners of that key, no matter what object it's using.
///
/// The only held state is the stream subscription created when [listen] is called, but this is disposed of cleanly when [done] is called on the key.
class QuickListener {
  /// The key associated with this [QuickListener].
  ///
  /// If this is null, it's associated with *all* keys.
  final String? key;

  /// The ID of this listener.
  final int id;

  // This is added to for each [listen] that's called.
  final List<StreamSubscription> _subscriptions = [];

  /// Define a [QuickListener] to either listen, broadcast, or close a key's stream.
  ///
  /// [QuickListener]'s don't contain stream controllers. If you call [QuickListener.done], it'll close all listeners of that key, no matter what object it's using.
  ///
  /// The only held state is the stream subscription created when [listen] is called, but this is disposed of cleanly when [done] is called on the key.
  QuickListener([this.key]) : id = _nextNodeId() {
    _initialize();
  }

  @override
  String toString() {
    return "QuickListener(key: $key)";
  }

  // This function isn't called directly; it's used to generate a function for the user to call to send a response.
  void Function([dynamic input]) _respond(bool error, int bid) {
    return ([dynamic input]) {
      _responseController.add(QuickListenerResponse(key, input, error));
    };
  }

  /// Start listening to the keys specified.
  ///
  /// If you specified one key, it'll listen to that one key. If you specified multiple keys, it'll listen to all of your specified keys. If you didn't specify any keys, it'll listen for anything.
  ///
  /// When data is received, it is only passed into [onData] if it is an instance of [T].
  QuickListener listen<T>(
    FutureOr<void> Function(T? data, void Function([dynamic input]) respond)? onData, {
    FutureOr<void> Function(Object error, void Function([dynamic input]) respond)? onError,
    FutureOr<void> Function(Object error)? onStreamError,
    FutureOr<void> Function()? onDone,
  }) {
    _subscriptions.add(
      _controller.stream.listen(
        (QuickListenerEvent input) async {
          _broadcastBarriers[input.id]?.received(id);
          QuickListenerEventType event = input.type;

          if (key != null && input.key != null && key != input.key) {
            return;
          }

          try {
            if (event == QuickListenerEventType.error && input.error != null) {
              await onError?.call(input.error!, _respond(true, input.id));
            } else if (event == QuickListenerEventType.done) {
              await onDone?.call();
              await _done();
            } else {
              await onData?.call(
                input.data is T ? input.data : null,
                _respond(false, input.id),
              );
            }
          } finally {
            final barrier = _broadcastBarriers[input.id];
            barrier?.signal(id);
          }
        },
        cancelOnError: false,
        onError: onStreamError ?? (_) {},
      ),
    );

    return this;
  }

  /// Broadcast any input to the specified key(s). If a specified key(s) is not provided, it'll broadcast to all keys.
  ///
  /// [input] is sent as an error (thus triggering a listener's [StreamSubscription.onError]) when [input] can be classified as an [Error] or [Exception]. To manually override this, you can input a [QuickListenerData] object instead.
  Future<QuickListener> broadcastAndWait([dynamic input]) async {
    final bid = _nextBroadcastId();
    final barrier = BroadcastBarrier();

    _broadcastBarriers[bid] = barrier;
    _broadcast(bid, input);
    _debug("Broadcasting broadcast $bid from node $key");
    barrier.finishBroadcast();

    await barrier.completer.future.whenComplete(() {
      _broadcastBarriers.remove(bid);
    });

    _debug("After broadcast, barrier: $barrier");
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
        input._done == true ? QuickListenerEvent.done(
              key: key,
              id: id,
        ) : QuickListenerEvent(
          data: input.data,
          error: null,
          key: key,
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
            key: key,
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
    final result = timeout == null ? await stream.first : await stream.first.timeout(timeout);
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
    final result = timeout == null ? await stream.first : await stream.first.timeout(timeout);
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
      final value = response.key;
      final target = key;

      if (value == null || target == null || value == target) {
        if (!completer.isCompleted) completer.complete(response);
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

  // Dispose of all subscriptions and keys.
  Future<void> _done() async {
    if (key != null) {
      _keys.remove(key);
    } else if (_keys.isNotEmpty) {
      _keys.clear();
    }

    await dispose();
  }

  /// This removes all listeners on this **instance**. This is different from [done] in that it only disposes subscriptions of this listener, but [done] repeats this for *every* listener *and* removes the key(s) specified.
  Future<void> dispose() async {
    if (_subscriptions.isNotEmpty) await Future.wait(_subscriptions.map((x) => x.cancel()));
    _subscriptions.clear();
  }

  /// Closes down the key by removing it and its state, and disposing of all the listeners. It can be re-added later.
  Future<void> done() async {
    await broadcastAndWait(QuickListenerData.done());
    await _done();
  }

  // Make sure each key's state exists in [_keys].
  void _initialize() {
    if (key != null && !_keys.contains(key)) {
      _keys.add(key!);
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
  final String? key;

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
    required this.key,
    required this.id,
  });

  /// Simply sets [type] to [QuickListenerEventType.done].
  QuickListenerEvent.done({required this.key, required this.id}) : type = QuickListenerEventType.done, data = null, error = null;

  @override
  String toString() {
    return "QuickListenerEvent(key: $key, type: $type, data: $data)";
  }
}

/// This is used for an easy way of transmitting data, errors, or "done" signals.
/// You can input this into [QuickListener.broadcast] to override the default method, which is using any [Error] or [Exception] as an error.
class QuickListenerData {
  /// The included data in the base [QuickListenerData].
  final dynamic data;

  /// The included error when an error is signaled.
  final Object? error;

  // True if an error is signaled.
  final bool _error;

  // True if the done signal is signaled.
  final bool _done;

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
  QuickListenerData.done() : data = null, error = null, _error = false, _done = true;

  @override
  String toString() {
    return "QuickListenerData(type: ${_done ? "Done" : (_error ? "Error" : "Data")}, data: $data, error: $error)";
  }
}

/// A response for a data event or error event from any listeners.
///
/// This can optionally contain data.
class QuickListenerResponse {
  /// The key associated with this response.
  final String? key;

  /// The optional data/error associated with this response.
  final dynamic input;

  /// Whether [input] should be treated as an error or not.
  final bool error;

  /// A response for a data event or error event from any listeners.
  ///
  /// This can optionally contain data.
  const QuickListenerResponse(this.key, this.input, this.error);

  @override
  String toString() {
    return "QuickListenerResponse(input: $input, error: $error)";
  }
}
