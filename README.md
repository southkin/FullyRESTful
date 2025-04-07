# FullyRESTful

**FullyRESTful** is a Swift library supporting both **RESTful APIs** and **WebSocket** connections in a simple, declarative, and composable way.

---

## 🚀 Features

- 📦 **Modular** – Use only REST or WebSocket components as needed.
- 📡 **WebSocket** – Stream messages with Combine. Automatic connection & disconnect.
- 📠 **RESTful API** – Simple declaration of request/response models.
- 📁 **Multipart Upload** – File uploads made easy.
- 🧪 **Testing Friendly** – Fully testable with XCTest.

---

## 📦 Installation

Using **Swift Package Manager**:

```swift
dependencies: [
    .package(url: "https://github.com/southkin/FullyRESTful.git", from: "2.0.0")
]
```

---

## 🌐 RESTful API

### 1. Define API

```swift
let myServer = ServerInfo(domain: "https://api.example.com", defaultHeader: [:])

struct MyAPI: APIITEM {
    var server = myServer
    
    struct Request: Codable {
        let name: String
        let values: [Int]
    }

    struct Response: Codable {
        let message: String
        let result: [Int]
    }

    var requestModel = Request.self
    var responseModel = Response.self
    var method: HTTPMethod = .POST
    var path: String = "/example/path"
}
```

### 2. Make Request

```swift
let model = try await MyAPI().request(param: .init(name: "Test", values: [1, 2, 3])).model
```

---

## 🧷 Multipart Upload

```swift
struct UploadAPI: APIITEM, MultipartUpload {
    var server = myServer

    struct Request: Codable {
        let image: MultipartItem
        let title: String
    }

    struct Response: Codable {
        let status: String
    }

    var requestModel = Request.self
    var responseModel = Response.self
    var method: HTTPMethod = .POST
    var path: String = "/upload"
}

let imageData = UIImage(named: "sample")!.pngData()!
let item = MultipartItem(data: imageData, mimeType: "image/png", fileName: "sample.png")

let response = try await UploadAPI().request(
    param: .init(image: item, title: "My Image")
).model
```

---

## 🔌 WebSocket

### 1. Define a WebSocket

```swift
struct EchoSocket: WebSocketITEM {
    var server = ServerInfo(domain: "wss://echo.websocket.org", defaultHeader: [:])
    var path = ""
}
```

### 2. Listen to Messages

```swift
let socket = EchoSocket()

socket.listen()
    .compactMap { $0 }
    .sink { message in
        print("Received:", message)
    }
    .store(in: &cancellables)
```

### 3. Send a Message

```swift
try await socket.send(.text("Hello!"))
```

---

## 🧠 Advanced

- ✅ **Automatic Disconnect**: If no subscribers remain, the WebSocket disconnects.
- 🔁 **Connection Reuse**: New listeners share existing connections.
- 🛠 **Custom Ping Interval**: Conform to `WebSocketITEM` with `pingInterval`.
- 🧪 **Debug Helper**:

```swift
#if DEBUG
let isDisconnected = socket.isDisconnected(socket)
#endif
```

---

## 🔍 Debug cURL

Enable cURL logging for REST APIs:

```swift
struct MyAPI: APIITEM {
    var curlLog = true
}
```

---

## 📄 License

MIT License.
