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
    
    static let shared = TCPSocketManager()
    
    weak var delegate: TCPSocketManagerDelegate?
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.tyaudio.tcp", qos: .userInitiated)
    
    private(set) var connectionState: TCPConnectionState = .disconnected {
        didSet {
            let newState = connectionState // 立即捕获，避免异步读取时状态已变
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                print("TCP Connection state changed: \(newState)")
                self.delegate?.tcpSocketManager(self, didChangeState: newState)
            }
        }
    }
    
    private(set) var currentHost: String?
    private(set) var currentPort: UInt16 = 8001 // 默认端口
    
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
                self.startReceiving()
            case .failed(let error):
                self.connectionState = .failed(error)
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
        connection?.cancel()
        connection = nil
        connectionState = .disconnected
        currentHost = nil
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
                    self.delegate?.tcpSocketManager(self, didReceiveError: error)
                }
                return
            }
            
            if isComplete {
                print("[TCP] [Remote] Connection closed by remote host (EOF)")
                self.connectionState = .disconnected
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
                    self.delegate?.tcpSocketManager(self, didReceiveError: error)
                }
                return
            }
            
            if let data = content {
                print("[TCP] Received Hex: \(data.map { String(format: "%02hhx", $0) }.joined())")
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
                    self.delegate?.tcpSocketManager(self, didReceiveData: json, command: command)
                }
            }
        } catch {
            print("Error parsing received data: \(error)")
            DispatchQueue.main.async {
                self.delegate?.tcpSocketManager(self, didReceiveError: error)
            }
        }
    }
    
    /// 发送pong响应
    private func sendPong() {
        send(command: ["command": "pong"])
    }
}

// MARK: - Errors

enum TCPError: LocalizedError {
    case notConnected
    case invalidData
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "未连接到设备"
        case .invalidData:
            return "无效的数据格式"
        case .connectionFailed:
            return "连接失败"
        }
    }
}
