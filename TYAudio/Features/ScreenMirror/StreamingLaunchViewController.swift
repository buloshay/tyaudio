//
//  StreamingLaunchViewController.swift
//  TYAudio
//
//  统一启动页（全流程）
//  支持四种入口：流媒体 / NAS / 设置 / 屏幕互动
//  处理 启动APP → 请求session → 连接向日葵 → 内嵌远程桌面
//
//  注意：本页面不直接持有 TCPSocketManager delegate，
//        由 DeviceControlViewController 转发 TCP 消息。
//
//  方案：使用 CGAffineTransform 旋转实现横屏显示，
//        不改变系统屏幕方向，始终保持 portrait。
//

import UIKit

/// 启动模式：描述四种不同入口的流程差异
enum LaunchMode {
    case streaming(StreamingType)  // 流媒体：启动APP → get_session → 连接
    case nas                       // NAS：get_session → 等2秒 → launchNAS → 连接
    case settings                  // 设置：get_session → 等2秒 → launchSettings → 连接
    case screenMirror              // 屏幕互动：get_session → 直接连接
    
    var displayName: String {
        switch self {
        case .streaming(let type): return type.rawValue.uppercased()
        case .nas: return "NAS"
        case .settings: return "设置"
        case .screenMirror: return "屏幕互动"
        }
    }
}

class StreamingLaunchViewController: BaseViewController {
    
    // MARK: - Properties
    
    private let launchMode: LaunchMode
    
    /// 启动流程状态
    private enum LaunchState {
        case idle
        case waitingAppAck
        case waitingSession
        case connecting
        case connected        // 已连入远程桌面
    }
    
    private var launchState: LaunchState = .idle
    
    /// 是否已经内嵌了远程桌面
    private var remoteViewEmbedded = false
    
    /// 向日葵 SDK 返回的远程桌面 ViewController
    private var remoteDesktopVC: UIViewController?
    
    // MARK: - Error UI
    
    private var errorLabel: UILabel?
    private var errorButton: UIButton?
    
    // MARK: - 远程桌面 UI（旋转方式实现横屏）
    
