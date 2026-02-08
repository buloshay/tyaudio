//
//  DeviceScanner.swift
//  TYAudio
//
//  设备扫描器，扫描局域网内的音响设备
//

import Foundation
import Network

/// 扫描状态
enum ScanningState {
    case idle
    case scanning(progress: Float)
    case completed(devices: [Device])
    case failed(Error)
}

/// 扫描结果代理
protocol DeviceScannerDelegate: AnyObject {
    func deviceScanner(_ scanner: DeviceScanner, didUpdateState state: ScanningState)
    func deviceScanner(_ scanner: DeviceScanner, didFindDevice device: Device)
}

/// 设备扫描器
class DeviceScanner {
    
    weak var delegate: DeviceScannerDelegate?
    
    private var isScanning = false
    private var foundDevices: [Device] = []
    private let scanQueue = DispatchQueue(label: "com.tyaudio.scanner", qos: .utility, attributes: .concurrent)
    private var activeConnections: [NWConnection] = []
    private let connectionTimeout: TimeInterval = 2.0
    private let port: UInt16 = 9012
    
    private var scannedCount = 0
    private let totalHosts = 254
    
    /// 获取本机局域网IP前缀
    private var localIPPrefix: String? {
        var prefix: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        let ip = String(cString: hostname)
                        if let range = ip.range(of: ".", options: .backwards) {
                            prefix = String(ip[..<range.lowerBound])
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return prefix
    }
    
    /// 开始扫描
    func startScan() {
        guard !isScanning else { return }
        
        isScanning = true
        foundDevices = []
        scannedCount = 0
        
        guard let prefix = localIPPrefix else {
            delegate?.deviceScanner(self, didUpdateState: .failed(ScanError.noLocalIP))
            isScanning = false
            return
        }
        
        delegate?.deviceScanner(self, didUpdateState: .scanning(progress: 0))
        
        // 并发扫描所有IP
        let group = DispatchGroup()
        
        for i in 1...254 {
            group.enter()
            let ip = "\(prefix).\(i)"
            
            scanQueue.async {
                self.checkDevice(at: ip) { [weak self] device in
                    guard let self = self else { return }
                    
                    self.scannedCount += 1
                    let progress = Float(self.scannedCount) / Float(self.totalHosts)
                    
                    DispatchQueue.main.async {
                        self.delegate?.deviceScanner(self, didUpdateState: .scanning(progress: progress))
                        
                        if let device = device {
                            self.foundDevices.append(device)
                            self.delegate?.deviceScanner(self, didFindDevice: device)
                        }
                    }
                    
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isScanning = false
            self.delegate?.deviceScanner(self, didUpdateState: .completed(devices: self.foundDevices))
        }
    }
    
    /// 停止扫描
    func stopScan() {
        isScanning = false
        activeConnections.forEach { $0.cancel() }
        activeConnections.removeAll()
    }
    
    /// 检查单个设备
    private func checkDevice(at ip: String, completion: @escaping (Device?) -> Void) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(rawValue: port)!)
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        var completed = false
        let timeout = DispatchWorkItem { [weak connection] in
            if !completed {
                completed = true
                connection?.cancel()
                completion(nil)
            }
        }
        
        connection.stateUpdateHandler = { [weak self] state in
            guard !completed else { return }
            
            switch state {
            case .ready:
                timeout.cancel()
                self?.queryDeviceModel(connection: connection, ip: ip) { device in
                    completed = true
                    completion(device)
                }
            case .failed, .cancelled:
                if !completed {
                    completed = true
                    timeout.cancel()
                    completion(nil)
                }
            default:
                break
            }
        }
        
        connection.start(queue: scanQueue)
        scanQueue.asyncAfter(deadline: .now() + connectionTimeout, execute: timeout)
    }
    
    /// 查询设备型号
    private func queryDeviceModel(connection: NWConnection, ip: String, completion: @escaping (Device?) -> Void) {
        let command = CommandBuilder.getProperty()
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: command, options: []) else {
            connection.cancel()
            completion(nil)
            return
        }
        
        // 打包消息
        let length = jsonData.count
        let lengthString = String(format: "%08d", length)
        var messageData = Data(lengthString.utf8)
        messageData.append(jsonData)
        
        connection.send(content: messageData, completion: .contentProcessed { error in
            if error != nil {
                connection.cancel()
                completion(nil)
                return
            }
            
            // 接收响应
            connection.receive(minimumIncompleteLength: 8, maximumLength: 8) { lengthData, _, _, error in
                guard error == nil,
                      let data = lengthData,
                      let lengthStr = String(data: data, encoding: .utf8),
                      let contentLength = Int(lengthStr.trimmingCharacters(in: .whitespaces)),
                      contentLength > 0 else {
                    connection.cancel()
                    completion(nil)
                    return
                }
                
                connection.receive(minimumIncompleteLength: contentLength, maximumLength: contentLength) { contentData, _, _, error in
                    defer { connection.cancel() }
                    
                    guard error == nil,
                          let data = contentData,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let result = json["result"] as? Int,
                          result == 1 else {
                        completion(nil)
                        return
                    }
                    
                    let model = json["value"] as? String
                    var device = Device(ipAddress: ip, port: self.port, model: model)
                    device.isConnected = false
                    completion(device)
                }
            }
        })
    }
}

// MARK: - Errors

enum ScanError: LocalizedError {
    case noLocalIP
    case scanFailed
    
    var errorDescription: String? {
        switch self {
        case .noLocalIP:
            return "无法获取本机IP地址，请检查网络连接"
        case .scanFailed:
            return "扫描失败"
        }
    }
}
