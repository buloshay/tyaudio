---
description: 如何添加新的数据模型
---

# 添加新的数据模型

当需要解析新的 TCP 响应数据时，按以下步骤创建模型：

## 1. 创建模型结构体

在 `TYAudio/Core/Models/` 下创建或修改文件：

```swift
/// 模型描述
/// - Note: 对应 TCP 响应中的 xxx 字段
struct NewModel: Codable, Equatable {
    let id: String
    let name: String
    let value: Int
    
    // MARK: - JSON 解析
    
    /// 从 JSON 字典创建模型
    /// - Parameter json: TCP 响应的 JSON 字典
    /// - Returns: 解析后的模型，解析失败返回默认值
    static func from(json: [String: Any]) -> NewModel {
        return NewModel(
            id: json["id"] as? String ?? "",
            name: json["name"] as? String ?? "",
            value: json["value"] as? Int ?? 0
        )
    }
    
    /// 从 JSON 数组创建模型数组
    static func fromArray(jsonArray: [[String: Any]]) -> [NewModel] {
        return jsonArray.map { from(json: $0) }
    }
}
```

## 2. 在 ViewController 中使用

```swift
func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
    if command == "new_command" {
        if let list = data["list"] as? [[String: Any]] {
            let models = NewModel.fromArray(jsonArray: list)
            // 更新 UI
        }
    }
}
```

## 最佳实践

### ✅ 正确做法
```swift
// 使用可选绑定 + 默认值
let name = json["name"] as? String ?? ""
let count = json["count"] as? Int ?? 0
```

### ❌ 错误做法
```swift
// 强制解包 - 可能崩溃
let name = json["name"] as! String

// 多重嵌套 - 难以维护
if let name = json["name"] as? String {
    if let count = json["count"] as? Int {
        // ...
    }
}
```

## 已有模型参考

| 模型 | 文件 | 说明 |
|------|------|------|
| `Device` | Device.swift | 设备信息 |
| `PlayState` | PlayState.swift | 播放状态 |
| `FileItem` | FileItem.swift | 文件/目录 |
| `CategoryItem` | FileItem.swift | 分类项 |
| `AppItem` | FileItem.swift | 应用项 |
