---
description: 如何添加新的TCP指令
---

# 添加新的 TCP 指令

当需要与音响设备通信新功能时，按以下步骤添加指令：

## 1. 在 CommandBuilder 中添加静态方法

打开 `TYAudio/Core/Network/CommandBuilder.swift`，添加新的静态方法：

```swift
/// 描述这个指令的功能
/// - Parameters:
///   - param1: 参数说明
/// - Returns: 指令字典
static func newCommand(param1: String) -> [String: Any] {
    return [
        "command": "command_name",
        "param1": param1
    ]
}
```

## 2. 发送指令

在需要使用的地方调用：

```swift
TCPSocketManager.shared.send(command: CommandBuilder.newCommand(param1: "value")) { error in
    if let error = error {
        // 处理错误
    }
}
```

## 3. 处理响应

在 ViewController 中实现 `TCPSocketManagerDelegate`：

```swift
func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
    if command == "command_name" {
        // 解析 data 并更新 UI
    }
}
```

## 注意事项

- ❌ 禁止直接构建指令字典，必须使用 CommandBuilder
- ❌ 禁止在多个地方重复实现相同的响应解析逻辑
- ✅ 所有指令必须在 CommandBuilder 中有详细注释
