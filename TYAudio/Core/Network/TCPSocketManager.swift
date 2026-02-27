//
//  TCPSocketManager.swift
//  TYAudio
//
//  核心TCP通信管理器，基于TY-i60协议实现
//

import Foundation
import Network

/// TCP连接状态
enum TCPConnectionState {
    case disconnected
    case connecting
    case connected
    case failed(Error)
}

/// TCP通信管理器代理
protocol TCPSocketManagerDelegate: AnyObject {
    func tcpSocketManager(_ manager: TCPSocketManager, didChangeState state: TCPConnectionState)
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String)
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error)
}

/// TCP通信管理器
/// 协议格式：8字节长度前缀 + JSON数据
class TCPSocketManager {
    
    // MARK: - Properties
    
    private struct WeakDelegate {
        weak var value: TCPSocketManagerDelegate?
        init(_ value: TCPSocketManagerDelegate) {
            self.value = value
        }
    }
    
    private var delegates: [WeakDelegate] = []
    
    /// 添加代理
    func addDelegate(_ delegate: TCPSocketManagerDelegate) {
        // 清理已释放的代理
        delegates = delegates.filter { $0.value != nil }
        // 避免重复添加
        if !delegates.contains(where: { $0.value === delegate }) {
            delegates.append(WeakDelegate(delegate))
        }
    }
    
    /// 移除代理
    func removeDelegate(_ delegate: TCPSocketManagerDelegate) {
        delegates = delegates.filter { $0.value != nil && $0.value !== delegate }
    }
    
    // MARK: - Properties
    static let shared = TCPSocketManager()
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.tyaudio.tcp", qos: .userInitiated)
    
