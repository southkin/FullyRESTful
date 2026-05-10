# FullyRESTful Migration Guide

This guide covers the practical migration points from older 2.x-style WebSocket usage to the current API.

## What Changed

The main change is that WebSocket usage is now centered on `WebSocketITEM`.

Before:
- topic-oriented API shape
- extra wrapper concepts such as `makeTopic(...)`
- custom send/listen flow per topic

Now:
- one `WebSocketITEM` per endpoint
- `listen()` for incoming messages
- `send(_:)` for outgoing messages
- connection reuse managed internally
- automatic disconnect when the last subscriber is cancelled

## Before

```swift
class WebSocketEcho: WebSocketAPIITEM {
    var server = ...
    var path = ""
}

let topic = WebSocketEcho().makeTopic(name: "echo")

topic.listen()
    .sink { message in
        print(message)
    }
    .store(in: &cancellables)

try await topic.send(message: .text("Hello"))
```

## After

```swift
struct EchoSocket: WebSocketITEM {
    var server = ServerInfo(domain: "wss://example.com", defaultHeader: [:])
    var path: String = "/echo"
}

let socket = EchoSocket()

socket.listen()
    .sink { message in
        print(message)
    }
    .store(in: &cancellables)

try await socket.send(.text("Hello"))
```

## Migration Steps

1. Replace `WebSocketAPIITEM` / `TopicITEM` usage with `WebSocketITEM`.
2. Remove `makeTopic(...)` and any topic-specific routing layer.
3. Subscribe with `listen()` directly from the socket item.
4. Send with `send(_:)` directly from the socket item.
5. If needed, override `pingInterval` per socket.

## Behavior Notes

- `send(_:)` now ensures the connection exists before sending.
- Multiple subscribers on the same endpoint share one connection.
- Cancelling the last subscriber disconnects the socket automatically.
- Incoming messages are delivered as `WebSocketReceiveMessageModel`.
- You can decode received JSON with the provided Combine helper:

```swift
socket.listen()
    .decode(ChatMessage.self)
    .sink(
        receiveCompletion: { print($0) },
        receiveValue: { print($0) }
    )
    .store(in: &cancellables)
```

## Testing

The current WebSocket layer supports mockable session/task injection.

If you need deterministic tests:
- inject a custom `webSocketSession`
- provide a mock task
- assert `send`, incoming publish, and disconnect behavior without hitting a real server

## Cleanup Checklist

- Remove old topic abstractions
- Remove direct references to older WebSocket manager internals
- Update examples to `listen()` / `send(_:)`
- Replace external echo-server tests with mock-based tests

## Release Note Summary

For consumers, the migration message is simple:
- REST usage stays mostly the same
- WebSocket usage is flatter and endpoint-centric
- testing is easier because the transport can be mocked
