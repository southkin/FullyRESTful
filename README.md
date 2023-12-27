# FullyRESTful
Swift로 구현된 HTTP 네트워킹 라이브러리

## 기능
- RESTful API 호출 지원
- 멀티파트 폼 데이터 업로드

## 특징
- `APIITEM` `MultipartUpload` 프로토콜을 통한 API 의 선언
- 하나의 구조체에 path, RequestModel, ResponseModel 을 선언


## 설치 방법

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/southkin/FullyRESTfu.git", .upToNextMajor(from: "1.0.0"))
]
```
## 사용 방법

### 서버 선언
```swift
let myServer:ServerInfo = .init(domain: "https://foo.bar", defaultHeader: [:])
```

### API 선언
```swift
struct myAPI:APIITEM {
    var server: ServerInfo = myServer
    
    struct Request:Codable {
        let param1:String?
        let param2:[Int]
        let param3:[String:Float]
    }
    struct Response:Codable {
        let result1:[String]
        let result2:[Int]?
        let result3:[String:Float]?
    }
    var requestModel = Request.self
    var responseModel = Response.self
    var method: HTTPMethod = .POST
    var path: String = "/myapi/path"
}
//Data
let data = try? await myAPI().getData(param: .init(param1: "param1", param2: [1,2,3], param3: ["param3Key":1.123]))

//ResponseModel
let model = try? await myAPI().request(param: .init(param1: "param1", param2: [1,2,3], param3: ["param3Key":1.123]))
```

### Multipart 업로드
```swift
struct myUploadAPI:APIITEM, MultipartUpload {
    var server: ServerInfo = myServer
    
    struct Request:Codable {
        let param1:String
        let param2:[Float]
        let param3:MultipartItem
        let param4:MultipartItem
    }
    struct Response:Codable {
        let result1:[String]
    }
    var requestModel = Request.self
    var responseModel = Response.self
    var method: HTTPMethod = .POST
    var path: String = "/myapi/path/upload"
}

guard let imageData = UIImage(named: "myImage")?.pngData() else {return}
//Data
let data = try? await myUploadAPI().getData(param: .init(param1: "param1", param2: [1.2,3.4], param3: .init(data: imageData, mimeType: "image/png", fileName: "myImage1"), param4: .init(data: imageData, mimeType: "image/png", fileName: "myImage2")))

//RespnoseModel
let model = try? await myUploadAPI().request(param: .init(param1: "param1", param2: [1.2,3.4], param3: .init(data: imageData, mimeType: "image/png", fileName: "myImage1"), param4: .init(data: imageData, mimeType: "image/png", fileName: "myImage2")))
```

### 리퀘스트 정보(curl)
```swift
struct myAPI:APIITEM {
    //... 기존 설정정보
    var curlLog: Bool = true
}

```
