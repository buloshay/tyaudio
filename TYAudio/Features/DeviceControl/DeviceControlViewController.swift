//
//  DeviceControlViewController.swift
//  TYAudio
//
//  设备控制主页面
//

import UIKit

class DeviceControlViewController: BaseViewController {
    
    // MARK: - UI Components
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .textPrimary
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var deviceIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "hifispeaker.fill")
        imageView.tintColor = .accent
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var deviceNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()
    
    private lazy var connectionStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .playing
        label.text = "● 已连接"
        return label
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 120, right: 0)
        return scroll
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        return stack
    }()
    
    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.delegate = self
        return view
    }()
    
    // MARK: - Properties
    
    private var device: Device
    private var playState: PlayState?
    private var streamingLaunchState: StreamingLaunchState = .idle
    private var streamingSessionRetryCount = 0
    private let maxStreamingSessionRetryCount = 3
    private var streamingMirrorPresenting = false
    private var streamingRemoteViewPresented = false
    private let streamingRemoteSystems: [SCCRemoteSystem] = [.android, .linux]
    private var streamingRemoteSystemIndex = 0

    /// 流媒体启动流程状态：先等待 app/start 回包，再请求 get_session
    private enum StreamingLaunchState {
        case idle
        case waitingAppAck(StreamingType)
        case waitingSession(StreamingType)
    }

    /// 向日葵会话参数
    private struct ScreenMirrorSessionInfo {
        let address: String
        let session: String
        let soundSession: String?
    }
    
    // MARK: - Feature Sections
    
    private enum FeatureSection: CaseIterable {
        case storage
        case category
        case streaming
        case other
        
        var title: String {
            switch self {
            case .storage: return "存储"
            case .category: return "分类"
            case .streaming: return "流媒体"
            case .other: return "其他"
            }
        }
        
        var items: [FeatureItem] {
            switch self {
            case .storage:
                return [
                    FeatureItem(icon: "externaldrive.fill", title: "硬盘", action: .storage(.hardDrive)),
                    FeatureItem(icon: "usb.fill", title: "U盘", action: .storage(.usb)),
                    FeatureItem(icon: "sdcard.fill", title: "TF卡", action: .storage(.tfCard))
                ]
            case .category:
                return [
                    FeatureItem(icon: "music.note", title: "单曲", action: .category(.music)),
                    FeatureItem(icon: "square.stack", title: "专辑", action: .category(.album)),
                    FeatureItem(icon: "person.fill", title: "歌手", action: .category(.artist)),
                    FeatureItem(icon: "guitars.fill", title: "风格", action: .category(.style)),
                    FeatureItem(icon: "heart.fill", title: "收藏", action: .favorites)
                ]
            case .streaming:
                return [
                    FeatureItem(icon: "waveform", title: "Tidal", action: .streaming(.tidal)),
                    FeatureItem(icon: "waveform", title: "Qobuz", action: .streaming(.qobuz)),
                    FeatureItem(icon: "waveform", title: "Deezer", action: .streaming(.deezer)),
                    FeatureItem(icon: "waveform", title: "HIGHRESAUDIO", action: .streaming(.highresaudio))
                ]
            case .other:
                return [
                    FeatureItem(icon: "server.rack", title: "NAS", action: .nas),
                    FeatureItem(icon: "rectangles.group", title: "屏幕互动", action: .screenMirror),
                    FeatureItem(icon: "gearshape.fill", title: "设置", action: .settings),
                    FeatureItem(icon: "app.fill", title: "应用", action: .apps)
                ]
            }
        }
    }
    
    private struct FeatureItem {
        let icon: String
        let title: String
        let action: FeatureAction
    }
    
    private enum FeatureAction {
        case storage(StorageType)
        case category(CategoryType)
        case favorites
        case streaming(StreamingType)
        case nas
        case screenMirror
        case settings
        case apps
    }
    
    private enum StorageType {
        case hardDrive
        case usb
        case tfCard
        
        var path: String {
            switch self {
            case .hardDrive: return "/mnt/sda"
            case .usb: return "/mnt/usb"
            case .tfCard: return "/mnt/tf"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(device: Device) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("[DeviceControlViewController] deinit - disconnecting TCP")
        if ScreenMirrorService.shared.delegate === self {
            ScreenMirrorService.shared.delegate = nil
        }
        TCPSocketManager.shared.disconnect()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        connectToDevice()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        
        // Header
        view.addSubviewWithAutoLayout(headerView)
        headerView.addSubviewWithAutoLayout(backButton)
        headerView.addSubviewWithAutoLayout(deviceIconView)
        headerView.addSubviewWithAutoLayout(deviceNameLabel)
        headerView.addSubviewWithAutoLayout(connectionStatusLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 140),
            
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            backButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            deviceIconView.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            deviceIconView.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            deviceIconView.widthAnchor.constraint(equalToConstant: 36),
            deviceIconView.heightAnchor.constraint(equalToConstant: 36),
            
            deviceNameLabel.leadingAnchor.constraint(equalTo: deviceIconView.trailingAnchor, constant: 12),
            deviceNameLabel.topAnchor.constraint(equalTo: deviceIconView.topAnchor),
            
            connectionStatusLabel.leadingAnchor.constraint(equalTo: deviceNameLabel.leadingAnchor),
            connectionStatusLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 4)
        ])
        
        deviceNameLabel.text = device.displayName
        
        // Scroll View
        view.addSubviewWithAutoLayout(scrollView)
        scrollView.addSubviewWithAutoLayout(contentStackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // Add feature sections
        for section in FeatureSection.allCases {
            let sectionView = createSectionView(section)
            contentStackView.addArrangedSubview(sectionView)
        }
        
        // Mini Player
        view.addSubviewWithAutoLayout(miniPlayerView)
        NSLayoutConstraint.activate([
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            miniPlayerView.heightAnchor.constraint(equalToConstant: 70)
        ])
    }
    
    private func createSectionView(_ section: FeatureSection) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = section.title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .textPrimary
        
        container.addSubviewWithAutoLayout(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        ])
        
        let gridView = createGridView(for: section.items)
        container.addSubviewWithAutoLayout(gridView)
        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            gridView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createGridView(for items: [FeatureItem]) -> UIView {
        let container = UIView()
        var lastView: UIView?
        var currentRowViews: [UIView] = []
        let itemsPerRow = 4
        
        for (index, item) in items.enumerated() {
            let button = createFeatureButton(item)
            container.addSubviewWithAutoLayout(button)
            currentRowViews.append(button)
            
            if currentRowViews.count == itemsPerRow || index == items.count - 1 {
                // Layout row
                for (rowIndex, rowView) in currentRowViews.enumerated() {
                    let width = (UIScreen.main.bounds.width - 32 - CGFloat(itemsPerRow - 1) * 12) / CGFloat(itemsPerRow)
                    
                    NSLayoutConstraint.activate([
                        rowView.widthAnchor.constraint(equalToConstant: width),
                        rowView.heightAnchor.constraint(equalToConstant: 80)
                    ])
                    
                    if rowIndex == 0 {
                        rowView.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
                    } else {
                        rowView.leadingAnchor.constraint(equalTo: currentRowViews[rowIndex - 1].trailingAnchor, constant: 12).isActive = true
                    }
                    
                    if let last = lastView {
                        rowView.topAnchor.constraint(equalTo: last.bottomAnchor, constant: 12).isActive = true
                    } else {
                        rowView.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
                    }
                }
                
                lastView = currentRowViews.first
                currentRowViews = []
            }
        }
        
        if let last = lastView {
            last.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        }
        
        return container
    }
    
    private func createFeatureButton(_ item: FeatureItem) -> UIView {
        let button = UIButton(type: .custom)
        button.backgroundColor = .cardBackground
        button.setCornerRadius(12)
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: item.icon)
        iconView.tintColor = .accent
        iconView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .textPrimary
        titleLabel.textAlignment = .center
        
        button.addSubviewWithAutoLayout(iconView)
        button.addSubviewWithAutoLayout(titleLabel)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: button.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            
            titleLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4)
        ])
        
        button.addAction(UIAction { [weak self] _ in
            self?.handleFeatureAction(item.action)
        }, for: .touchUpInside)
        
        return button
    }
    
    // MARK: - Connection
    
    private func connectToDevice() {
        print("[User Action] DeviceControlViewController - connecting to device: \(device.displayName)")
        TCPSocketManager.shared.delegate = self
        TCPSocketManager.shared.connect(host: device.ipAddress, port: device.port)
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        print("[User Action] DeviceControlViewController - backTapped")
        TCPSocketManager.shared.disconnect()
        navigationController?.popViewController(animated: true)
    }
    
    private func handleFeatureAction(_ action: FeatureAction) {
        print("[User Action] DeviceControlViewController - handleFeatureAction: \(action)")
        switch action {
        case .storage(let type):
            let vc = FileBrowserViewController(path: type.path, title: type == .hardDrive ? "硬盘" : type == .usb ? "U盘" : "TF卡", shouldAutoEnterSingleRoot: true)
            navigationController?.pushViewController(vc, animated: true)
            
        case .category(let type):
            let vc = CategoryViewController(categoryType: type)
            navigationController?.pushViewController(vc, animated: true)
            
        case .favorites:
            let vc = FileBrowserViewController(path: "/", title: "收藏", isFavorites: true)
            navigationController?.pushViewController(vc, animated: true)
            
        case .streaming(let type):
            launchStreamingApp(type)
            
        case .nas:
            launchNAS()
            
        case .screenMirror:
            openScreenMirror()
            
        case .settings:
            launchSettings()
            
        case .apps:
            let vc = AppListViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func launchStreamingApp(_ type: StreamingType) {
        streamingSessionRetryCount = 0
        streamingMirrorPresenting = false
        streamingRemoteViewPresented = false
        streamingRemoteSystemIndex = 0
        ScreenMirrorService.shared.delegate = self
        streamingLaunchState = .waitingAppAck(type)
        TCPSocketManager.shared.send(command: CommandBuilder.launchStreaming(type)) { [weak self] error in
            guard let self = self, let error = error else { return }
            self.streamingLaunchState = .idle
            self.showAlert(title: "启动失败", message: "发送流媒体启动指令失败：\(error.localizedDescription)")
        }
    }
    
    private func launchNAS() {
        TCPSocketManager.shared.send(command: CommandBuilder.getSession())
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            TCPSocketManager.shared.send(command: CommandBuilder.launchNAS())
        }
    }
    
    private func launchSettings() {
        TCPSocketManager.shared.send(command: CommandBuilder.getSession())
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            TCPSocketManager.shared.send(command: CommandBuilder.launchSettings())
        }
    }
    
    private func openScreenMirror() {
        // TODO: 集成向日葵SDK
        let alert = UIAlertController(title: "屏幕互动", message: "即将打开屏幕镜像功能", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    /// 处理流媒体 app/start 回包，成功后请求 get_session
    private func handleStreamingAppResponse(_ data: [String: Any]) {
        guard case .waitingAppAck(let type) = streamingLaunchState else { return }
        guard (data["action"] as? String) == "start" else { return }

        let package = (data["package"] as? String)?.lowercased()
        guard package == type.rawValue else { return }

        let resultCode = parseResultCode(from: data["result"]) ?? -1
        guard resultCode == 0 else {
            streamingLaunchState = .idle
            showAlert(title: "启动失败", message: "\(type.rawValue) 启动失败，返回码：\(resultCode)")
            return
        }

        streamingLaunchState = .waitingSession(type)
        requestStreamingSession(type: type, delay: 3.0)
    }

    /// 处理 get_session 回包，成功后直接拉起向日葵远程控制
    private func handleStreamingSessionResponse(_ data: [String: Any]) {
        guard case .waitingSession(let type) = streamingLaunchState else { return }
        guard let sessionInfo = parseSessionInfo(from: data) else {
            streamingLaunchState = .idle
            showAlert(title: "连接失败", message: "会话信息格式无效")
            return
        }

        streamingMirrorPresenting = true
        let targetSystem: SCCRemoteSystem
        if streamingRemoteSystemIndex >= 0 && streamingRemoteSystemIndex < streamingRemoteSystems.count {
            targetSystem = streamingRemoteSystems[streamingRemoteSystemIndex]
        } else {
            targetSystem = .android
        }
        print("[ScreenMirror] try connect with system=\(targetSystem.rawValue)")
        ScreenMirrorService.shared.connect(
            address: sessionInfo.address,
            session: sessionInfo.session,
            soundSession: sessionInfo.soundSession,
            system: targetSystem
        ) { [weak self] viewController in
            guard let self = self else { return }
            guard let remoteVC = viewController else {
                self.streamingMirrorPresenting = false
                self.handleStreamingMirrorConnectFailure(for: type, message: "无法创建远程桌面")
                return
            }
            guard !self.streamingRemoteViewPresented else { return }
            self.streamingRemoteViewPresented = true
            remoteVC.modalPresentationStyle = .fullScreen
            self.present(remoteVC, animated: true)
        }
    }

    /// 获取流媒体远控会话，失败时统一收敛到一个错误出口
    private func requestStreamingSession(type: StreamingType, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            guard case .waitingSession(let expectedType) = self.streamingLaunchState, expectedType == type else { return }
            TCPSocketManager.shared.send(command: CommandBuilder.getSession()) { [weak self] error in
                guard let self = self, let error = error else { return }
                self.streamingLaunchState = .idle
                self.showAlert(title: "连接失败", message: "请求会话失败：\(error.localizedDescription)")
            }
        }
    }

    /// 向日葵连接失败时自动重取一次 session 再重连，提升会话未稳定场景成功率
    private func handleStreamingMirrorConnectFailure(for type: StreamingType, message: String) {
        guard case .waitingSession(let expectedType) = streamingLaunchState, expectedType == type else { return }
        if streamingSessionRetryCount < maxStreamingSessionRetryCount {
            streamingSessionRetryCount += 1
            streamingRemoteViewPresented = false
            requestStreamingSession(type: type, delay: 2.0)
            return
        }

        if streamingRemoteSystemIndex + 1 < streamingRemoteSystems.count {
            streamingRemoteSystemIndex += 1
            streamingSessionRetryCount = 0
            streamingRemoteViewPresented = false
            requestStreamingSession(type: type, delay: 2.0)
            return
        }

        streamingLaunchState = .idle
        showAlert(title: "连接失败", message: message)
    }

    /// 兼容 Int / String 两种 result 编码
    private func parseResultCode(from value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let stringValue = value as? String {
            return Int(stringValue)
        }
        return nil
    }

    /// 兼容两类会话格式：
    /// 1) result 为 JSON 字符串（协议新格式）
    /// 2) address/session 直接位于顶层（兼容老格式）
    private func parseSessionInfo(from data: [String: Any]) -> ScreenMirrorSessionInfo? {
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

    private func makeSessionInfo(from dict: [String: Any]) -> ScreenMirrorSessionInfo? {
        guard let rawAddress = dict["address"] as? String,
              let session = dict["session"] as? String,
              !rawAddress.isEmpty,
              !session.isEmpty else {
            return nil
        }
        // 只保留 PHSRC:// 和 PHSRC_HTTPS:// 协议段，
        // 移除 UsingMultiChannel://、UR://、ORTC:// 等无效段，避免向日葵 SDK 连接失败
        let address = cleanSunflowerAddress(rawAddress)
        let soundSession = dict["sound_session"] as? String
        return ScreenMirrorSessionInfo(address: address, session: session, soundSession: soundSession)
    }

    /// 清理向日葵连接地址，只保留有效的 PHSRC 协议段
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

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func updateMiniPlayer(with state: PlayState) {
        playState = state
        miniPlayerView.update(with: state, ipAddress: device.ipAddress)
    }
}

// MARK: - TCPSocketManagerDelegate

extension DeviceControlViewController: TCPSocketManagerDelegate {
    
    func tcpSocketManager(_ manager: TCPSocketManager, didChangeState state: TCPConnectionState) {
        switch state {
        case .connected:
            connectionStatusLabel.text = "● 已连接"
            connectionStatusLabel.textColor = .playing
            // 获取播放状态
            TCPSocketManager.shared.send(command: CommandBuilder.getPlayState())
            
        case .disconnected:
            connectionStatusLabel.text = "○ 未连接"
            connectionStatusLabel.textColor = .textSecondary
            
        case .connecting:
            connectionStatusLabel.text = "◐ 连接中..."
            connectionStatusLabel.textColor = .accent
            
        case .failed:
            connectionStatusLabel.text = "○ 连接失败"
            connectionStatusLabel.textColor = .systemRed
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
        switch command {
        case "play_state":
            let state = PlayState.from(json: data)
            updateMiniPlayer(with: state)

        case "app":
            handleStreamingAppResponse(data)

        case "get_session", "screen_mirror_session":
            handleStreamingSessionResponse(data)
            
        default:
            break
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        print("TCP Error: \(error.localizedDescription)")
    }
}

// MARK: - ScreenMirrorServiceDelegate

extension DeviceControlViewController: ScreenMirrorServiceDelegate {
    
    func screenMirrorService(_ service: ScreenMirrorService, didChangeState state: ScreenMirrorState) {
        guard case .waitingSession(let type) = streamingLaunchState else { return }
        switch state {
        case .connected:
            streamingMirrorPresenting = false
            streamingSessionRetryCount = 0
            streamingLaunchState = .idle

        case .failed(let error):
            if streamingMirrorPresenting {
                streamingMirrorPresenting = false
                handleStreamingMirrorConnectFailure(for: type, message: "向日葵连接失败：\(error)")
            }
        case .disconnected:
            if streamingMirrorPresenting {
                streamingMirrorPresenting = false
                handleStreamingMirrorConnectFailure(for: type, message: "向日葵连接断开")
            }
        default:
            break
        }
    }
}

// MARK: - MiniPlayerViewDelegate

extension DeviceControlViewController: MiniPlayerViewDelegate {
    
    func miniPlayerViewDidTapPlay(_ view: MiniPlayerView) {
        TCPSocketManager.shared.send(command: CommandBuilder.playPause())
    }
    
    func miniPlayerViewDidTapNext(_ view: MiniPlayerView) {
        TCPSocketManager.shared.send(command: CommandBuilder.next())
    }
    
    func miniPlayerViewDidTap(_ view: MiniPlayerView) {
        guard let state = playState else { return }
        let playerVC = PlayerViewController(playState: state, ipAddress: device.ipAddress)
        playerVC.modalPresentationStyle = .fullScreen
        present(playerVC, animated: true)
    }
}
