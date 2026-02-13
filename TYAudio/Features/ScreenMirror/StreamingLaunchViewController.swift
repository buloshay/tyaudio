//
//  StreamingLaunchViewController.swift
//  TYAudio
//
//  流媒体启动页（全流程）
//  处理 启动APP → 请求session → 连接向日葵 → 内嵌远程桌面
//
//  注意：本页面不直接持有 TCPSocketManager delegate，
//        由 DeviceControlViewController 转发 TCP 消息。
//
//  方案：使用 CGAffineTransform 旋转实现横屏显示，
//        不改变系统屏幕方向，始终保持 portrait。
//

import UIKit

class StreamingLaunchViewController: BaseViewController {
    
    // MARK: - Properties
    
    private let streamingType: StreamingType
    
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
    
    // MARK: - UI Components（loading 阶段使用）
    
    /// Loading 指示器
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .accent
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    /// 状态文字
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "正在启动..."
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    /// loading 阶段的容器视图
    private lazy var loadingContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .background
        return v
    }()
    
    /// 返回按钮（错误时显示）
    private var errorReturnButton: UIButton?
    
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
    
    /// Loading 遮罩层（覆盖在远程桌面之上）
    private lazy var remoteLoadingOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0, alpha: 0.8)
        return v
    }()
    
    /// 远程桌面 Loading 指示器
    private lazy var remoteLoadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    /// 远程桌面 Loading 文字
    private lazy var remoteLoadingLabel: UILabel = {
        let label = UILabel()
        label.text = "正在连接远程桌面..."
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
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
    
    init(type: StreamingType) {
        self.streamingType = type
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
        setupLoadingUI()
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
    
    private func setupLoadingUI() {
        view.backgroundColor = .background
        
        // 使用 loadingContainerView 包裹所有 loading 阶段 UI
        view.addSubviewWithAutoLayout(loadingContainerView)
        loadingContainerView.fillSuperview()
    }
    
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
        
        // ── 4. Loading 遮罩层（覆盖整个远程桌面区域，不旋转）──
        view.addSubviewWithAutoLayout(remoteLoadingOverlay)
        remoteLoadingOverlay.addSubviewWithAutoLayout(remoteLoadingIndicator)
        remoteLoadingOverlay.addSubviewWithAutoLayout(remoteLoadingLabel)
        
        NSLayoutConstraint.activate([
            remoteLoadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            remoteLoadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteLoadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            remoteLoadingOverlay.bottomAnchor.constraint(equalTo: bottomControlBar.topAnchor),
            
            remoteLoadingIndicator.centerXAnchor.constraint(equalTo: remoteLoadingOverlay.centerXAnchor),
            remoteLoadingIndicator.centerYAnchor.constraint(equalTo: remoteLoadingOverlay.centerYAnchor, constant: -20),
            
            remoteLoadingLabel.topAnchor.constraint(equalTo: remoteLoadingIndicator.bottomAnchor, constant: 16),
            remoteLoadingLabel.centerXAnchor.constraint(equalTo: remoteLoadingOverlay.centerXAnchor)
        ])
        
        // 先让布局生效，再应用旋转 transform
        view.layoutIfNeeded()
        rotatedContainer.transform = CGAffineTransform(rotationAngle: .pi / 2)
    }
    
    // MARK: - Launch Flow
    
    /// 开始启动流程
    private func startLaunch() {
        launchState = .waitingAppAck
        statusLabel.text = "正在启动 \(streamingType.rawValue.uppercased())..."
        loadingIndicator.startAnimating()
        
        ScreenMirrorService.shared.delegate = self
        
        // 发送启动指令（TCP 消息由 DeviceControlViewController 转发）
        TCPSocketManager.shared.send(command: CommandBuilder.launchStreaming(streamingType)) { [weak self] error in
            guard let self = self, let error = error else { return }
            self.showError("发送启动指令失败：\(error.localizedDescription)")
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
    
    /// 处理 app/start 回包
    private func handleAppStartResponse(_ data: [String: Any]) {
        guard launchState == .waitingAppAck else { return }
        guard (data["action"] as? String) == "start" else { return }
        
        let package = (data["package"] as? String)?.lowercased()
        guard package == streamingType.rawValue else { return }
        
        let resultCode = parseResultCode(from: data["result"]) ?? -1
        guard resultCode == 0 else {
            showError("\(streamingType.rawValue.uppercased()) 启动失败，返回码：\(resultCode)")
            return
        }
        
        // 收到启动成功，直接请求 session（无延时）
        launchState = .waitingSession
        statusLabel.text = "正在获取会话..."
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
        
        launchState = .connecting
        statusLabel.text = "正在连接远程桌面..."
        
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
        // 1. 隐藏 loading 容器
        loadingContainerView.isHidden = true
        loadingIndicator.stopAnimating()
        
        // 2. 设置远程桌面 UI（旋转容器 + 底部按钮栏）
        setupRemoteDesktopUI()
        
        // 3. 将向日葵远程桌面 VC 以 child VC 方式内嵌到旋转容器
        print("[StreamingLaunch] embed remoteVC type: \(type(of: remoteVC))")
        prepareRemoteDesktopController(remoteVC)
        self.remoteDesktopVC = remoteVC
        addChild(remoteVC)
        rotatedContainer.addSubviewWithAutoLayout(remoteVC.view)
        remoteVC.view.fillSuperview()
        remoteVC.didMove(toParent: self)
        hideEmbeddedNavigationIfNeeded()
        
        // 4. 显示 loading 遮罩
        remoteLoadingOverlay.isHidden = false
        remoteLoadingIndicator.startAnimating()
        
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
    
    private func hideRemoteLoading() {
        UIView.animate(withDuration: 0.3) {
            self.remoteLoadingOverlay.alpha = 0
        } completion: { _ in
            self.remoteLoadingOverlay.isHidden = true
            self.remoteLoadingIndicator.stopAnimating()
            self.remoteLoadingOverlay.alpha = 1  // 重置以便复用
        }
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        launchState = .idle
        loadingIndicator.stopAnimating()
        statusLabel.text = message
        statusLabel.textColor = .systemRed
        
        guard errorReturnButton == nil else { return }
        let button = UIButton(type: .system)
        button.setTitle("返回", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .accent
        button.setCornerRadius(12)
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        loadingContainerView.addSubviewWithAutoLayout(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            button.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 30),
            button.widthAnchor.constraint(equalToConstant: 120),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        errorReturnButton = button
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
        hideRemoteLoading()
    }
}
