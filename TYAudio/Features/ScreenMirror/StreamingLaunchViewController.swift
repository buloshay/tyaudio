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

/// 启动模式：描述不同入口的流程差异
enum LaunchMode {
    case streaming(StreamingType)  // 流媒体：启动APP → get_session → 连接
    case app(AppItem)              // 应用：启动APP → get_session → 连接（同流媒体流程）
    case nas                       // NAS：get_session → 等2秒 → launchNAS → 连接
    case settings                  // 设置：get_session → 等2秒 → launchSettings → 连接
    case screenMirror              // 屏幕互动：get_session → 直接连接
    
    var displayName: String {
        switch self {
        case .streaming(let type): return type.rawValue.uppercased()
        case .app(let appItem): return appItem.title
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
    private var retryButton: UIButton?
    
    /// 响应超时计时器（15秒）
    private var responseTimeoutTimer: Timer?
    /// 当前重试次数
    private var retryCount: Int = 0
    /// 最大重试次数
    private let maxRetryCount: Int = 1
    
    /// SDK 连接超时计时器（6秒）
    private var sdkConnectionTimer: Timer?
    /// SDK 连接重试次数
    private var sdkRetryCount: Int = 0
    /// 最大 SDK 重试次数
    private let maxSdkRetryCount: Int = 3
    /// 缓存最近的 session 信息，重试时使用
    private var lastSessionInfo: SessionInfo?
    /// 是否已经显示了提前退出按钮
    private var earlyCloseButtonShown = false
    
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
        cancelResponseTimeout()
        cancelSdkConnectionTimeout()
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
            startResponseTimeout()
            TCPSocketManager.shared.sendWithTimeout(command: CommandBuilder.launchStreaming(type)) { [weak self] error in
                guard let self = self, let error = error else { return }
                // 发送超时或失败，取消响应计时器（避免双重错误提示）
                self.cancelResponseTimeout()
                self.showError("发送启动指令失败：\(error.localizedDescription)")
            }
            
        case .app(let appItem):
            // 应用：先启动 APP，等待 ack 后再请求 session（与流媒体流程相同）
            launchState = .waitingAppAck
            showLoading(message: "正在启动 \(appItem.title)...")
            startResponseTimeout()
            TCPSocketManager.shared.sendWithTimeout(command: CommandBuilder.launchApp(package: appItem.packageName)) { [weak self] error in
                guard let self = self, let error = error else { return }
                self.cancelResponseTimeout()
                self.showError("发送启动指令失败：\(error.localizedDescription)")
            }
            
        case .nas:
            // NAS：直接请求 session
            launchState = .waitingSession
            showLoading(message: "正在连接 NAS...")
            startResponseTimeout()
            TCPSocketManager.shared.sendWithTimeout(command: CommandBuilder.getSession()) { [weak self] error in
                guard let self = self, let error = error else { return }
                self.cancelResponseTimeout()
                self.showError("请求会话失败：\(error.localizedDescription)")
            }
            
        case .settings:
            // 设置：直接请求 session
            launchState = .waitingSession
            showLoading(message: "正在连接设置...")
            startResponseTimeout()
            TCPSocketManager.shared.sendWithTimeout(command: CommandBuilder.getSession()) { [weak self] error in
                guard let self = self, let error = error else { return }
                self.cancelResponseTimeout()
                self.showError("请求会话失败：\(error.localizedDescription)")
            }
            
        case .screenMirror:
            // 屏幕互动：直接请求 session
            launchState = .waitingSession
            showLoading(message: "正在连接屏幕互动...")
            startResponseTimeout()
            TCPSocketManager.shared.sendWithTimeout(command: CommandBuilder.getSession()) { [weak self] error in
                guard let self = self, let error = error else { return }
                self.cancelResponseTimeout()
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
        
        // 收到响应，取消超时计时
        cancelResponseTimeout()
        
        guard (data["action"] as? String) == "start" else { return }
        
        // 根据模式检查 package
        let expectedPackage: String
        let displayName: String
        
        switch launchMode {
        case .streaming(let type):
            expectedPackage = type.rawValue
            displayName = type.rawValue.uppercased()
        case .app(let appItem):
            expectedPackage = appItem.packageName
            displayName = appItem.title
        default:
            return
        }
        
        let package = (data["package"] as? String)?.lowercased()
        guard package == expectedPackage.lowercased() else { return }
        
        let resultCode = parseResultCode(from: data["result"]) ?? -1
        guard resultCode == 0 else {
            showError("\(displayName) 启动失败，返回码：\(resultCode)")
            return
        }
        
        // 收到启动成功，直接请求 session（无延时）
        launchState = .waitingSession
        showLoading(message: "正在获取会话...")
        startResponseTimeout()
        TCPSocketManager.shared.sendWithTimeout(command: CommandBuilder.getSession()) { [weak self] error in
            guard let self = self, let error = error else { return }
            self.cancelResponseTimeout()
            self.showError("请求会话失败：\(error.localizedDescription)")
        }
    }
    
    /// 处理 get_session 回包
    private func handleSessionResponse(_ data: [String: Any]) {
        guard launchState == .waitingSession else { return }
        
        // 收到响应，取消超时计时
        cancelResponseTimeout()
        
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
            
        case .streaming, .app, .screenMirror:
            // 流媒体 / 应用 / 屏幕互动：收到 session 后直接连接
            connectSunflower(with: sessionInfo)
        }
    }
    
    /// 连接向日葵远程桌面
    private func connectSunflower(with sessionInfo: SessionInfo) {
        launchState = .connecting
        lastSessionInfo = sessionInfo
        
        let retryHint = sdkRetryCount > 0 ? "（第 \(sdkRetryCount) 次重连）" : ""
        showLoading(message: "正在连接远程桌面...\(retryHint)")
        
        // 提前显示关闭按钮，允许用户在连接阶段退出
        setupEarlyCloseButton()
        
        // 启动 SDK 连接超时检测（6秒）
        startSdkConnectionTimeout()
        
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
                self.cancelSdkConnectionTimeout()
                self.showError("无法创建远程桌面")
                return
            }
            guard !self.remoteViewEmbedded else { return }
            self.remoteViewEmbedded = true
            self.launchState = .connected
            self.cancelSdkConnectionTimeout()
            self.sdkRetryCount = 0
            
            // 直接在本页面内嵌远程桌面（旋转方式横屏）
            self.embedRemoteDesktop(remoteVC)
        }
    }
    
    /// 在 loading 阶段提前显示关闭按钮，方便用户退出
    private func setupEarlyCloseButton() {
        guard !earlyCloseButtonShown else { return }
        earlyCloseButtonShown = true
        
        // 添加底部控制栏（仅含关闭按钮）
        view.addSubviewWithAutoLayout(bottomControlBar)
        
        // 只放一个关闭按钮
        let earlyCloseStack = UIStackView()
        earlyCloseStack.axis = .horizontal
        earlyCloseStack.distribution = .fillEqually
        earlyCloseStack.spacing = 0
        earlyCloseStack.addArrangedSubview(closeButton)
        bottomControlBar.addSubviewWithAutoLayout(earlyCloseStack)
        
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        bottomControlBar.addSubviewWithAutoLayout(separator)
        
        NSLayoutConstraint.activate([
            bottomControlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomControlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomControlBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            earlyCloseStack.topAnchor.constraint(equalTo: bottomControlBar.topAnchor),
            earlyCloseStack.leadingAnchor.constraint(equalTo: bottomControlBar.leadingAnchor),
            earlyCloseStack.trailingAnchor.constraint(equalTo: bottomControlBar.trailingAnchor),
            earlyCloseStack.bottomAnchor.constraint(equalTo: bottomControlBar.safeAreaLayoutGuide.bottomAnchor),
            earlyCloseStack.heightAnchor.constraint(equalToConstant: 60),
            
            separator.topAnchor.constraint(equalTo: bottomControlBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bottomControlBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bottomControlBar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
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
        cancelResponseTimeout()
        
        // 清理旧视图
        errorLabel?.removeFromSuperview()
        errorButton?.removeFromSuperview()
        retryButton?.removeFromSuperview()
        
        // 显示错误信息
        let label = UILabel()
        label.text = message
        label.textColor = .systemRed
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        
        // 返回按钮
        let backBtn = UIButton(type: .system)
        backBtn.setTitle("返回", for: .normal)
        backBtn.setTitleColor(.white, for: .normal)
        backBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        backBtn.backgroundColor = .systemGray
        backBtn.setCornerRadius(12)
        backBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        view.addSubviewWithAutoLayout(label)
        view.addSubviewWithAutoLayout(backBtn)
        
        // 布局 Label
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
        
        // 检查是否可以重试
        if retryCount < maxRetryCount {
            print("[StreamingLaunch] Showing retry button (retryCount: \(retryCount))")
            
            let retryBtn = UIButton(type: .system)
            retryBtn.setTitle("重试", for: .normal)
            retryBtn.setTitleColor(.white, for: .normal)
            retryBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            retryBtn.backgroundColor = .accent
            retryBtn.setCornerRadius(12)
            retryBtn.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
            
            view.addSubviewWithAutoLayout(retryBtn)
            
            NSLayoutConstraint.activate([
                retryBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                retryBtn.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 30),
                retryBtn.widthAnchor.constraint(equalToConstant: 120),
                retryBtn.heightAnchor.constraint(equalToConstant: 44),
                
                backBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                backBtn.topAnchor.constraint(equalTo: retryBtn.bottomAnchor, constant: 16),
                backBtn.widthAnchor.constraint(equalToConstant: 120),
                backBtn.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            self.retryButton = retryBtn
        } else {
            // 超过重试次数，只显示返回
            NSLayoutConstraint.activate([
                backBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                backBtn.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 30),
                backBtn.widthAnchor.constraint(equalToConstant: 120),
                backBtn.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
        
        self.errorLabel = label
        self.errorButton = backBtn
    }
    
    // MARK: - Actions
    
    /// 重试按钮点击
    @objc private func retryTapped() {
        print("[User Action] StreamingLaunch - retryTapped")
        retryCount += 1
        
        // 清理错误 UI
        errorLabel?.removeFromSuperview()
        errorButton?.removeFromSuperview()
        retryButton?.removeFromSuperview()
        errorLabel = nil
        errorButton = nil
        retryButton = nil
        
        // 重新开始启动流程
        startLaunch()
    }
    
    /// 开启响应超时
    private func startResponseTimeout() {
        cancelResponseTimeout()
        print("[StreamingLaunch] Starting 15s response timeout")
        responseTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.handleResponseTimeout()
        }
    }

    /// 取消响应超时
    private func cancelResponseTimeout() {
        if responseTimeoutTimer != nil {
             print("[StreamingLaunch] Cancelling response timeout")
             responseTimeoutTimer?.invalidate()
             responseTimeoutTimer = nil
        }
    }

    /// 响应超时处理
    private func handleResponseTimeout() {
        print("[StreamingLaunch] Response timeout triggered")
        showError("连接超时，设备没有响应")
    }
    
    // MARK: - SDK Connection Timeout
    
    /// 开启 SDK 连接超时检测（6秒）
    private func startSdkConnectionTimeout() {
        cancelSdkConnectionTimeout()
        print("[StreamingLaunch] Starting 6s SDK connection timeout (retry \(sdkRetryCount)/\(maxSdkRetryCount))")
        sdkConnectionTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            self?.handleSdkConnectionTimeout()
        }
    }
    
    /// 取消 SDK 连接超时
    private func cancelSdkConnectionTimeout() {
        if sdkConnectionTimer != nil {
            print("[StreamingLaunch] Cancelling SDK connection timeout")
            sdkConnectionTimer?.invalidate()
            sdkConnectionTimer = nil
        }
    }
    
    /// SDK 连接超时处理：断开当前连接，重新请求 session 并重连
    private func handleSdkConnectionTimeout() {
        print("[StreamingLaunch] SDK connection timeout triggered (retry \(sdkRetryCount)/\(maxSdkRetryCount))")
        
        // 断开当前连接
        ScreenMirrorService.shared.disconnect()
        
        guard sdkRetryCount < maxSdkRetryCount else {
            showError("远程桌面连接超时，请检查网络或设备状态")
            return
        }
        
        sdkRetryCount += 1
        showLoading(message: "连接超时，正在第 \(sdkRetryCount) 次重连...")
        
        // 重新请求 session
        launchState = .waitingSession
        startResponseTimeout()
        TCPSocketManager.shared.sendWithTimeout(command: CommandBuilder.getSession()) { [weak self] error in
            guard let self = self, let error = error else { return }
            self.cancelResponseTimeout()
            self.showError("重新请求会话失败：\(error.localizedDescription)")
        }
    }
    
    /// loading 阶段关闭按钮
    @objc private func closeTapped() {
        print("[User Action] StreamingLaunch - closeTapped")
        cancelSdkConnectionTimeout()
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
    
    /// 结束远程桌面 — 已连接时确认后断开，连接中时直接退出
    @objc private func remoteCloseTapped() {
        print("[User Action] StreamingLaunch - remoteCloseTapped")
        if launchState == .connected {
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
        } else {
            // 连接中直接退出，不需要确认
            cancelSdkConnectionTimeout()
            ScreenMirrorService.shared.disconnect()
            navigationController?.popViewController(animated: true)
        }
    }
    
    /// 断开向日葵连接，移除子 VC，pop 回上一页
    private func disconnectAndPop() {
        // 防止重复调用
        guard launchState != .idle else { return }
        launchState = .idle
        cancelSdkConnectionTimeout()
        
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
            cancelSdkConnectionTimeout()
        case .failed(let error):
            print("[StreamingLaunch] mirror failed: \(error)")
            cancelSdkConnectionTimeout()
            if launchState == .connecting {
                showError("向日葵连接失败：\(error)")
            }
        case .disconnected:
            print("[StreamingLaunch] mirror disconnected")
            // 如果 SDK 超时重试中主动断开的，不要显示错误
            if sdkConnectionTimer != nil { break }
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
        cancelSdkConnectionTimeout()
        sdkRetryCount = 0
        hideLoading()
    }
}
