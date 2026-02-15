//
//  DeviceControlViewController.swift
//  TYAudio
//
//  设备控制主页面
//

import UIKit

class DeviceControlViewController: BaseViewController {
    
    // MARK: - UI Components
    

    
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
            case .hardDrive: return "/storage/emulated/0"
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
        // 每次页面出现时重新设置 delegate，防止被其他页面覆盖后丢失
        TCPSocketManager.shared.addDelegate(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        
        // Header
        setupNavBar(title: "")
        
        // Custom Nav Content
        customNavigationBar.addSubview(deviceIconView)
        deviceIconView.translatesAutoresizingMaskIntoConstraints = false
        customNavigationBar.addSubview(deviceNameLabel)
        deviceNameLabel.translatesAutoresizingMaskIntoConstraints = false
        customNavigationBar.addSubview(connectionStatusLabel)
        connectionStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Adjust height for DeviceControl (Original 140 + 10 = 150)
        if let heightConstraint = customNavigationBar.constraints.first(where: { $0.firstAttribute == .height }) {
            heightConstraint.constant = 150
        }
        
        NSLayoutConstraint.activate([
            // Align with back button in BaseViewController
            deviceIconView.leadingAnchor.constraint(equalTo: navLeftButton.trailingAnchor, constant: 8),
            deviceIconView.centerYAnchor.constraint(equalTo: navLeftButton.centerYAnchor),
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
            scrollView.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
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
        TCPSocketManager.shared.addDelegate(self)
        TCPSocketManager.shared.connect(host: device.ipAddress, port: device.port)
    }
    
    // MARK: - Actions
    
    override func navBackTapped() {
        print("[User Action] DeviceControlViewController - backTapped")
        TCPSocketManager.shared.disconnect()
        navigationController?.popViewController(animated: true)
    }
    
    private func handleFeatureAction(_ action: FeatureAction) {
        print("[User Action] DeviceControlViewController - handleFeatureAction: \(action)")
        switch action {
        case .storage(let type):
            let vc = FileBrowserViewController(path: type.path, title: type == .hardDrive ? "硬盘" : type == .usb ? "U盘" : "TF卡", ipAddress: device.ipAddress, shouldAutoEnterSingleRoot: true)
            navigationController?.pushViewController(vc, animated: true)
            
        case .category(let type):
            let vc = CategoryViewController(categoryType: type, ipAddress: device.ipAddress)
            navigationController?.pushViewController(vc, animated: true)
            
        case .favorites:
            let vc = FileBrowserViewController(path: "/", title: "收藏", isFavorites: true)
            navigationController?.pushViewController(vc, animated: true)
            
        case .streaming(let type):
            let vc = StreamingLaunchViewController(mode: .streaming(type))
            navigationController?.pushViewController(vc, animated: true)
            
        case .nas:
            let vc = StreamingLaunchViewController(mode: .nas)
            navigationController?.pushViewController(vc, animated: true)
            
        case .screenMirror:
            let vc = StreamingLaunchViewController(mode: .screenMirror)
            navigationController?.pushViewController(vc, animated: true)
            
        case .settings:
            let vc = StreamingLaunchViewController(mode: .settings)
            navigationController?.pushViewController(vc, animated: true)
            
        case .apps:
            let vc = AppListViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
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
            
        case "app", "get_session", "screen_mirror_session":
            // 转发给当前 nav 栈上的 StreamingLaunchViewController
            if let launchVC = navigationController?.viewControllers.last as? StreamingLaunchViewController {
                launchVC.handleTCPData(data, command: command)
            }
            
        default:
            break
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        print("TCP Error: \(error.localizedDescription)")
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
