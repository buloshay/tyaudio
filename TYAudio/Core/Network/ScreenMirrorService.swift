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
    /// 向日葵远程桌面画面已出现（可用于关闭 loading）
    func screenMirrorServiceDidDesktopAppear(_ service: ScreenMirrorService)
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
    /// 持有一个 SDK 实例，避免每次连接都创建临时对象
    private let sdk = SCCSDK()
    
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
    ///   - system: 被控系统类型
    ///   - config: 桌面配置（可选），传 nil 则使用默认配置
    ///   - completion: 连接完成回调
    func connect(
        address: String,
        session: String,
        soundSession: String? = nil,
        system: SCCRemoteSystem = .android,
        config: SCCDesktopConfig? = nil,
        completion: @escaping (UIViewController?) -> Void
    ) {
        // T010: 防御式校验，避免在异常 session 场景触发 precondition 崩溃
        guard !address.isEmpty else {
            print("[ScreenMirror] ⚠️ connect failed: address is empty")
            state = .failed(error: "Address cannot be empty")
            DispatchQueue.main.async { completion(nil) }
            return
        }
        guard !session.isEmpty else {
            print("[ScreenMirror] ⚠️ connect failed: session is empty")
            state = .failed(error: "Session cannot be empty")
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        // 新建连接前先清理旧桌面，避免底层通道残留影响
        desktopController?.closeDesktop()
        desktopController = nil
        state = .connecting
        
        // 使用传入的配置或创建默认配置
        let desktopConfig = config ?? SCCDesktopConfig()
        
        print("[ScreenMirror] start connect, system=\(system.rawValue), enableUI=\(desktopConfig.isEnableUI)")
        
        // 连接远程桌面
        sdk.connectRemoteDestop(
            withAddress: address,
            session: session,
            soundSession: soundSession,
            system: system,
            desktopConfig: desktopConfig,
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
        desktopController?.switch(mode)
    }
    
    /// 获取当前操作模式
    var currentOperationMode: SCCDesktopOperationMode {
        return desktopController?.currentOperationMode() ?? .touch
    }
    
    // MARK: - Android快捷按键
    
    /// 向日葵 Android 返回键
    func androidClickBack() {
        guard let controller = desktopController else {
            print("[ScreenMirror] androidClickBack ignored: desktopController is nil")
            return
        }
        controller.androidClickBack()
    }
    
    /// 向日葵 Android 菜单键
    func androidClickMenu() {
        guard let controller = desktopController else {
            print("[ScreenMirror] androidClickMenu ignored: desktopController is nil")
            return
        }
        controller.androidClickMenu()
    }
    
    /// 向日葵 Android Home键（预留）
    func androidClickHome() {
        guard let controller = desktopController else {
            print("[ScreenMirror] androidClickHome ignored: desktopController is nil")
            return
        }
        controller.androidClickHome()
    }
}

// MARK: - SCCSDKConnectStateDelegate

extension ScreenMirrorService: SCCSDKConnectStateDelegate {
    
    func sccsdkConnecting() {
        print("[ScreenMirror] SCCSDK connecting")
        state = .connecting
    }
    
    func sccsdkConnectWillSucceed() {
        // 即将连接成功
    }
    
    func sccsdkConnectSucceed() {
        print("[ScreenMirror] SCCSDK connect succeed")
        state = .connected
    }
    
    func sccsdkConnectFailedWithErrorCode(_ errorCode: Int, errorMessage: String) {
        let detail = "[\(errorCode)] \(errorMessage)"
        print("[ScreenMirror] SCCSDK connect failed: \(detail)")
        state = .failed(error: detail)
    }
}

// MARK: - SCCDesktopControllerDelegate

extension ScreenMirrorService: SCCDesktopControllerDelegate {
    
    func sccDesktopDisconnect(_ isActive: Bool) {
        print("[ScreenMirror] desktop disconnect, isActive=\(isActive)")
        state = .disconnected
        desktopController = nil
    }
    
    func sccDesktopDidAppear() {
        print("[ScreenMirror] desktop did appear")
        DispatchQueue.main.async {
            self.delegate?.screenMirrorServiceDidDesktopAppear(self)
        }
    }
    
    func sccDesktopDidDisappear() {
        // 远程桌面已消失
    }
}
