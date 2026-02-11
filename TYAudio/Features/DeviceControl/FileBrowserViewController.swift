//
//  FileBrowserViewController.swift
//  TYAudio
//
//  文件浏览器
//

import UIKit

class FileBrowserViewController: BaseViewController {
    
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
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.register(FileCell.self, forCellReuseIdentifier: FileCell.reuseIdentifier)
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 100, right: 0)
        return table
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .accent
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无文件"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    // MARK: - Properties
    
    private var currentPath: String
    private var pageTitle: String
    private var isFavorites: Bool
    private var files: [FileItem] = []
    private var navigationStack: [String] = []
    private var shouldAutoEnterSingleRoot: Bool = false
    /// 标记是否正在等待 change_path 响应
    private var isWaitingForChangePath: Bool = false
    
    // MARK: - Initialization
    
    init(path: String, title: String, isFavorites: Bool = false, shouldAutoEnterSingleRoot: Bool = false) {
        self.currentPath = path
        self.pageTitle = title
        self.isFavorites = isFavorites
        self.shouldAutoEnterSingleRoot = shouldAutoEnterSingleRoot
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        TCPSocketManager.shared.delegate = self
        loadFiles()
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
        
        titleLabel.text = pageTitle
        
        // Table View
        view.addSubviewWithAutoLayout(tableView)
        view.addSubviewWithAutoLayout(loadingIndicator)
        view.addSubviewWithAutoLayout(emptyLabel)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    /// 加载文件列表（有序流程：change_path -> 等待响应 -> playlist -> 等待响应）
    private func loadFiles() {
        loadingIndicator.startAnimating()
        files = []
        tableView.reloadData()
        emptyLabel.isHidden = true
        
        // 第一步：发送切换目录指令，等待响应后再发送 playlist
        isWaitingForChangePath = true
        TCPSocketManager.shared.send(command: CommandBuilder.changePath(dir: currentPath))
    }
    
    /// change_path 响应成功后，发送获取文件列表指令
    private func requestPlaylist() {
        TCPSocketManager.shared.send(command: CommandBuilder.playlist(nameOnly: false, current: false))
    }
    
    private func showError() {
        loadingIndicator.stopAnimating()
        emptyLabel.text = "加载失败"
        emptyLabel.isHidden = false
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        if navigationStack.isEmpty {
            navigationController?.popViewController(animated: true)
        } else {
            // 返回上级目录
            currentPath = navigationStack.removeLast()
            loadFiles()
        }
    }
    
    private func enterDirectory(_ item: FileItem) {
        navigationStack.append(currentPath)
        currentPath = item.path
        pageTitle = item.name
        titleLabel.text = item.name
        loadFiles()
    }
    
    private func playSong(at index: Int) {
        TCPSocketManager.shared.send(command: CommandBuilder.playAt(index: index))
    }
}

// MARK: - UITableViewDataSource

extension FileBrowserViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: FileCell.reuseIdentifier, for: indexPath) as? FileCell else {
            return UITableViewCell()
        }
        cell.configure(with: files[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FileBrowserViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = files[indexPath.row]
        
        if item.isDirectory {
            enterDirectory(item)
        } else {
            playSong(at: indexPath.row)
        }
    }
}

// MARK: - TCPSocketManagerDelegate

extension FileBrowserViewController: TCPSocketManagerDelegate {
    
    func tcpSocketManager(_ manager: TCPSocketManager, didChangeState state: TCPConnectionState) {}
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
        if command == "change_path" {
            // 第二步：收到 change_path 响应
            let result = data["result"] as? Int ?? -1
            if result == -1 {
                // 失败
                isWaitingForChangePath = false
                showError()
                return
            }
            
            // 成功，发送获取文件列表指令
            isWaitingForChangePath = false
            requestPlaylist()
            
        } else if command == "playlist" {
            // 第四步：收到文件列表数据
            loadingIndicator.stopAnimating()
            
            if let list = data["list"] as? [[String: Any]] {
                files = FileItem.fromArray(jsonArray: list)
                
                // 自动进入根目录（如果只有一个文件夹）
                if shouldAutoEnterSingleRoot {
                    shouldAutoEnterSingleRoot = false
                    if files.count == 1, let firstItem = files.first, firstItem.isDirectory {
                        enterDirectory(firstItem)
                        return
                    }
                }
                
                tableView.reloadData()
                emptyLabel.isHidden = !files.isEmpty
                if files.isEmpty {
                    emptyLabel.text = "暂无文件"
                }
            }
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        showError()
    }
}

// MARK: - File Cell

class FileCell: UITableViewCell {
    
    static let reuseIdentifier = "FileCell"
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.setCornerRadius(10)
        return view
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .accent
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .textPrimary
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = .textSecondary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubviewWithAutoLayout(containerView)
        containerView.addSubviewWithAutoLayout(iconImageView)
        containerView.addSubviewWithAutoLayout(nameLabel)
        containerView.addSubviewWithAutoLayout(arrowImageView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 28),
            iconImageView.heightAnchor.constraint(equalToConstant: 28),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            
            arrowImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            arrowImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with item: FileItem) {
        nameLabel.text = item.name
        
        if item.isDirectory {
            iconImageView.image = UIImage(systemName: "folder.fill")
            arrowImageView.isHidden = false
        } else {
            iconImageView.image = UIImage(systemName: "music.note")
            arrowImageView.isHidden = true
        }
    }
}
