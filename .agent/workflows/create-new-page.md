---
description: 如何创建新的功能页面
---

# 创建新的功能页面

当需要添加新的 ViewController 时，按以下步骤操作：

## 1. 创建 ViewController 文件

在 `TYAudio/Features/` 下创建新文件夹和 ViewController：

```swift
//
//  NewFeatureViewController.swift
//  TYAudio
//
//  功能描述
//

import UIKit

class NewFeatureViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground  // 使用主题色
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
        label.text = "页面标题"
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        TCPSocketManager.shared.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        
        // 使用 addSubviewWithAutoLayout 而非手动设置
        view.addSubviewWithAutoLayout(headerView)
        headerView.addSubviewWithAutoLayout(backButton)
        headerView.addSubviewWithAutoLayout(titleLabel)
        
        // 统一的 Header 布局
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
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - TCPSocketManagerDelegate

extension NewFeatureViewController: TCPSocketManagerDelegate {
    
    func tcpSocketManager(_ manager: TCPSocketManager, didChangeState state: TCPConnectionState) {}
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
        // 处理响应数据
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {}
}
```

## 2. 主题色使用规范

| 用途 | 颜色 |
|------|------|
| 页面背景 | `.background` |
| 卡片背景 | `.cardBackground` |
| 主色调 | `.accent` |
| 主文字 | `.textPrimary` |
| 次要文字 | `.textSecondary` |

## 3. 使用已有扩展

```swift
// 添加子视图
view.addSubviewWithAutoLayout(subview)

// 设置圆角
view.setCornerRadius(10)

// 添加阴影
view.addShadow(opacity: 0.2, radius: 4)

// 设置尺寸
button.setSize(width: 44, height: 44)
```

## 注意事项

- ✅ 必须使用主题色，禁止硬编码颜色值
- ✅ 必须使用 `addSubviewWithAutoLayout` 添加子视图
- ✅ 必须实现 `TCPSocketManagerDelegate` 处理通信
- ❌ 禁止在 setupUI 中进行网络请求