    /// 旋转容器 — 通过 CGAffineTransform 旋转 90° 实现横屏显示
    /// 宽度 = 屏幕高度，高度 = 屏幕宽度，居中后旋转
    private lazy var rotatedContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.clipsToBounds = true
        return v
    }()
    
    /// 远程桌面容器（在旋转容器内部）
    private lazy var remoteDesktopContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }()
    
    /// 底部控制栏（在旋转容器内部）
    private lazy var bottomControlBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        return v
    }()
    
    /// 底部按钮容器
    private lazy var buttonStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        return stack
    }()
    
    /// 后退按钮 — 发送向日葵返回键
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: "chevron.backward", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return button
    }()
    
    /// 菜单按钮 — 发送向日葵菜单键
    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: "line.3.horizontal", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        return button
    }()
    
    /// 关闭远程桌面按钮
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.tintColor = .systemRed
        button.addTarget(self, action: #selector(remoteCloseTapped), for: .touchUpInside)
        return button
    }()
    

    
    // MARK: - Orientation（始终保持竖屏）
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Initialization
    
    init(mode: LaunchMode) {
        self.launchMode = mode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if ScreenMirrorService.shared.delegate === self {
            ScreenMirrorService.shared.delegate = nil
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 彻底隐藏导航栏和返回按钮
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = nil
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .background
        startLaunch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        hideEmbeddedNavigationIfNeeded()
    }
    
    // MARK: - Setup Loading UI
    

    
    // MARK: - Setup Remote Desktop UI（旋转横屏布局）
    
    /// 设置旋转容器及远程桌面布局
    /// - 底部按钮栏直接放在 view 上（不旋转），固定在屏幕底部
    /// - 远程桌面放在旋转容器内，通过 CGAffineTransform 实现横屏
    private func setupRemoteDesktopUI() {
        view.backgroundColor = .black
        
        // ── 1. 底部控制栏（不旋转，固定在屏幕底部）──
        view.addSubviewWithAutoLayout(bottomControlBar)
        
        buttonStackView.addArrangedSubview(backButton)
        buttonStackView.addArrangedSubview(menuButton)
        buttonStackView.addArrangedSubview(closeButton)
        bottomControlBar.addSubviewWithAutoLayout(buttonStackView)
        
        // 顶部分隔线
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        bottomControlBar.addSubviewWithAutoLayout(separator)
        
        NSLayoutConstraint.activate([
            // 底部栏 — 屏幕最底部
            bottomControlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomControlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomControlBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 按钮容器
            buttonStackView.topAnchor.constraint(equalTo: bottomControlBar.topAnchor),
            buttonStackView.leadingAnchor.constraint(equalTo: bottomControlBar.leadingAnchor),
            buttonStackView.trailingAnchor.constraint(equalTo: bottomControlBar.trailingAnchor),
            buttonStackView.bottomAnchor.constraint(equalTo: bottomControlBar.safeAreaLayoutGuide.bottomAnchor),
            buttonStackView.heightAnchor.constraint(equalToConstant: 60),
            
            // 分隔线
            separator.topAnchor.constraint(equalTo: bottomControlBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bottomControlBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bottomControlBar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        // ── 2. 远程桌面区域（bottomControlBar 上方）──
        view.addSubviewWithAutoLayout(remoteDesktopContainer)
        NSLayoutConstraint.activate([
            remoteDesktopContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            remoteDesktopContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteDesktopContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            remoteDesktopContainer.bottomAnchor.constraint(equalTo: bottomControlBar.topAnchor)
        ])
        
        // ── 3. 旋转容器（在远程桌面区域内，旋转 90° 显示横屏内容）──
        remoteDesktopContainer.addSubview(rotatedContainer)
        rotatedContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rotatedContainer.centerXAnchor.constraint(equalTo: remoteDesktopContainer.centerXAnchor),
            rotatedContainer.centerYAnchor.constraint(equalTo: remoteDesktopContainer.centerYAnchor),
            rotatedContainer.widthAnchor.constraint(equalTo: remoteDesktopContainer.heightAnchor),
            rotatedContainer.heightAnchor.constraint(equalTo: remoteDesktopContainer.widthAnchor)
        ])
        

        
        // 先让布局生效，再应用旋转 transform
        view.layoutIfNeeded()
        rotatedContainer.transform = CGAffineTransform(rotationAngle: .pi / 2)
    }
    
    // MARK: - Launch Flow
    
    /// 开始启动流程
    private func startLaunch() {
        ScreenMirrorService.shared.delegate = self
        
        switch launchMode {
        case .streaming(let type):
            // 流媒体：先启动 APP，等待 ack 后再请求 session
            launchState = .waitingAppAck
            showLoading(message: "正在启动 \(type.rawValue.uppercased())...")
            TCPSocketManager.shared.send(command: CommandBuilder.launchStreaming(type)) { [weak self] error in
                guard let self = self, let error = error else { return }
                self.showError("发送启动指令失败：\(error.localizedDescription)")
            }
            
        case .nas:
            // NAS：直接请求 session
            launchState = .waitingSession
            showLoading(message: "正在连接 NAS...")
            TCPSocketManager.shared.send(command: CommandBuilder.getSession()) { [weak self] error in
                guard let self = self, let error = error else { return }
                self.showError("请求会话失败：\(error.localizedDescription)")
            }
            
        case .settings:
            // 设置：直接请求 session
            launchState = .waitingSession
            showLoading(message: "正在连接设置...")
            TCPSocketManager.shared.send(command: CommandBuilder.getSession()) { [weak self] error in
                guard let self = self, let error = error else { return }
                self.showError("请求会话失败：\(error.localizedDescription)")
            }
            
        case .screenMirror:
            // 屏幕互动：直接请求 session
            launchState = .waitingSession
            showLoading(message: "正在连接屏幕互动...")
            TCPSocketManager.shared.send(command: CommandBuilder.getSession()) { [weak self] error in
                guard let self = self, let error = error else { return }
                self.showError("请求会话失败：\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public: 接收 DeviceControlViewController 转发的 TCP 数据
    
    func handleTCPData(_ data: [String: Any], command: String) {
        switch command {
        case "app":
            handleAppStartResponse(data)
        case "get_session", "screen_mirror_session":
            handleSessionResponse(data)
        default:
            break
        }
    }
    
    // MARK: - Private Flow Handlers
    
    /// 处理 app/start 回包（仅流媒体模式使用）
    private func handleAppStartResponse(_ data: [String: Any]) {
        guard launchState == .waitingAppAck else { return }
        guard (data["action"] as? String) == "start" else { return }
        
        // 仅流媒体模式需要检查 package
        guard case .streaming(let type) = launchMode else { return }
        
        let package = (data["package"] as? String)?.lowercased()
        guard package == type.rawValue else { return }
        
        let resultCode = parseResultCode(from: data["result"]) ?? -1
        guard resultCode == 0 else {
            showError("\(type.rawValue.uppercased()) 启动失败，返回码：\(resultCode)")
            return
        }
        
        // 收到启动成功，直接请求 session（无延时）
        launchState = .waitingSession
        showLoading(message: "正在获取会话...")
        TCPSocketManager.shared.send(command: CommandBuilder.getSession()) { [weak self] error in
            guard let self = self, let error = error else { return }
            self.showError("请求会话失败：\(error.localizedDescription)")
        }
    }
    
    /// 处理 get_session 回包
    private func handleSessionResponse(_ data: [String: Any]) {
        guard launchState == .waitingSession else { return }
        guard let sessionInfo = parseSessionInfo(from: data) else {
            showError("会话信息格式无效")
            return
        }
        
        switch launchMode {
        case .nas:
            // NAS：收到 session 后，等 2 秒发 launchNAS，然后连接
            showLoading(message: "正在启动 NAS...")
            self.connectSunflower(with: sessionInfo)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                TCPSocketManager.shared.send(command: CommandBuilder.launchNAS())
            }
            
        case .settings:
            // 设置：收到 session 后，等 2 秒发 launchSettings，然后连接
            showLoading(message: "正在启动设置...")
            self.connectSunflower(with: sessionInfo)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                TCPSocketManager.shared.send(command: CommandBuilder.launchSettings())
            }
            
        case .streaming, .screenMirror:
            // 流媒体 / 屏幕互动：收到 session 后直接连接
            connectSunflower(with: sessionInfo)
        }
    }
    
    /// 连接向日葵远程桌面
    private func connectSunflower(with sessionInfo: SessionInfo) {
        launchState = .connecting
        showLoading(message: "正在连接远程桌面...")
        
        // 创建配置，隐藏向日葵默认 UI
        let config = SCCDesktopConfig()
        config.isEnableUI = false
        config.isShowStatusBar = false
        
        ScreenMirrorService.shared.connect(
            address: sessionInfo.address,
            session: sessionInfo.session,
            soundSession: sessionInfo.soundSession,
            system: .android,
            config: config
        ) { [weak self] viewController in
            guard let self = self else { return }
            guard let remoteVC = viewController else {
                self.showError("无法创建远程桌面")
                return
            }
            guard !self.remoteViewEmbedded else { return }
            self.remoteViewEmbedded = true
            self.launchState = .connected
            
            // 直接在本页面内嵌远程桌面（旋转方式横屏）
            self.embedRemoteDesktop(remoteVC)
        }
    }
    
    // MARK: - 内嵌远程桌面（旋转方式横屏）
    
    /// 隐藏 loading UI，设置旋转横屏布局，嵌入远程桌面 VC
    private func embedRemoteDesktop(_ remoteVC: UIViewController) {
        // 1. 设置远程桌面 UI（旋转容器 + 底部按钮栏）
        setupRemoteDesktopUI()
        
        // 2. 将向日葵远程桌面 VC 以 child VC 方式内嵌到旋转容器
        print("[StreamingLaunch] embed remoteVC type: \(type(of: remoteVC))")
        prepareRemoteDesktopController(remoteVC)
        self.remoteDesktopVC = remoteVC
        addChild(remoteVC)
        rotatedContainer.addSubviewWithAutoLayout(remoteVC.view)
        remoteVC.view.fillSuperview()
        remoteVC.didMove(toParent: self)
        hideEmbeddedNavigationIfNeeded()
        
        // 3. 继续显示 Loading
        showLoading(message: "正在连接远程桌面...")
        
        setNeedsStatusBarAppearanceUpdate()
        
        print("[StreamingLaunch] remote desktop embedded with rotation transform")
    }
    
    /// 规范化向日葵返回的 VC，避免出现 SDK 导航 UI
    private func prepareRemoteDesktopController(_ remoteVC: UIViewController) {
        remoteVC.additionalSafeAreaInsets = .zero
        remoteVC.view.backgroundColor = .black
        
        if let navController = remoteVC as? UINavigationController {
            navController.setNavigationBarHidden(true, animated: false)
            navController.setToolbarHidden(true, animated: false)
            navController.navigationBar.isHidden = true
            navController.navigationBar.alpha = 0
        }
    }
    
    /// 兜底隐藏嵌入子控制器可能出现的导航栏
    private func hideEmbeddedNavigationIfNeeded() {
        if let navController = remoteDesktopVC as? UINavigationController {
            navController.setNavigationBarHidden(true, animated: false)
            navController.setToolbarHidden(true, animated: false)
            navController.navigationBar.isHidden = true
        } else {
            remoteDesktopVC?.navigationController?.setNavigationBarHidden(true, animated: false)
            remoteDesktopVC?.navigationController?.navigationBar.isHidden = true
        }
    }
    
    // MARK: - Remote Loading
    

    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        launchState = .idle
        hideLoading(animated: true)
        
        // 如果已显示错误页，仅更新文字
        if let label = errorLabel {
            label.text = message
            return
        }
        
        // 显示错误信息
        let label = UILabel()
        label.text = message
        label.textColor = .systemRed
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        
        let button = UIButton(type: .system)
        button.setTitle("返回", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .accent
        button.setCornerRadius(12)
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        view.addSubviewWithAutoLayout(label)
        view.addSubviewWithAutoLayout(button)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 30),
            button.widthAnchor.constraint(equalToConstant: 120),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        self.errorLabel = label
        self.errorButton = button
    }
    
    // MARK: - Actions
    
    /// loading 阶段关闭按钮
    @objc private func closeTapped() {
        print("[User Action] StreamingLaunch - closeTapped")
        ScreenMirrorService.shared.disconnect()
        navigationController?.popViewController(animated: true)
    }
    
    /// 后退 — 发送向日葵返回键（保持横屏不退出）
    @objc private func backTapped() {
        print("[User Action] StreamingLaunch - backTapped (Sunlogin androidClickBack)")
        ScreenMirrorService.shared.androidClickBack()
    }
    
    /// 菜单 — 发送向日葵菜单键
    @objc private func menuTapped() {
        print("[User Action] StreamingLaunch - menuTapped (Sunlogin androidClickMenu)")
        ScreenMirrorService.shared.androidClickMenu()
    }
    
    /// 结束远程桌面 — 确认后断开连接并 pop
    @objc private func remoteCloseTapped() {
        print("[User Action] StreamingLaunch - remoteCloseTapped")
        let alert = UIAlertController(
            title: "结束远程桌面",
            message: "确定要结束远程桌面操控吗？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            self?.disconnectAndPop()
        })
        present(alert, animated: true)
    }
    
    /// 断开向日葵连接，移除子 VC，pop 回上一页
    private func disconnectAndPop() {
        // 防止重复调用
        guard launchState != .idle else { return }
        launchState = .idle
        
        ScreenMirrorService.shared.disconnect()
        
        // 移除远程桌面子控制器
        if let remoteVC = remoteDesktopVC {
            remoteVC.willMove(toParent: nil)
            remoteVC.view.removeFromSuperview()
            remoteVC.removeFromParent()
            self.remoteDesktopVC = nil
        }
        
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Session Parsing
    
    private struct SessionInfo {
        let address: String
        let session: String
        let soundSession: String?
    }
    
    private func parseResultCode(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }
    
    private func parseSessionInfo(from data: [String: Any]) -> SessionInfo? {
        if let resultString = data["result"] as? String,
           let resultData = resultString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: resultData, options: []),
           let resultDict = jsonObject as? [String: Any] {
            return makeSessionInfo(from: resultDict)
        }
        if let resultDict = data["result"] as? [String: Any] {
            return makeSessionInfo(from: resultDict)
        }
        return makeSessionInfo(from: data)
    }
    
    private func makeSessionInfo(from dict: [String: Any]) -> SessionInfo? {
        guard let rawAddress = dict["address"] as? String,
              let session = dict["session"] as? String,
              !rawAddress.isEmpty,
              !session.isEmpty else {
            return nil
        }
        let address = cleanSunflowerAddress(rawAddress)
        return SessionInfo(address: address, session: session, soundSession: dict["sound_session"] as? String)
    }
    
    private func cleanSunflowerAddress(_ raw: String) -> String {
        let validPrefixes = ["PHSRC://", "PHSRC_HTTPS://"]
        let segments = raw.split(separator: ";", omittingEmptySubsequences: true)
        let filtered = segments.filter { segment in
            validPrefixes.contains(where: { segment.hasPrefix($0) })
        }
        let cleaned = filtered.map(String.init).joined(separator: ";") + ";"
        print("[ScreenMirror] address cleaned: \(raw) -> \(cleaned)")
        return cleaned
    }
}

// MARK: - ScreenMirrorServiceDelegate

extension StreamingLaunchViewController: ScreenMirrorServiceDelegate {
    
    func screenMirrorService(_ service: ScreenMirrorService, didChangeState state: ScreenMirrorState) {
        switch state {
        case .connected:
            print("[StreamingLaunch] mirror connected")
        case .failed(let error):
            print("[StreamingLaunch] mirror failed: \(error)")
            if launchState == .connecting {
                showError("向日葵连接失败：\(error)")
            }
        case .disconnected:
            print("[StreamingLaunch] mirror disconnected")
            if launchState == .connecting {
                showError("向日葵连接断开")
            } else if launchState == .connected {
                // 远程桌面断开，自动退出
                disconnectAndPop()
            }
        default:
            break
        }
    }
    
    func screenMirrorServiceDidDesktopAppear(_ service: ScreenMirrorService) {
        print("[StreamingLaunch] desktop appeared, hiding remote loading")
        hideLoading()
    }
}
