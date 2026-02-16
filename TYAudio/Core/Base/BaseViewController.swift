//
//  BaseViewController.swift
//  TYAudio
//
//  Base View Controller for common functionality and logging
//

import UIKit

class BaseViewController: UIViewController {

    // MARK: - Custom Navigation Bar
    
    lazy var customNavigationBar: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        return view
    }()
    
    lazy var navTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    lazy var navLeftButton: UIButton = {
        let button = UIButton(type: .system)
        // Default back button
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        button.tintColor = .textPrimary
        button.addTarget(self, action: #selector(navBackTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var navRightButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .textPrimary
        button.isHidden = true
        return button
    }()
    
    // MARK: - Loading UI
    
    private var loadingOverlayView: UIView?
    private var loadingSpinner: UIActivityIndicatorView?
    private var loadingMessageLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCustomNavigationBar()
//        print("[Page] \(String(describing: type(of: self))) - viewDidLoad")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure nav bar is on top
        view.bringSubviewToFront(customNavigationBar)
//        print("[Page] \(String(describing: type(of: self))) - viewWillAppear")
    }
    
    // MARK: - Navigation Bar Setup
    
    /// 初始化自定义导航栏
    private func setupCustomNavigationBar() {
        view.addSubview(customNavigationBar)
        customNavigationBar.translatesAutoresizingMaskIntoConstraints = false
        
        customNavigationBar.addSubview(navTitleLabel)
        navTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        customNavigationBar.addSubview(navLeftButton)
        navLeftButton.translatesAutoresizingMaskIntoConstraints = false
        
        customNavigationBar.addSubview(navRightButton)
        navRightButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 增加 10pt 高度 (100 -> 110)
        NSLayoutConstraint.activate([
            customNavigationBar.topAnchor.constraint(equalTo: view.topAnchor),
            customNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customNavigationBar.heightAnchor.constraint(equalToConstant: 110),
            
            // 内容位置保持靠下，高度增加自然实现了整体下移 10pt 的效果
            navLeftButton.leadingAnchor.constraint(equalTo: customNavigationBar.leadingAnchor, constant: 12),
            navLeftButton.bottomAnchor.constraint(equalTo: customNavigationBar.bottomAnchor, constant: -12),
            navLeftButton.widthAnchor.constraint(equalToConstant: 44),
            navLeftButton.heightAnchor.constraint(equalToConstant: 44),
            
            navTitleLabel.centerXAnchor.constraint(equalTo: customNavigationBar.centerXAnchor),
            navTitleLabel.centerYAnchor.constraint(equalTo: navLeftButton.centerYAnchor),
            navTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: navLeftButton.trailingAnchor, constant: 8),
            navTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: navRightButton.leadingAnchor, constant: -8),
            
            navRightButton.trailingAnchor.constraint(equalTo: customNavigationBar.trailingAnchor, constant: -12),
            navRightButton.centerYAnchor.constraint(equalTo: navLeftButton.centerYAnchor),
            navRightButton.widthAnchor.constraint(equalToConstant: 44),
            navRightButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    /// 配置导航栏
    /// - Parameter title: 标题
    /// - Parameter hideLeftButton: 是否隐藏左侧按钮（默认 false）
    func setupNavBar(title: String, hideLeftButton: Bool = false) {
        navTitleLabel.text = title
        navLeftButton.isHidden = hideLeftButton
        customNavigationBar.isHidden = false
    }
    
    /// 设置右侧按钮
    /// - Parameters:
    ///   - image: 图标
    ///   - action: 点击事件
    func setRightButton(image: UIImage?, action: Selector?) {
        navRightButton.setImage(image, for: .normal)
        navRightButton.isHidden = false
        if let action = action {
            navRightButton.removeTarget(nil, action: nil, for: .allEvents)
            navRightButton.addTarget(self, action: action, for: .touchUpInside)
        }
    }
    
    /// 隐藏所有自定义导航栏（全屏页面用）
    func hideCustomNavBar() {
        customNavigationBar.isHidden = true
    }
    
    @objc func navBackTapped() {
        navigationController?.popViewController(animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        print("[Page] \(String(describing: type(of: self))) - viewDidAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
//        print("[Page] \(String(describing: type(of: self))) - viewWillDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
//        print("[Page] \(String(describing: type(of: self))) - viewDidDisappear")
    }
    
    deinit {
//        print("[Page] \(String(describing: type(of: self))) - deinit")
    }
    
    // MARK: - Public Loading Methods
    
    /// 显示全屏 Loading 遮罩
    /// - Parameter message: 可选提示文字，默认为 "正在加载..."
    func showLoading(message: String = "正在加载...") {
        // 如果已经存在，直接更新文字
        if let existingLabel = loadingMessageLabel, loadingOverlayView != nil {
            existingLabel.text = message
            view.bringSubviewToFront(loadingOverlayView!)
            return
        }
        
        // 1. 创建遮罩背景
        let overlay = UIView()
        overlay.backgroundColor = UIColor(white: 0, alpha: 0.6)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.tag = 999 // 防止重复查找
        
        // 2. 创建 Spinner
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        
        // 3. 创建文字标签
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // 4. 添加视图
        overlay.addSubview(spinner)
        overlay.addSubview(label)
        view.addSubview(overlay)
        
        // 确保 Loading 在最上层
        view.bringSubviewToFront(overlay)
        
        // 5. 布局
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),
            
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -20)
        ])
        
        // 保存引用
        self.loadingOverlayView = overlay
        self.loadingSpinner = spinner
        self.loadingMessageLabel = label
    }
    
    /// 隐藏 Loading 遮罩
    /// - Parameter animated: 是否使用淡出动画
    func hideLoading(animated: Bool = true) {
        guard let overlay = loadingOverlayView else { return }
        
        let cleanup = {
            overlay.removeFromSuperview()
            self.loadingOverlayView = nil
            self.loadingSpinner = nil
            self.loadingMessageLabel = nil
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                overlay.alpha = 0
            }) { _ in
                cleanup()
            }
        } else {
            cleanup()
        }
    }
}
