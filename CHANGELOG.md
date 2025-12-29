## 0.0.0 - 6/16/25

- Initial beta release.

## 0.0.1 - 12/28/25

I finally remembered this existed after some time. I've made a *lot* of changes (see the partly-redone readme), so I'll only list breaking changes.

- `QuickListener` no longer accepts multiple keys. This also gets rid of its dynamic input.
- `QuickListener` no longer accepts a type input. Only `QuickListener.listen` does.
- `QuickListener.listen`'s `onData` and `onError` now have new `void Function([dynamic input]) respond` parameters.
- `QuickListenerEvent.event` is deprecated. Use `QuickListenerEvent.type` instead.

There are probably a lot more changes that I'm forgetting; it's probably worth reading over the readme. Reminder that this is still in beta.