    private(set) var connectionState: TCPConnectionState = .disconnected {
        didSet {
            let newState = connectionState // 立即捕获，避免异步读取时状态已变
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                print("TCP Connection state changed: \(newState)")
                self.notifyDelegates { $0.tcpSocketManager(self, didChangeState: newState) }
            }
        }
    }
    
    private(set) var currentHost: String?
    private(set) var currentPort: UInt16 = 8001 // 默认端口
    
    // T019: 自动重连状态机
    /// 是否启用自动重连
    var autoReconnectEnabled: Bool = true
    /// 当前重连尝试次数
    private var reconnectAttempts: Int = 0
    /// 最大重连次数
    private let maxReconnectAttempts: Int = 5
    /// 重连计时器
    private var reconnectTimer: DispatchSourceTimer?
    /// 是否用户主动断开（不触发自动重连）
    private var isManualDisconnect: Bool = false
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Connection Management
    
    /// 连接到设备
    func connect(host: String, port: UInt16 = 8001) {
        print("[TCP] [App] Connecting to host: \(host), port: \(port)...")
        // 静默清理旧连接，不触发状态回调
        connection?.cancel()
        connection = nil
        
        currentHost = host
        currentPort = port
        connectionState = .connecting
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        connection = NWConnection(to: endpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.connectionState = .connected
                self.reconnectAttempts = 0 // T019: 连接成功重置重连计数器
                self.isManualDisconnect = false
                self.cancelReconnectTimer()
                self.startReceiving()
                
                if self.isReconnecting {
                    self.isReconnecting = false
                    print("[TCP] Reconnected, refreshing play state")
                    DispatchQueue.main.async {
                        self.send(command: CommandBuilder.getPlayState())
                    }
                }
            case .failed(let error):
                self.connectionState = .failed(error)
                // T019: 连接失败时触发自动重连
                self.scheduleReconnectIfNeeded()
            case .cancelled:
                self.connectionState = .disconnected
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    /// 断开连接
    func disconnect() {
        print("[TCP] [App] Disconnecting from host...")
        isManualDisconnect = true // T019: 标记为手动断开
        cancelReconnectTimer()
        reconnectAttempts = 0
        connection?.cancel()
        connection = nil
        connectionState = .disconnected
        currentHost = nil
        isReconnecting = false
    }
    
    /// 是否已连接
    var isConnected: Bool {
        if case .connected = connectionState {
            return true
        }
        return false
    }
    
    // MARK: - Data Transmission
    
    /// 发送JSON指令
    /// - Parameter command: 指令字典
    func send(command: [String: Any], completion: ((Error?) -> Void)? = nil) {
        guard isConnected else {
            completion?(TCPError.notConnected)
            return
        }
        
        do {
            print("[TCP] Sending command: \(command)")
            let jsonData = try JSONSerialization.data(withJSONObject: command, options: [])
            print("[TCP] Sending Hex: \(jsonData.map { String(format: "%02hhx", $0) }.joined())")
            let messageData = packMessage(jsonData)
            
            connection?.send(content: messageData, completion: .contentProcessed { error in
                DispatchQueue.main.async {
                    completion?(error)
                }
            })
        } catch {
            completion?(error)
        }
    }
    
    /// 发送JSON字符串指令
    func send(jsonString: String, completion: ((Error?) -> Void)? = nil) {
        guard isConnected else {
            completion?(TCPError.notConnected)
            return
        }
        
        print("[TCP] Sending JSON string: \(jsonString)")
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            completion?(TCPError.invalidData)
            return
        }
        
        print("[TCP] Sending Hex: \(jsonData.map { String(format: "%02hhx", $0) }.joined())")
        
        let messageData = packMessage(jsonData)
        
        connection?.send(content: messageData, completion: .contentProcessed { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        })
    }
    
    // MARK: - Reconnection
    
    /// 是否是重连操作
    private var isReconnecting = false
    
    /// App 回到前台时调用
    func handleAppDidBecomeActive() {
        guard !isConnected,
              let host = currentHost,
              !host.isEmpty else { return }
        
        print("[TCP] Connection lost while in background, reconnecting to \(host):\(currentPort)")
        isReconnecting = true
        reconnectAttempts = 0 // T019: 前台重连重置计数器
        connect(host: host, port: currentPort)
    }
    
    // MARK: - T019: Auto Reconnect
    
    /// 计算重连延迟（指数退避）
    private func reconnectDelay(for attempt: Int) -> TimeInterval {
        return min(pow(2.0, Double(attempt)), 16.0) // 1s, 2s, 4s, 8s, 16s
    }
    
    /// 判断并调度自动重连
    private func scheduleReconnectIfNeeded() {
        guard autoReconnectEnabled,
              !isManualDisconnect,
              reconnectAttempts < maxReconnectAttempts,
              let host = currentHost,
              !host.isEmpty else {
            if reconnectAttempts >= maxReconnectAttempts {
                print("[TCP] ⚠️ Auto-reconnect exhausted (\(maxReconnectAttempts) attempts)")
            }
            return
        }
        
        let delay = reconnectDelay(for: reconnectAttempts)
        reconnectAttempts += 1
        print("[TCP] Scheduling auto-reconnect #\(reconnectAttempts) in \(delay)s")
        
        cancelReconnectTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard !self.isConnected else { return }
            print("[TCP] Auto-reconnecting to \(host):\(self.currentPort) (attempt \(self.reconnectAttempts))")
            self.isReconnecting = true
            DispatchQueue.main.async {
                self.connect(host: host, port: self.currentPort)
            }
        }
        timer.resume()
        reconnectTimer = timer
    }
    
    /// 取消重连计时器
    private func cancelReconnectTimer() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    // MARK: - Private Methods
    
    /// 打包消息：8字节长度前缀 + JSON数据
    private func packMessage(_ jsonData: Data) -> Data {
        let length = jsonData.count
        let lengthString = String(format: "%08d", length)
        var messageData = Data(lengthString.utf8)
        messageData.append(jsonData)
        return messageData
    }
    
    /// 开始接收数据
    private func startReceiving() {
        receiveLength()
    }
    
    /// 接收8字节长度前缀
    private func receiveLength() {
        connection?.receive(minimumIncompleteLength: 8, maximumLength: 8) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[TCP] Error receiving length: \(error)")
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.tcpSocketManager(self, didReceiveError: error) }
                }
                return
            }
            
            if isComplete {
                print("[TCP] [Remote] Connection closed by remote host (EOF)")
                self.connectionState = .disconnected
                // T019: 远端关闭连接时也触发自动重连
                self.scheduleReconnectIfNeeded()
                return
            }
            
            guard let data = content,
                  let lengthString = String(data: data, encoding: .utf8),
                  let length = Int(lengthString.trimmingCharacters(in: .whitespaces)),
                  length > 0 else {
                print("[TCP] Invalid length header received, retrying...")
                self.receiveLength()
                return
            }
            
            print("[TCP] Received data length: \(length)")
            self.receiveContent(length: length)
        }
    }
    
    /// 接收JSON内容
    private func receiveContent(length: Int) {
        connection?.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error receiving content: \(error)")
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.tcpSocketManager(self, didReceiveError: error) }
                }
                return
            }
            
            if let data = content {
//                print("[TCP] Received Hex: \(data.map { String(format: "%02hhx", $0) }.joined())")
                self.parseReceivedData(data)
            }
            
            if !isComplete {
                self.receiveLength()
            }
        }
    }
    
    /// 解析接收的JSON数据
    private func parseReceivedData(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let command = json["command"] as? String {
                
                print("Received command: \(command), data: \(json)")
                
                // 播放状态需要回应pong
                if command == "play_state" {
                    sendPong()
                }
                
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.tcpSocketManager(self, didReceiveData: json, command: command) }
                }
            }
        } catch {
            print("Error parsing received data: \(error)")
            DispatchQueue.main.async {
                self.notifyDelegates { $0.tcpSocketManager(self, didReceiveError: error) }
            }
        }
    }
    
    /// 通知所有代理
    private func notifyDelegates(_ block: (TCPSocketManagerDelegate) -> Void) {
        // 清理已释放的代理
        delegates = delegates.filter { $0.value != nil }
        
        for delegate in delegates {
            if let value = delegate.value {
                block(value)
            }
        }
    }
    
    /// 发送pong响应
    private func sendPong() {
        send(command: ["command": "pong"])
    }
    /// 发送JSON指令（带超时）
    /// - Parameters:
    ///   - command: 指令字典
    ///   - timeout: 超时时间（秒），默认 6 秒
    func sendWithTimeout(command: [String: Any], timeout: TimeInterval = 6.0, completion: ((Error?) -> Void)? = nil) {
        // 创建超时计时器
        var isCompleted = false
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + timeout)
        
        // 超时处理
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if !isCompleted {
                isCompleted = true
                timer.cancel()
                print("[TCP] Send timeout for command: \(command)")
                DispatchQueue.main.async {
                    completion?(TCPError.sendTimeout)
                }
            }
        }
        timer.resume()
        
        // 发送数据
        send(command: command) { error in
            if !isCompleted {
                isCompleted = true
                timer.cancel()
                completion?(error)
            }
        }
    }
}

// MARK: - Errors

enum TCPError: LocalizedError {
    case notConnected
    case invalidData
    case connectionFailed
    case sendTimeout
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "未连接到设备"
        case .invalidData:
            return "无效的数据格式"
        case .connectionFailed:
            return "连接失败"
        case .sendTimeout:
            return "发送指令超时"
        }
    }
}
