//
//  Device.swift
//  TYAudio
//
//  设备数据模型
//

import Foundation

/// 音响设备模型
struct Device: Codable, Identifiable, Equatable {
    let id: UUID
    var ipAddress: String
    var port: UInt16
    var model: String?
    var isConnected: Bool
    var lastConnected: Date?
    
    init(ipAddress: String, port: UInt16 = 9012, model: String? = nil) {
        self.id = UUID()
        self.ipAddress = ipAddress
        self.port = port
        self.model = model
        self.isConnected = false
        self.lastConnected = nil
    }
    
    /// 设备显示名称
    var displayName: String {
        return model ?? "TY-i60"
    }
    
    /// 设备地址
    var address: String {
        return "\(ipAddress):\(port)"
    }
}

/// 设备管理器
class DeviceManager {
    
    static let shared = DeviceManager()
    
    private let userDefaultsKey = "SavedDevices"
    
    /// 已保存的设备列表
    private(set) var devices: [Device] = []
    
    /// 当前连接的设备
    private(set) var currentDevice: Device?
    
    private init() {
        loadDevices()
    }
    
    // MARK: - Device Management
    
    /// 添加设备
    func addDevice(_ device: Device) {
        if !devices.contains(where: { $0.ipAddress == device.ipAddress }) {
            devices.append(device)
            saveDevices()
        }
    }
    
    /// 移除设备
    func removeDevice(_ device: Device) {
        devices.removeAll { $0.id == device.id }
        saveDevices()
    }
    
    /// 更新设备
    func updateDevice(_ device: Device) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
            saveDevices()
        }
    }
    
    /// 设置当前设备
    func setCurrentDevice(_ device: Device?) {
        currentDevice = device
    }
    
    // MARK: - Persistence
    
    private func saveDevices() {
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadDevices() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedDevices = try? JSONDecoder().decode([Device].self, from: data) {
            devices = savedDevices
        }
    }
}
