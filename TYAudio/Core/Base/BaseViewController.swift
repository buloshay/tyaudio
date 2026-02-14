//
//  BaseViewController.swift
//  TYAudio
//
//  Base View Controller for common functionality and logging
//

import UIKit

class BaseViewController: UIViewController {

    // MARK: - Loading UI
    
    private var loadingOverlayView: UIView?
    private var loadingSpinner: UIActivityIndicatorView?
    private var loadingMessageLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[Page] \(String(describing: type(of: self))) - viewDidLoad")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("[Page] \(String(describing: type(of: self))) - viewWillAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[Page] \(String(describing: type(of: self))) - viewDidAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("[Page] \(String(describing: type(of: self))) - viewWillDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("[Page] \(String(describing: type(of: self))) - viewDidDisappear")
    }
    
    deinit {
        print("[Page] \(String(describing: type(of: self))) - deinit")
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
