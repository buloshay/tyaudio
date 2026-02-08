//
//  ScreenMirrorService.swift
//  TYAudio
//
//  向日葵远程控制服务封装
//

import UIKit

// MARK: - 连接状态枚举

enum ScreenMirrorState {
    case idle
    case connecting
    case connected
    case failed(error: String)
    case disconnected
}

// MARK: - 代理协议

protocol ScreenMirrorServiceDelegate: AnyObject {
    func screenMirrorService(_ service: ScreenMirrorService, didChangeState state: ScreenMirrorState)
}

// MARK: - 服务类

/// 向日葵远程控制服务封装
/// - Note: 使用 SCCSDK 实现屏幕镜像功能
/// - Warning: 需要在 Xcode 项目中添加 SunloginControlSDK.framework
class ScreenMirrorService: NSObject {
    
    // MARK: - Singleton
    
    static let shared = ScreenMirrorService()
    
    // MARK: - Properties
    
    weak var delegate: ScreenMirrorServiceDelegate?
    
    private(set) var state: ScreenMirrorState = .idle {
        didSet {
            DispatchQueue.main.async {
                self.delegate?.screenMirrorService(self, didChangeState: self.state)
            }
        }
    }
    
    private var desktopController: SCCDesktopController?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 连接远程桌面
    /// - Parameters:
    ///   - address: 设备地址
    ///   - session: 会话ID
    ///   - soundSession: 声音会话ID（可选）
    ///   - completion: 连接完成回调
    func connect(address: String, session: String, soundSession: String? = nil, completion: @escaping (UIViewController?) -> Void) {
        precondition(!address.isEmpty, "Address cannot be empty")
        precondition(!session.isEmpty, "Session cannot be empty")
        
        state = .connecting
        
        // 创建桌面配置
        let config = SCCDesktopConfig()
        
        // 连接远程桌面
        SCCSDK.sdk().connectRemoteDestop(
            withAddress: address,
            session: session,
            soundSession: soundSession,
            system: .android,  // 音响设备使用 Android 系统
            desktopConfig: config,
            delegate: self
        ) { [weak self] controller in
            guard let self = self else { return }
            
            self.desktopController = controller
            controller.setDesktopDelegate(self)
            
            DispatchQueue.main.async {
                let viewController = controller.getDesktopViewController()
                completion(viewController)
            }
        }
    }
    
    /// 断开连接
    func disconnect() {
        desktopController?.closeDesktop()
        desktopController = nil
        state = .disconnected
    }
    
    /// 暂停接收数据（进入后台时调用）
    func pause() {
        desktopController?.pauseReceiveDate()
    }
    
    /// 恢复数据传输（回到前台时调用）
    func resume() {
        desktopController?.resumeReceiveDate()
    }
    
    /// 截图
    func takeScreenshot(completion: @escaping (UIImage?) -> Void) {
        desktopController?.getScreenshotComplete { image in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    /// 切换操作模式
    func switchOperationMode(_ mode: SCCDesktopOperationMode) {
        desktopController?.switchOperationMode(mode)
    }
    
    /// 获取当前操作模式
    var currentOperationMode: SCCDesktopOperationMode {
        return desktopController?.currentOperationMode() ?? .touch
    }
}

// MARK: - SCCSDKConnectStateDelegate

extension ScreenMirrorService: SCCSDKConnectStateDelegate {
    
    func sccsdkConnecting() {
        state = .connecting
    }
    
    func sccsdkConnectWillSucceed() {
        // 即将连接成功
    }
    
    func sccsdkConnectSucceed() {
        state = .connected
    }
    
    func sccsdkConnectFailed(withErrorCode errorCode: Int, errorMessage: String) {
        state = .failed(error: errorMessage)
    }
}

// MARK: - SCCDesktopControllerDelegate

extension ScreenMirrorService: SCCDesktopControllerDelegate {
    
    func sccDesktopDisconnect(_ isActive: Bool) {
        state = .disconnected
        desktopController = nil
    }
    
    func sccDesktopDidAppear() {
        // 远程桌面已显示
    }
    
    func sccDesktopDidDisappear() {
        // 远程桌面已消失
    }
}
