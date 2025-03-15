# FullyRESTful - Swift 네트워크 라이브러리

Swift에서 **RESTful API** 및 **WebSocket**을 손쉽게 다룰 수 있도록 설계된 경량 네트워킹 라이브러리입니다.

## 🚀 주요 기능
- RESTful API 호출 (`APIITEM` 프로토콜 기반)
- 멀티파트 폼 데이터 업로드 (`MultipartUpload` 프로토콜)
- WebSocket 연결 및 메시지 구독 (`WebSocketAPIITEM` 프로토콜)
- 간편한 `cURL` 로그 출력
- `Combine` 기반의 스트리밍 및 이벤트 처리

---

## 📦 설치 방법

### Swift Package Manager (SPM)
```swift
dependencies: [
    .package(url: "https://github.com/southkin/FullyRESTfu.git", .upToNextMajor(from: "1.0.0"))
]
```

---

## 🛠 RESTful API 사용법
### 📌 1. 서버 정보 선언
```swift
let myServer: ServerInfo = .init(domain: "https://foo.bar", defaultHeader: [:])
```

### 📌 2. API 선언
```swift
struct myAPI: APIITEM {
    var server: ServerInfo = myServer
    
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

### 📌 3. API 호출
#### ✅ Raw Data 요청
```swift
let data = try? await myAPI().getData(param: .init(param1: "param1", param2: [1,2,3], param3: ["param3Key":1.123]))
```

#### ✅ ResponseModel 변환
```swift
let model = try? await myAPI().request(param: .init(param1: "param1", param2: [1,2,3], param3: ["param3Key":1.123]))
```

---

## 📂 Multipart 업로드
```swift
struct myUploadAPI: APIITEM, MultipartUpload {
    var server: ServerInfo = myServer
    
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
    var path: String = "/myapi/path/upload"
}

guard let imageData = UIImage(named: "myImage")?.pngData() else { return }

// ✅ 데이터 업로드
let data = try? await myUploadAPI().getData(
    param: .init(
        param1: "param1",
        param2: [1.2, 3.4],
        param3: .init(data: imageData, mimeType: "image/png", fileName: "myImage1"),
        param4: .init(data: imageData, mimeType: "image/png", fileName: "myImage2")
    )
)

// ✅ 모델 변환 후 응답 받기
let model = try? await myUploadAPI().request(
    param: .init(
        param1: "param1",
        param2: [1.2, 3.4],
        param3: .init(data: imageData, mimeType: "image/png", fileName: "myImage1"),
        param4: .init(data: imageData, mimeType: "image/png", fileName: "myImage2")
    )
)
```


---

## 📜 `cURL` 로그 활성화
API 요청을 `cURL`로 출력하려면 `curlLog = true` 옵션을 설정하면 됩니다.
```swift
struct myAPI: APIITEM {
    // 기존 설정 정보
    var curlLog: Bool = true
}
```

출력 예시:
```bash
curl https://foo.bar/myapi/path -X POST -H "Content-Type: application/json" -d '{"param1":"value1","param2":[1,2,3]}'
```

---

## 🌍 WebSocket 사용법
FullyRESTful은 **WebSocket 연결 및 메시지 송수신**을 위한 `WebSocketAPIITEM`을 제공합니다.

### 📌 1. WebSocket 선언
```swift
enum MyWebSockets {
    class EchoSocket: WebSocketAPIITEM {
        var publishers: [String: CurrentValueSubject<WebSocketReceiveMessageModel?, any Error>] = [:]
        var webSocketTask: URLSessionWebSocketTask?
        var server: ServerInfo = .init(domain: "wss://echo.websocket.org", defaultHeader: [:])
        var path: String = ""
    }
}
```

### 📌 2. WebSocket 연결 및 메시지 수신
```swift
let echoSocket = MyWebSockets.EchoSocket()
let echoTopic = echoSocket.makeTopic(name: "echo")

echoTopic.listen()
    .compactMap { $0 }
    .sink(receiveValue: { message in
        print("📩 Received:", message)
    })
    .store(in: &cancellables)
```

### 📌 3. WebSocket 메시지 송신
```swift
let success = try await echoTopic.send(message: .text("Hello, WebSocket!"))
print("📤 Send Result:", success)
```

### 📌 4. WebSocket 닫기
```swift
echoTopic.close()
```

---

## 📋 지원 기능 요약
| 기능                 | 설명                                                   |
|--------------------|----------------------------------------------------|
| ✅ `APIITEM` 지원 | RESTful API를 선언형 방식으로 구성                     |
| ✅ `MultipartUpload` | 파일 업로드 API를 손쉽게 구현 가능                    |
| ✅ `cURL 로그`     | API 요청을 `cURL` 형식으로 확인 가능                     |
| ✅ `WebSocketAPIITEM` | WebSocket 연결 및 메시지 송수신 지원                    |
| ✅ `Combine` 지원  | WebSocket 메시지 스트리밍 및 필터링 처리 가능             |

---

## 📌 라이선스
이 프로젝트는 MIT 라이선스에 따라 배포됩니다.
