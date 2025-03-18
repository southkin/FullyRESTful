# FullyRESTful

FullyRESTful is a Swift networking library supporting **RESTful API calls**, **WebSocket connections**, and **Multipart uploads** with a simple and declarative approach.

## Features
- **Declarative API Definitions**  
  Define API calls with just a struct, including request, response models, and path.
- **RESTful API Calls**  
  Easily perform HTTP requests with JSON encoding/decoding.
- **WebSocket Support**  
  Subscribe, send messages, and receive real-time updates with Combine.
- **Multipart File Uploads**  
  Attach files in API requests with minimal configuration.
- **Modular Targeting**  
  Use only the features you need (RESTful API, WebSockets, or both).

---

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/southkin/FullyRESTful.git", .upToNextMajor(from: "2.0.0"))
]
```

---

## RESTful API Usage

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

// Request as Data
let data = try? await MyAPI().getData(param: .init(param1: "example", param2: [1, 2, 3], param3: ["key": 1.123]))

// Request as Response Model
let model = try? await MyAPI().request(param: .init(param1: "example", param2: [1, 2, 3], param3: ["key": 1.123]))
```

---

## Multipart File Upload

### Define a Multipart Upload API
```swift
struct MyUploadAPI: APIITEM, MultipartUpload {
    var server = myServer
    
    struct Request: Codable {
        let param1: String
        let param2: [Float]
        let param3: MultipartItem
        let param4: MultipartItem
    }

    struct Response: Codable {
        let result1: [String]
    }

    var requestModel = Request.self
    var responseModel = Response.self
    var method: HTTPMethod = .POST
    var path: String = "/myapi/upload"
}

guard let imageData = UIImage(named: "exampleImage")?.pngData() else { return }

// Request as Data
let data = try? await MyUploadAPI().getData(
    param: .init(
        param1: "example",
        param2: [1.2, 3.4],
        param3: .init(data: imageData, mimeType: "image/png", fileName: "image1"),
        param4: .init(data: imageData, mimeType: "image/png", fileName: "image2")
    )
)

// Request as Response Model
let model = try? await MyUploadAPI().request(
    param: .init(
        param1: "example",
        param2: [1.2, 3.4],
        param3: .init(data: imageData, mimeType: "image/png", fileName: "image1"),
        param4: .init(data: imageData, mimeType: "image/png", fileName: "image2")
    )
)
```

---

## WebSocket Usage

### Define a WebSocket Connection
```swift
enum TestWebSocket {}
extension TestWebSocket {
    class WebSocketEcho: WebSocketAPIITEM {
        var server = ServerInfo(domain: "wss://echo.websocket.org", defaultHeader: [:])
        var path = ""
    }
}
```

### Subscribe to a WebSocket Topic
```swift
let webSocket = TestWebSocket.WebSocketEcho()
let topic = webSocket.makeTopic(name: "echo")

topic.listen()
    .sink(receiveCompletion: { _ in }, receiveValue: { message in
        print("Received:", message)
    })
    .store(in: &cancellables)
```

### Send a Message
```swift
let isSuccess = try? await topic.send(message: .text("Hello, WebSocket!"))
if isSuccess == true {
    print("✅ Message sent successfully")
}
```

---

## Request Debugging (cURL Log)
Enable cURL logging for API requests.
```swift
struct MyAPI: APIITEM {
    // ... existing API configurations
    var curlLog = true
}
```

This will print the equivalent cURL command for debugging API requests.

---

## License
FullyRESTful is released under the MIT license.