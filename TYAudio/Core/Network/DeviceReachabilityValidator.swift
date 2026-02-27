//
//  DeviceReachabilityValidator.swift
//  TYAudio
//
//  统一设备可用性校验服务（IP格式 + TCP端口探测）
//

import Foundation
import Network

/// 校验结果
enum DeviceValidationResult {
    case valid
    case invalidIPFormat
    case unreachable
}

/// 设备可用性校验器
struct DeviceReachabilityValidator {
    
    /// 默认端口
    static let defaultPort: UInt16 = 8001
    /// 连接超时（秒）
    static let connectionTimeout: TimeInterval = 3.0
    
    // MARK: - IP Format Validation
    
    /// 校验 IP 地址格式是否合法
    static func isValidIP(_ ip: String) -> Bool {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".")
        guard parts.count == 4 else { return false }
        
        for part in parts {
            guard let num = Int(part), num >= 0, num <= 255 else {
                return false
            }
            // 不允许前导零（如 "01"、"001"），但允许单独的 "0"
            if part.count > 1 && part.hasPrefix("0") {
                return false
            }
        }
        return true
    }
    
    // MARK: - TCP Reachability Check
    
    /// 校验设备 TCP 端口是否可达
    /// - Parameters:
    ///   - ip: IP 地址（需已通过格式校验）
    ///   - port: 端口号，默认 8001
    ///   - completion: 回调（主线程），true 表示可达
    static func checkReachability(ip: String, port: UInt16 = defaultPort, completion: @escaping (Bool) -> Void) {
        let host = NWEndpoint.Host(ip)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let connection = NWConnection(host: host, port: nwPort, using: .tcp)
        
        var isCompleted = false
        let completeOnce: (Bool) -> Void = { reachable in
            guard !isCompleted else { return }
            isCompleted = true
            connection.cancel()
            DispatchQueue.main.async {
                completion(reachable)
            }
        }
        
        // 超时处理
        DispatchQueue.global().asyncAfter(deadline: .now() + connectionTimeout) {
            completeOnce(false)
        }
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[DeviceValidator] TCP connection to \(ip):\(port) succeeded")
                completeOnce(true)
            case .failed(let error):
                print("[DeviceValidator] TCP connection to \(ip):\(port) failed: \(error)")
                completeOnce(false)
            case .cancelled:
                break
            default:
                break
            }
        }
        
        connection.start(queue: DispatchQueue(label: "com.tyaudio.device-validator"))
    }
    
    // MARK: - Combined Validation
    
    /// 完整校验流程：IP 格式 + TCP 可达性
    /// - Parameters:
    ///   - ip: 待校验的 IP 地址
    ///   - port: 端口号
    ///   - completion: 回调（主线程）
    static func validate(ip: String, port: UInt16 = defaultPort, completion: @escaping (DeviceValidationResult) -> Void) {
        guard isValidIP(ip) else {
            DispatchQueue.main.async {
                completion(.invalidIPFormat)
            }
            return
        }
        
        checkReachability(ip: ip, port: port) { reachable in
            completion(reachable ? .valid : .unreachable)
        }
    }
}
