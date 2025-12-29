<h1 style="text-align: center;">QuickListener</h1>
<p style="text-align: center;">A Dart package to make setting up streams and stream subscriptions a lot simpler.</p>

Ever wanted to be able to broadcast messages to other, unrelated parts of your code without setting up stream controllers, stream subscriptions, and all that blah? This package simplifies the process by using a key-based system to separate different listeners, instead of using an object-based system. You don't have to set any global variables or subscriptions, as it's all managed by the package.

This is similar to the `Broadcast Message` action in [Scratch](https://scratch.mit.edu), the beginner visual code editor. There are no states to manually handle, scopes don't matter, and it takes as little as 1 line of code to broadcast a message, and another 1 line of code to receive it.

This is useful for times when you have a state change in one section of your code and you want to trigger an update in another, or when you just want to notify your Flutter widgets of new data.

**Note**: This package is still in beta and is currently being tested. Don't expect this to work properly until it exits beta.

# Usage

## The Basics

"Keys" in this sense are string identifiers to separate different streams. If you listen to a null key, then the listener will trigger for any input broadcasted. If you broadcast with a null key, then it will trigger any listener regardless of the key they're listening to.

This package is made to be as simple and fluid as possible. When you define an object (using `QuickListener()`) it doesn't immediately define any new states, it simply acts as a communicator with the key.

## How to create the object

You can either set the object as a variable and use it later/several times, or create the object inline and use the function(s) directly. For example:

```dart
// Set it as a variable
QuickListener listener = QuickListener("MyKey");
listener.listen<String>((String? data, respond) => print("$data"));
listener.broadcast("Hello, world!");

// Use it inline
QuickListener("MyKey").listen<String>((String? data, respond) => print("$data")).broadcast("Hello, world!");
```

Because `listen()` and `broadcast()` return the object itself, you can chain commands easily, as seen above.

To define an object, you have several options.

```dart
QuickListener listener = QuickListener("MyKey"); // Listens/broadcasts to one key. The listener will also trigger if a null key is broadcasted.

QuickListener listener = QuickListener(); // Listens to all keys and broadcasts to null keys.

QuickListener listener = QuickListener(null); // Same as not including a key at all.
```

## Broadcasting

Syntax:

```dart
QuickListener(key).broadcast(data);
```

`data` can be any value, or you can even not include it if you don't have data to send.

If you don't include a key in the object, it'll broadcast to all keys. If you have a list of keys, it'll broadcast to all keys in that list.

If `data` is an `Error` or `Exception`, then an error will be broadcasted and `onError` will be called instead of `onData` in the listeners. If you want to override it, you can use the manual data override method (see below).

You can manually override the input data by passing in a `QuickListenerData` object. There are three different types of this object:

- `QuickListenerData(data)`: Inputs data, no matter the input. Useful for broadcasting an error as plain data, so it doesn't trigger `onError`.
- `QuickListenerData.error(error)`: Sends an error no matter the input. The input must be of type `Object?`, unlike the base `QuickListenerData(data)` which is `dynamic`.
- `QuickListenerData.done()`: This is the same as calling `QuickListener().done()`. This is never auto-sent based on input.

You can also call `broadcastAndWait`, which will wait until all the listeners have received and processed the response. **This is different from responding**, in that it waits until the listeners' callbacks completely exit.

## Listening

Syntax:

```dart
QuickListener().listen<T>(onData, onError: onError, onDone: onDone);
```

`onData` is a required callback of `FutureOr<void> Function(dynamic data, void Function([dynamic input]) respond)?`. `data` is whatever is passed into the `broadcast`.

`onError` is an optional named callback of `FutureOr<void> Function(Object error, void Function([dynamic input]) respond)?`. `error` is the passed error or exception, but it can be any `Object?` if the override method is used in the `broadcast`.

`onDone` is an optional named callback of `FutureOr<void> Function()`. This is called when the key is marked as done. **This is not called when the listener alone is disposed.

`onStreamError` is an optional named callback of type `FutureOr<void> Function(Object error)?` that is called when the `StreamSubscription` errors. This is different from `onError`. The default of this is ignore.

The `T` is only used as a runtime check. If the received data is not of type `T`, `onData` is still called, but its data will be null.

You can also use some asynchronous methods:

- `waitForNewData`: Same as `listen.onData`, but returns when new data has arrived. This does **not** include errors or done signals.
- `waitForNewEvent`: Same as `waitForNewData`, but returns the entire event, which also includes errors or done signals. (Neither of these include stream errors though.)
- `waitForResponse`: Wait for a callback to respond to a broadcast. **This is done manually; callbacks must call `respond` to trigger this.** Otherwise, this hangs forever, or times out if specified.

## Finishing

Syntax:

```dart
QuickListener().done();
```

This broadcasts the `done` event, which removes the key(s) and disposes of the listeners, after triggering their `onDone`s. With this, all listeners with the key sent is closed, and the key is removed from the active keys list. It does take some time to close all listeners, due to the nature of broadcasting. However, you can await this if needed.

**Warning**: Using this on a null key cancels all active keys.

You can also dispose a single listener by using `QuickListener.dispose`. This just removes all listeners of that *instance*, not key.