//
//  StreamingRemoteViewController.swift
//  TYAudio
//
//  流媒体远程桌面页面
//  横屏显示向日葵远程桌面，底部 64pt 导航栏（后退/菜单/关闭）
//

import UIKit

class StreamingRemoteViewController: BaseViewController {
    
    // MARK: - Properties
    
    /// 向日葵 SDK 返回的远程桌面 ViewController
    private let remoteDesktopVC: UIViewController
    
    /// 关闭回调（作为子控制器嵌入时，由父控制器设置）
    var onClose: (() -> Void)?
    
    // MARK: - UI Components
    
    /// 远程桌面容器
    private lazy var remoteDesktopContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    /// 底部导航栏
    private lazy var bottomBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        return view
    }()
    
    /// 底部导航栏按钮容器
    private lazy var buttonStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        return stack
    }()
    
    /// 后退按钮
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: "chevron.backward", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return button
    }()
    
    /// 菜单按钮
    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: "line.3.horizontal", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        return button
    }()
    
    /// 关闭按钮
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.tintColor = UIColor.systemRed
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    
    /// Loading 遮罩层
    private lazy var loadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.8)
        return view
    }()
    
    /// Loading 指示器
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    /// Loading 状态文字
    private lazy var loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "正在连接远程桌面..."
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Orientation
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    // MARK: - Status Bar
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Initialization
    
    /// 初始化流媒体远程桌面页面
    /// - Parameter remoteDesktopVC: 向日葵 SDK 返回的远程桌面 ViewController
    init(remoteDesktopVC: UIViewController) {
        self.remoteDesktopVC = remoteDesktopVC
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        embedRemoteDesktop()
        showLoading()
        
        // 监听向日葵桌面出现事件
        ScreenMirrorService.shared.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ScreenMirrorService.shared.resume()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ScreenMirrorService.shared.pause()
    }
    
    deinit {
        if ScreenMirrorService.shared.delegate === self {
            ScreenMirrorService.shared.delegate = nil
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 远程桌面容器
        view.addSubviewWithAutoLayout(remoteDesktopContainer)
        
        // 底部导航栏
        view.addSubviewWithAutoLayout(bottomBar)
        
        // 按钮
        buttonStackView.addArrangedSubview(backButton)
        buttonStackView.addArrangedSubview(menuButton)
        buttonStackView.addArrangedSubview(closeButton)
        bottomBar.addSubviewWithAutoLayout(buttonStackView)
        
        // 顶部分隔线
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        bottomBar.addSubviewWithAutoLayout(separator)
        
        NSLayoutConstraint.activate([
            // 底部栏
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 64),
            
            // 远程桌面容器（填满底栏上方区域）
            remoteDesktopContainer.topAnchor.constraint(equalTo: view.topAnchor),
            remoteDesktopContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteDesktopContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            remoteDesktopContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            
            // 按钮容器
            buttonStackView.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            buttonStackView.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            buttonStackView.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            buttonStackView.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor),
            
            // 分隔线
            separator.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        // Loading 遮罩
        view.addSubviewWithAutoLayout(loadingOverlay)
        loadingOverlay.addSubviewWithAutoLayout(loadingIndicator)
        loadingOverlay.addSubviewWithAutoLayout(loadingLabel)
        
        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor, constant: -20),
            
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor)
        ])
    }
    
    /// 将向日葵远程桌面 VC 以 child VC 方式内嵌到容器
    private func embedRemoteDesktop() {
        addChild(remoteDesktopVC)
        remoteDesktopContainer.addSubviewWithAutoLayout(remoteDesktopVC.view)
        remoteDesktopVC.view.fillSuperview()
        remoteDesktopVC.didMove(toParent: self)
        
    }
    
    // MARK: - Loading
    
    private func showLoading() {
        loadingOverlay.isHidden = false
        loadingIndicator.startAnimating()
    }
    
    private func hideLoading() {
        UIView.animate(withDuration: 0.3) {
            self.loadingOverlay.alpha = 0
        } completion: { _ in
            self.loadingOverlay.isHidden = true
            self.loadingIndicator.stopAnimating()
            self.loadingOverlay.alpha = 1  // 重置以便复用
        }
    }
    
    // MARK: - Actions
    
    /// 后退 — 调用蒲公英返回键
    @objc private func backTapped() {
        print("[User Action] StreamingRemote - backTapped")
        TCPSocketManager.shared.send(command: CommandBuilder.sendBackKey())
    }
    
    /// 菜单 — 调用蒲公英菜单键
    @objc private func menuTapped() {
        print("[User Action] StreamingRemote - menuTapped")
        TCPSocketManager.shared.send(command: CommandBuilder.sendMenuKey())
    }
    
    /// 关闭 — 提示用户确认后断开连接并关闭页面
    @objc private func closeTapped() {
        print("[User Action] StreamingRemote - closeTapped")
        let alert = UIAlertController(
            title: "结束远程桌面",
            message: "确定要结束远程桌面操控吗？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            self?.disconnectAndDismiss()
        })
        present(alert, animated: true)
    }
    
    private func disconnectAndDismiss() {
        if let onClose = onClose {
            // 作为子控制器时，通知父控制器处理关闭
            onClose()
        } else {
            // 独立 present 时，直接 disconnect + dismiss
            ScreenMirrorService.shared.disconnect()
            dismiss(animated: true)
        }
    }
}

// MARK: - ScreenMirrorServiceDelegate

extension StreamingRemoteViewController: ScreenMirrorServiceDelegate {
    
    func screenMirrorService(_ service: ScreenMirrorService, didChangeState state: ScreenMirrorState) {
        switch state {
        case .connected:
            print("[StreamingRemote] mirror connected")
        case .failed(let error):
            print("[StreamingRemote] mirror failed: \(error)")
            hideLoading()
        case .disconnected:
            print("[StreamingRemote] mirror disconnected")
            hideLoading()
            // 自动关闭
            disconnectAndDismiss()
        default:
            break
        }
    }
    
    func screenMirrorServiceDidDesktopAppear(_ service: ScreenMirrorService) {
        print("[StreamingRemote] desktop appeared, hiding loading")
        hideLoading()
    }
}
