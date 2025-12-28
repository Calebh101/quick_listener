# QuickListener - The Quick Way to Listen

Ever wanted to be able to broadcast messages to other, unrelated parts of your code without setting up stream controllers, stream subscriptions, and all that blah? This package simplifies the process by using a key-based system to separate different listeners, instead of using an object-based system. You don't have to set any global variables or subscriptions, as it's all managed by the package.

This is similar to the `Broadcast Message` action in [Scratch](https://scratch.mit.edu), the beginner visual code editor. There are no states to manually handle, scopes don't matter, and it takes as little as 1 line of code to broadcast a message, and another 1 line of code to receive it.

This is useful for times when you have a state change in one section of your code and you want to trigger an update in another, or when you just want to notify your Flutter widgets of new data.

**Note**: This package is still in beta and is currently being tested. Don't expect this to work properly until it exits beta.

# Usage

## The Basics

"Keys" in this sense are string identifiers to separate different streams. If you listen to a null key, then the listener will trigger for any input broadcasted. If you broadcast with a null key, then it will trigger any listener regardless of the key they're listening to.

This package is made to be as simple and fluid as possible. When you define an object (using `QuickListener()`) it doesn't define any new states, it simply acts as a communicator with the key.

## How to create the object

You can either set the object as a variable and use it later/several times, or create the object inline and use the function(s) directly. For example:

```dart
// Set it as a variable
QuickListener listener = QuickListener("MyKey");
listener.listen<String>((String? data) => print("$data"));
listener.broadcast("Hello, world!");

// Use it inline
QuickListener("MyKey").listen<String>((String? data) => print("$data"));
```

Because `listen()` and `broadcast()` return the object itself, you can chain commands easily:

```dart
QuickListener("MyKey").listen<String>((String? data) => print("$data")).broadcast("Hello, world!");
```

To define a key or multiple keys in an object, you have several options.

```dart
QuickListener listener = QuickListener("MyKey"); // Listens/broadcasts to one key. The listener will also trigger if a null key is broadcasted.

QuickListener listener = QuickListener(["MyKey", "MySecondKey"]); // Listens/broadcasts to several keys. The listener will trigger if any of keys included is broadcasted, or a null key is broadcasted.

QuickListener listener = QuickListener(); // Listens to all keys and broadcasts to null keys.

QuickListener listener = QuickListener(null); // Same as not including a key at all.
```

You can only include a `String`, `List<String>`, or `null` value in the initializer; otherwise a QuickListenerTypeError will be thrown.

If you prefer stricter typing than this, there are 3 extra factory constructors:

```dart
// Same as QuickListener(null); however, no arguments are accepted.
QuickListener.all();

// Same as QuickListener("MyKey"); however, QuickListener.single *requires* a String.
QuickListener.single("MyKey");

// Same as QuickListener(["MyKey", "MyOtherKey"]); however, QuickListener.all *requires* a List<String>.
QuickListener.multiple(["MyKey", "MyOtherKey"]);
```

## Broadcasting

Syntax:

```dart
QuickListener().broadcast(data);
```

`data` can be any value, or you can even not include it if you don't have data to send.

If you don't include a key in the object, it'll broadcast to all keys. If you have a list of keys, it'll broadcast to all keys in that list.

If `data` is an `Error` or `Exception`, then an error will be broadcasted and `onError` will be called instead of `onData` in the listeners. If you want to override it, you can use the manual data override method.

You can manually override the input data by passing in a `QuickListenerData` object. There are three different types of this object:
- `QuickListenerData(data)`: Inputs data, no matter the input. Useful for broadcasting an error as plain data, so it doesn't trigger `onError`.
- `QuickListenerData.error(error)`: Sends an error no matter the input. The input must be of type `Object?`, unlike the base `QuickListenerData(data)` which is `dynamic`.
- `QuickListenerData.done()`: This is the same as calling `QuickListener().done()`. This is never auto-sent based on input.

## Listening

Syntax:

```dart
QuickListener().listen<T>(onData, onError: onError, onDone: onDone);
```

`onData` is a required callback of `void Function(dynamic data)?`. `data` is whatever is passed into the `broadcast`.

`onError` is an optional named callback of `void Function(Object error)?`. `error` is the passed error or exception, but it can be any `Object?` if the override method is used in the `broadcast`.

`onDone` is an optional named callback of `void Function()?`. It is called when the `done` event is passed and the key/keys is disposed of.

The `T` is only used as a runtime check. If the received data is not of type `T`, `onData` is still called, but its data will be null.

## Finishing

Syntax:

```dart
QuickListener().done();
```

This broadcasts the `done` event, which removes the key(s) and disposes of the listeners, after triggering their `onDone`s. You can call `QuickListener().done()` instead, which is just a shortcut to broadcasting the `done` event.

All listeners with *any* of the keys sent with the `done` event gets closed.

It does take some time to close all listeners, due to the nature of broadcasting.

**Warning**: Using these on a null key cancels all active keys.

# Errors and Exceptions

- `QuickListenerTypeError` is called when the wrong type is inputted as a key in `QuickListener`. `QuickListener` keys only accept a `String`, `List<String>`, or `null` input.