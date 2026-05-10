# FullyRESTful
## ✨ What makes it different?

Most networking libraries make you split one API across multiple places:
- endpoint path
- request model
- response model
- request-building logic

FullyRESTful was built for the opposite approach:
- one API
- one Swift type
- request and response defined together

That means the shape your backend teammate sends you can stay almost 그대로 in code.

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

- You want each API to own its `Request` and `Response` together.
- You do not want endpoint specs scattered across files.
- You want to turn backend API guides into Swift types with minimal glue code.
- You want REST and WebSocket to feel consistent.
- You want a small abstraction over `URLSession`, not a giant framework.

**FullyRESTful** is a Swift library supporting both **RESTful APIs** and **WebSocket** connections in a simple, declarative, and composable way.

---

# 🚨 FullyRESTful 3.0.0
**Breaking Changes in WebSocket Support**

The internal WebSocket system has been completely restructured.  
If you were using WebSocket features in version 2.x, please update your usage accordingly.

[See Migration Guide →](md/MigrationGuide.md)

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

let model = try await MyAPI().request(
    param: .init(param1: "example", param2: [1, 2, 3], param3: ["key": 1.23])
).model
```

---

## ✅ Empty Response

For endpoints like `DELETE /resource/:id` that return `204 No Content`:

```swift
struct DeleteUserAPI: APIITEM {
    var server = myServer

    struct Request: Codable {}

    var requestModel = Request.self
    var responseModel = EmptyResponse.self
    var method: HTTPMethod = .DELETE
    var path: String = "/users/1"
}

let response = try await DeleteUserAPI().request(param: .init())
print(response.rawResponse.statusCode)
```

---

## 📝 Plain Text Response

If the server returns `text/plain`, use `String` as the response model:

```swift
struct HealthCheckAPI: APIITEM {
    var server = myServer

    struct Request: Codable {}

    var requestModel = Request.self
    var responseModel = String.self
    var method: HTTPMethod = .GET
    var path: String = "/health"
}

let text = try await HealthCheckAPI().request(param: .init()).model
```

---

## 🎯 Custom Decoder

If the backend needs custom date decoding or key strategies:

```swift
struct EventAPI: APIITEM {
    var server = myServer

    struct Request: Codable {}
    struct Response: Codable {
        let createdAt: Date
    }

    var requestModel = Request.self
    var responseModel = Response.self
    var method: HTTPMethod = .GET
    var path: String = "/event"

    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
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
        print("📥", message)
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
    .decode(ChatMessage.self)
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

You can also inject a custom `URLSession` for tests or controlled environments:

```swift
struct MyAPI: APIITEM {
    var server = myServer
    var session: URLSession = .shared
}
```

---

## ⚠️ Error Handling

`FullyRESTful` throws `FullyRESTfulError` for the common transport and decoding cases.

Typical cases:
- `badURL`: invalid `server.domain + path`
- `httpError(statusCode:data:)`: non-success HTTP response with raw body preserved
- `emptyResponseBody`: body was empty but your `ResponseModel` could not decode from it
- `unsupportedContentType`: response was not JSON or text
- `invalidWebSocketState`: send attempted before a valid socket state existed

Example:

```swift
do {
    let response = try await MyAPI().request(param: .init(...))
    print(response.model)
} catch let error as FullyRESTfulError {
    switch error {
    case .httpError(let statusCode, let data):
        print("status:", statusCode)
        print("body:", String(data: data, encoding: .utf8) ?? "")
    default:
        print(error.localizedDescription)
    }
}
```

---

## 📄 License

MIT License
