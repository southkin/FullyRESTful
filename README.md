# FullyRESTful
## ✨ What makes it different?

This library lets you define APIs like this:

```swift
let responseModel = try await MyAPI().request(param: .init(...)).model
```
...instead of writing all this:

```swift
var request = URLRequest(url: URL(string: "...")!)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try JSONEncoder().encode(MyAPI.Request(...))

let (data, response) = try await URLSession.shared.data(for: request)
guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode) else {
    throw URLError(.badServerResponse)
}

let responseModel = try JSONDecoder().decode(MyAPI.Response.self, from: data)
```

## 🤔 Why FullyRESTful?

- You want a clean, Swift-native way to call APIs.
- You hate writing boilerplate URLRequests.
- You want WebSocket and REST in the same system.
- You want your API layer to feel like SwiftUI.
- You want it to *just work*.

**FullyRESTful** is a Swift library supporting both **RESTful APIs** and **WebSocket** connections in a simple, declarative, and composable way.

---

# 🚨 FullyRESTful 3.0.0
**Breaking Changes in WebSocket Support**

The internal WebSocket system has been completely restructured.  
If you were using WebSocket features in version 2.x, please update your usage accordingly.

<!-- Replace with actual link after adding migration guide -->
[See Migration Guide →](#)

---

## 🚀 Features

- **Declarative API Definitions**  
  Define REST or WebSocket APIs in a single Swift structure.
- **RESTful API Support**  
  Simple request/response modeling with JSON encoding/decoding.
- **Multipart Upload Support**  
  Upload files and form data with minimal configuration.
- **Modern WebSocket Support**  
  Connect once and share the connection via Combine.
- **Modular Design**  
  Use only the features you need.

---

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/southkin/FullyRESTful.git", .upToNextMajor(from: "3.0.0"))
]
```

---

## 🌐 RESTful API Usage

### Define a Server
```swift
let myServer = ServerInfo(domain: "https://api.example.com", defaultHeader: [:])
```

### Define an API
```swift
struct MyAPI: APIITEM {
    var server = myServer
    
    struct Request: Codable {
        let param1: String?
        let param2: [Int]
        let param3: [String: Float]
    }

    struct Response: Codable {
        let result1: [String]
        let result2: [Int]?
        let result3: [String: Float]?
    }

    var requestModel = Request.self
    var responseModel = Response.self
    var method: HTTPMethod = .POST
    var path: String = "/myapi/path"
}
```

### Request
```swift
let data = try? await MyAPI().getData(param: .init(param1: "example", param2: [1, 2, 3], param3: ["key": 1.23])).data

let model = try? await MyAPI().request(param: .init(param1: "example", param2: [1, 2, 3], param3: ["key": 1.23])).model
```

---

## 🧠 Advanced Example: Shared Models & API Composition

You can reuse shared request/response models across APIs:

```swift
// Shared data models
struct Paging: Codable {
    let page: Int
    let limit: Int
}

struct ListResult<T: Codable>: Codable {
    let items: [T]
    let total: Int
}

struct User: Codable {
    let name:String
    let email:String
    let nickname:String?
}

// Reusing the shared model in multiple APIs
struct GetUsersAPI: APIITEM {
    var server = myServer

    struct Request: Codable {
        let paging: Paging
    }

    struct Response: Codable {
        let result: ListResult<User>
    }

    var requestModel = Request.self
    var responseModel = Response.self
    var method: HTTPMethod = .POST
    var path: String = "/users/list"
}
```
---

## 📎 Multipart Upload

### Define an API with File Upload
```swift
struct MyUploadAPI: APIITEM, MultipartUpload {
    var server = myServer

    struct Request: Codable {
        let title: String
        let image: MultipartItem
    }

    struct Response: Codable {
        let uploadedURL: String
    }

    var requestModel = Request.self
    var responseModel = Response.self
    var method: HTTPMethod = .POST
    var path: String = "/upload"
}
```

---

## 🔁 WebSocket Usage

### WebSockets in FullyRESTful are:
- automatically managed (single connection per endpoint)
- Combine-based, and cancellable
- pinged at regular intervals to stay alive
- capable of sending .text, .binary, or .codable(...) payloads

### Define a WebSocket
```swift
struct EchoSocket: WebSocketITEM {
    var server = ServerInfo(domain: "wss://echo.websocket.org", defaultHeader: [:])
    var path: String = ""
    // Optional: override ping interval (default = 10 sec)
    var pingInterval: TimeInterval { 5 }
}
```

### Connect and Subscribe
```swift
let socket = EchoSocket()
socket.listen()
    .sink { message in
        print("📥", message ?? "nil")
    }
    .store(in: &cancellables)
```

### Send Text Message
```swift
try await socket.send(.text("Hello WebSocket!"))
```

### Send a Codable Message
```swift
struct ChatMessage: Codable {
    let type: String
    let content: String
}

let message = ChatMessage(type: "chat", content: "Hello from Codable!")
try await socket.send(.codable(message))
```

### Decode Received Messages
```swift
socket.listen()
    .compactMap {
        guard case let .text(text) = $0,
              let data = text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ChatMessage.self, from: data)
        else { return nil }
        return decoded
    }
    .sink { decoded in
        print("📩 Decoded:", decoded)
    }
    .store(in: &cancellables)
```

---

## 🧪 Debugging

Enable cURL log output for debugging:

```swift
struct MyAPI: APIITEM {
    var curlLog = true
}
```

---

## 📄 License

MIT License
