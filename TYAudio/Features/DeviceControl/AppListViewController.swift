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
    
    private func launchApp(_ app: AppItem) {
        TCPSocketManager.shared.send(command: CommandBuilder.launchApp(package: app.packageName))
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
        if command == "app" {
            loadingIndicator.stopAnimating()
            
            if let list = data["list"] as? [[String: Any]] {
                apps = AppItem.fromArray(jsonArray: list)
                collectionView.reloadData()
            }
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        loadingIndicator.stopAnimating()
    }
}

// MARK: - App Cell

class AppCell: UICollectionViewCell {
    
    static let reuseIdentifier = "AppCell"
    
    private lazy var iconView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.setCornerRadius(16)
        return view
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "app.fill")
        imageView.tintColor = .accent
        imageView.contentMode = .scaleAspectFit
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
            
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    func configure(with app: AppItem) {
        nameLabel.text = app.title
    }
}
