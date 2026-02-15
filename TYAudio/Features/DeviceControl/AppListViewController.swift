//
//  AppListViewController.swift
//  TYAudio
//
//  应用列表页面
//

import UIKit

class AppListViewController: BaseViewController {
    
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
        label.text = "应用"
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        let itemWidth = (UIScreen.main.bounds.width - 80) / 4
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth + 24)
        
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.delegate = self
        collection.dataSource = self
        collection.register(AppCell.self, forCellWithReuseIdentifier: AppCell.reuseIdentifier)
        return collection
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .accent
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Properties
    
    private var apps: [AppItem] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadApps()
        TCPSocketManager.shared.delegate = self
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
        
        // Collection View
        view.addSubviewWithAutoLayout(collectionView)
        view.addSubviewWithAutoLayout(loadingIndicator)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func loadApps() {
        loadingIndicator.startAnimating()
        TCPSocketManager.shared.send(command: CommandBuilder.appList())
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    /// 点击应用 → 进入 StreamingLaunchViewController 启动APP并开启屏幕镜像
    private func launchApp(_ app: AppItem) {
        let vc = StreamingLaunchViewController(mode: .app(app))
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension AppListViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AppCell.reuseIdentifier, for: indexPath) as? AppCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: apps[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension AppListViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        launchApp(apps[indexPath.item])
    }
}

// MARK: - TCPSocketManagerDelegate

extension AppListViewController: TCPSocketManagerDelegate {
    
    func tcpSocketManager(_ manager: TCPSocketManager, didChangeState state: TCPConnectionState) {}
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
        switch command {
        case "app":
            // 如果当前 nav 栈顶是 StreamingLaunchViewController，转发给它处理
            if let launchVC = navigationController?.viewControllers.last as? StreamingLaunchViewController {
                launchVC.handleTCPData(data, command: command)
                return
            }
            
            // 否则是应用列表响应（action == "list"）
            if (data["action"] as? String) == "list" {
                loadingIndicator.stopAnimating()
                if let list = data["list"] as? [[String: Any]] {
                    apps = AppItem.fromArray(jsonArray: list)
                    collectionView.reloadData()
                }
            }
            
        case "get_session", "screen_mirror_session":
            // 转发给 StreamingLaunchViewController
            if let launchVC = navigationController?.viewControllers.last as? StreamingLaunchViewController {
                launchVC.handleTCPData(data, command: command)
            }
            
        default:
            break
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        loadingIndicator.stopAnimating()
    }
}

// MARK: - App Cell

class AppCell: UICollectionViewCell {
    
    static let reuseIdentifier = "AppCell"
    
    /// 已知应用包名关键词 → Assets 图标名称映射
    private static let iconMapping: [(keyword: String, assetName: String)] = [
        ("kugou", "app_kugou"),
        ("apple.android.music", "app_apple_music"),
        ("qqmusic", "app_qq_music"),
        ("filemanager", "app_file_manager"),
        ("ximalaya", "app_ximalaya"),
        ("spotify", "app_spotify"),
        ("netease.cloudmusic", "app_netease_music"),
        ("dangbei", "app_dangbei"),
        ("cd", "app_cd")
    ]
    
    /// 根据包名查找对应的 Asset 图标名称
    private static func appIconName(for packageName: String) -> String? {
        let lower = packageName.lowercased()
        for mapping in iconMapping {
            if lower.contains(mapping.keyword) {
                return mapping.assetName
            }
        }
        return nil
    }
    
    private lazy var iconView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.setCornerRadius(16)
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "app.fill")
        imageView.tintColor = .accent
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubviewWithAutoLayout(iconView)
        iconView.addSubviewWithAutoLayout(iconImageView)
        contentView.addSubviewWithAutoLayout(nameLabel)
        
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),
            
            iconImageView.topAnchor.constraint(equalTo: iconView.topAnchor),
            iconImageView.leadingAnchor.constraint(equalTo: iconView.leadingAnchor),
            iconImageView.trailingAnchor.constraint(equalTo: iconView.trailingAnchor),
            iconImageView.bottomAnchor.constraint(equalTo: iconView.bottomAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    func configure(with app: AppItem) {
        nameLabel.text = app.title
        
        // 尝试匹配已知应用图标
        if let assetName = AppCell.appIconName(for: app.packageName),
           let image = UIImage(named: assetName) {
            iconImageView.image = image
            iconImageView.contentMode = .scaleAspectFill
            iconImageView.tintColor = nil
            iconView.backgroundColor = .clear
        } else {
            // 未匹配到：使用默认 SF Symbol 图标
            iconImageView.image = UIImage(systemName: "app.fill")
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.tintColor = .accent
            iconView.backgroundColor = .cardBackground
        }
    }
}
