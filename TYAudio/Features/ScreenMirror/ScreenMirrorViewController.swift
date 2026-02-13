//
//  ScreenMirrorViewController.swift
//  TYAudio
//
//  屏幕镜像功能页面
//

import UIKit

class ScreenMirrorViewController: BaseViewController {
    
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
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "屏幕互动"
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "准备连接..."
        label.font = .systemFont(ofSize: 14)
        label.textColor = .textSecondary
        label.textAlignment = .center
        return label
    }()
    
    private lazy var connectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始连接", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .accent
        button.setCornerRadius(12)
        button.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .accent
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var infoStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        return stack
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "rectangle.on.rectangle.angled")
        imageView.tintColor = .accent
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "通过屏幕互动功能，您可以直接控制音响设备的屏幕"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    // MARK: - Control Bar Components
    
    private lazy var controlBar: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.isHidden = true
        return view
    }()
    
    private lazy var controlStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        return stack
    }()
    
    private lazy var deviceBackButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.backward.circle.fill"), for: .normal)
        button.setTitle(" 后退", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.tintColor = .textPrimary
        button.addTarget(self, action: #selector(deviceBackTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var deviceHomeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "house.circle.fill"), for: .normal)
        button.setTitle(" 主页", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.tintColor = .textPrimary
        button.addTarget(self, action: #selector(deviceHomeTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var disconnectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.setTitle(" 关闭", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.tintColor = .systemRed
        button.addTarget(self, action: #selector(disconnectTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    
    private let device: Device
    
    // MARK: - Initialization
    
    init(device: Device) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        ScreenMirrorService.shared.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 页面消失时暂停
        ScreenMirrorService.shared.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 页面显示时恢复
        ScreenMirrorService.shared.resume()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        
        // Header
        view.addSubviewWithAutoLayout(headerView)
        headerView.addSubviewWithAutoLayout(backButton)
        headerView.addSubviewWithAutoLayout(titleLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),
            
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            backButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor)
        ])
        
        // Content
        infoStackView.addArrangedSubview(iconImageView)
        infoStackView.addArrangedSubview(descriptionLabel)
        infoStackView.addArrangedSubview(statusLabel)
        
        view.addSubviewWithAutoLayout(infoStackView)
        view.addSubviewWithAutoLayout(loadingIndicator)
        view.addSubviewWithAutoLayout(connectButton)
        
        iconImageView.setSize(width: 80, height: 80)
        
        NSLayoutConstraint.activate([
            infoStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            infoStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            infoStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: infoStackView.bottomAnchor, constant: 30),
            
            connectButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            connectButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            connectButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            connectButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Control Bar
        controlStackView.addArrangedSubview(deviceBackButton)
        controlStackView.addArrangedSubview(deviceHomeButton)
        controlStackView.addArrangedSubview(disconnectButton)
        
        view.addSubviewWithAutoLayout(controlBar)
        controlBar.addSubviewWithAutoLayout(controlStackView)
        
        NSLayoutConstraint.activate([
            controlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlBar.heightAnchor.constraint(equalToConstant: 80),
            
            controlStackView.topAnchor.constraint(equalTo: controlBar.topAnchor, constant: 12),
            controlStackView.leadingAnchor.constraint(equalTo: controlBar.leadingAnchor, constant: 20),
            controlStackView.trailingAnchor.constraint(equalTo: controlBar.trailingAnchor, constant: -20),
            controlStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        ScreenMirrorService.shared.disconnect()
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func connectTapped() {
        startConnection()
    }
    
    @objc private func deviceBackTapped() {
        TCPSocketManager.shared.send(command: CommandBuilder.sendBackKey())
    }
    
    @objc private func deviceHomeTapped() {
        TCPSocketManager.shared.send(command: CommandBuilder.sendHomeKey())
    }
    
    @objc private func disconnectTapped() {
        ScreenMirrorService.shared.disconnect()
        controlBar.isHidden = true
        connectButton.isHidden = false
        statusLabel.text = "已断开连接"
        statusLabel.textColor = .textSecondary
    }
    
    private func startConnection() {
        loadingIndicator.startAnimating()
        connectButton.isEnabled = false
        statusLabel.text = "正在连接..."
        
        // 向设备请求远程控制会话信息
        TCPSocketManager.shared.delegate = self
        TCPSocketManager.shared.send(command: CommandBuilder.getScreenMirrorSession())
    }
    
    private func showRemoteDesktop(_ viewController: UIViewController) {
        loadingIndicator.stopAnimating()
        connectButton.isEnabled = true
        
        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }
    
    private func showError(_ message: String) {
        loadingIndicator.stopAnimating()
        connectButton.isEnabled = true
        statusLabel.text = message
        statusLabel.textColor = .systemRed
    }
}

// MARK: - ScreenMirrorServiceDelegate

extension ScreenMirrorViewController: ScreenMirrorServiceDelegate {
    
    func screenMirrorService(_ service: ScreenMirrorService, didChangeState state: ScreenMirrorState) {
        switch state {
        case .idle:
            statusLabel.text = "准备连接..."
            statusLabel.textColor = .textSecondary
        case .connecting:
            statusLabel.text = "正在连接..."
            statusLabel.textColor = .textSecondary
        case .connected:
            statusLabel.text = "已连接"
            statusLabel.textColor = .accent
            controlBar.isHidden = false
            connectButton.isHidden = true
        case .failed(let error):
            showError("连接失败: \(error)")
        case .disconnected:
            statusLabel.text = "已断开连接"
            statusLabel.textColor = .textSecondary
            connectButton.isEnabled = true
        }
    }
}

// MARK: - TCPSocketManagerDelegate

extension ScreenMirrorViewController: TCPSocketManagerDelegate {
    
    func tcpSocketManager(_ manager: TCPSocketManager, didChangeState state: TCPConnectionState) {}
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
        guard command == "get_session" || command == "screen_mirror_session" else { return }
        guard let sessionInfo = parseSessionInfo(from: data) else {
            showError("无法获取会话信息")
            return
        }
        
        // 连接远程桌面
        ScreenMirrorService.shared.connect(
            address: sessionInfo.address,
            session: sessionInfo.session,
            soundSession: sessionInfo.soundSession
        ) { [weak self] viewController in
            if let vc = viewController {
                self?.showRemoteDesktop(vc)
            } else {
                self?.showError("无法创建远程桌面")
            }
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        showError("通信错误: \(error.localizedDescription)")
    }

    /// 兼容两类会话格式：
    /// 1) result 为 JSON 字符串（新协议）
    /// 2) address/session 在顶层（旧协议）
    private func parseSessionInfo(from data: [String: Any]) -> (address: String, session: String, soundSession: String?)? {
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
    
    private func makeSessionInfo(from dict: [String: Any]) -> (address: String, session: String, soundSession: String?)? {
        guard let rawAddress = dict["address"] as? String,
              let session = dict["session"] as? String,
              !rawAddress.isEmpty,
              !session.isEmpty else {
            return nil
        }
        let address = cleanSunflowerAddress(rawAddress)
        return (address, session, dict["sound_session"] as? String)
    }

    /// 清理向日葵连接地址，只保留有效的 PHSRC 协议段
    private func cleanSunflowerAddress(_ raw: String) -> String {
        let validPrefixes = ["PHSRC://", "PHSRC_HTTPS://"]
        let segments = raw.split(separator: ";", omittingEmptySubsequences: true)
        let filtered = segments.filter { segment in
            validPrefixes.contains(where: { segment.hasPrefix($0) })
        }
        return filtered.map(String.init).joined(separator: ";") + ";"
    }
}
