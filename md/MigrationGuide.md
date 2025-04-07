# 📦 FullyRESTful 3.0.0 Migration Guide

This guide helps you migrate from version `2.x` to `3.0.0`, especially for **WebSocket** usage.

---

## ❗ What's Changed?

The WebSocket system has been **entirely restructured**:
- Removed `WebSocketAPIITEM` and `TopicITEM`
- Introduced a simpler protocol-based model: `WebSocketITEM`
- New WebSocket lifecycle management using Combine publishers
- Automatic connection sharing and lifecycle tracking via `WebSocketManager`

---

## ✅ Before (v2.x Style)

```swift
class WebSocketEcho: WebSocketAPIITEM {
    var server = ...
    var path = ""
}

let topic = WebSocketEcho().makeTopic(name: "echo")

topic.listen()
    .sink(receiveValue: { message in print(message) })
    .store(in: &cancellables)

try await topic.send(message: .text("Hello"))
```

---

## ✅ After (v3.0.0+ Style)

```swift
struct EchoSocket: WebSocketITEM {
    var server = ServerInfo(domain: "wss://echo.websocket.org", defaultHeader: [:])
    var path: String = ""
}

let item = EchoSocket()

item.listen()
    .sink { message in print(message) }
    .store(in: &cancellables)

try await item.send(.text("Hello"))
```

---

## 🔄 How to Migrate

1. **Replace** any `WebSocketAPIITEM` and `TopicITEM` usage with `WebSocketITEM`.
2. **Use `listen()`** to subscribe to incoming messages.
3. **Use `send(_:)`** to send messages directly from the item.
4. Let **`WebSocketManager`** automatically handle:
   - Connection reuse
   - Auto disconnection when no subscribers remain
   - Ping keepalive

---

## 🧪 Unit Test Example (v3.0.0)

```swift
struct EchoSocket: WebSocketITEM {
    var server = ServerInfo(domain: "wss://echo.websocket.org", defaultHeader: [:])
    var path: String = ""
}

let item = EchoSocket()

item.listen()
    .sink { message in print(message) }
    .store(in: &cancellables)

try await item.send(.text("test"))
```

---

## 🧼 Cleanups

- All `makeTopic()`, `.send(to:)`, and `publishers[topicName]` references should be removed.
- Instead, use the new `listen()` and `send()` provided by `WebSocketITEM`.

---

## 🤔 Need Help?

Feel free to open an issue or pull request at  
[https://github.com/southkin/FullyRESTful](https://github.com/southkin/FullyRESTful)