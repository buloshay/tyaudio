//
//  FileBrowserViewController.swift
//  TYAudio
//
//  文件浏览器
//

import UIKit

class FileBrowserViewController: BaseViewController {
    
    // MARK: - UI Components
    
    /// T025: 路径面包屑
    private lazy var breadcrumbScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .cardBackground
        return scrollView
    }()
    
    private lazy var breadcrumbStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        return stack
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.register(FileCell.self, forCellReuseIdentifier: FileCell.reuseIdentifier)
        table.register(CategoryItemCell.self, forCellReuseIdentifier: CategoryItemCell.reuseIdentifier)
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
    
    /// T029: 底部常驻 MiniPlayer
    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.delegate = self
        return view
    }()
    
    // MARK: - Properties
    
    private var currentPath: String
    private var pageTitle: String
    private let fixedNavTitle: String
    private let shouldKeepTitleFixed: Bool
    private let shouldPopOnBack: Bool
    private var isFavorites: Bool
    private var ipAddress: String?
    private var files: [FileItem] = []
    private var navigationStack: [String] = []
    private var shouldAutoEnterSingleRoot: Bool = false
    /// 标记是否正在等待 change_path 响应
    private var isWaitingForChangePath: Bool = false
    
    /// 播放状态通知观察者
    private var playStateObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    init(
        path: String,
        title: String,
        isFavorites: Bool = false,
        ipAddress: String? = nil,
        shouldAutoEnterSingleRoot: Bool = false,
        shouldKeepTitleFixed: Bool = false,
        shouldPopOnBack: Bool = false
    ) {
        self.currentPath = path
        self.pageTitle = title
        self.fixedNavTitle = title
        self.shouldKeepTitleFixed = shouldKeepTitleFixed
        self.shouldPopOnBack = shouldPopOnBack
        self.isFavorites = isFavorites
        self.ipAddress = ipAddress
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
        setupNavBar(title: fixedNavTitle)
        TCPSocketManager.shared.addDelegate(self)
        
        // 监听全局播放状态变化（其他页面触发的播放）
        playStateObserver = NotificationCenter.default.addObserver(
            forName: PlayStateManager.didUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePlayingState()
            // T029: 更新 MiniPlayer
            if let state = PlayStateManager.shared.currentState,
               let ip = self?.ipAddress {
                self?.miniPlayerView.update(with: state, ipAddress: ip)
            }
        }
        
        loadFiles()
    }
    
    deinit {
        if let observer = playStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        
        // T025: 面包屑导航
        view.addSubviewWithAutoLayout(breadcrumbScrollView)
        breadcrumbScrollView.addSubviewWithAutoLayout(breadcrumbStackView)
        
        // Table View
        view.addSubviewWithAutoLayout(tableView)
        view.addSubviewWithAutoLayout(loadingIndicator)
        view.addSubviewWithAutoLayout(emptyLabel)
        
        // T029: MiniPlayer
        view.addSubviewWithAutoLayout(miniPlayerView)
        
        NSLayoutConstraint.activate([
            // T029: MiniPlayer 固定在底部
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            miniPlayerView.heightAnchor.constraint(equalToConstant: 70),
            
            // 面包屑
            breadcrumbScrollView.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
            breadcrumbScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            breadcrumbScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            breadcrumbScrollView.heightAnchor.constraint(equalToConstant: 36),
            
            breadcrumbStackView.topAnchor.constraint(equalTo: breadcrumbScrollView.topAnchor),
            breadcrumbStackView.leadingAnchor.constraint(equalTo: breadcrumbScrollView.leadingAnchor, constant: 16),
            breadcrumbStackView.trailingAnchor.constraint(equalTo: breadcrumbScrollView.trailingAnchor, constant: -16),
            breadcrumbStackView.bottomAnchor.constraint(equalTo: breadcrumbScrollView.bottomAnchor),
            breadcrumbStackView.heightAnchor.constraint(equalTo: breadcrumbScrollView.heightAnchor),
            
            tableView.topAnchor.constraint(equalTo: breadcrumbScrollView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: miniPlayerView.topAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        updateBreadcrumb()
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
        // (4) 获取文件列表: nameOnly=false, current=false
        TCPSocketManager.shared.send(command: CommandBuilder.playlist(nameOnly: false, current: false))
    }
    
    private func showError() {
        loadingIndicator.stopAnimating()
        emptyLabel.text = "加载失败"
        emptyLabel.isHidden = false
    }
    
    // MARK: - Actions
    
    override func navBackTapped() {
        // 需求：硬盘/U盘/TF 页面左上返回直接退出页面，不做目录回退
        if shouldPopOnBack {
            navigationController?.popViewController(animated: true)
            return
        }
        
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
        if !shouldKeepTitleFixed {
            pageTitle = item.name
            navTitleLabel.text = Self.displayName(for: item.path, fallback: item.name)
        } else {
            navTitleLabel.text = fixedNavTitle
        }
        updateBreadcrumb()
        loadFiles()
    }
    
    private func playSong(at index: Int) {
        TCPSocketManager.shared.send(command: CommandBuilder.playAt(index: index))
        
        // 乐观更新到全局单例
        if index < files.count {
            let fileItem = files[index]
            PlayStateManager.shared.updateOptimistically(
                index: index,
                title: fileItem.name,
                filePath: fileItem.path
            )
        }
    }
    
    /// 逐 cell 更新播放状态，避免 reloadData 导致的闪烁
    private func updatePlayingState() {
        for cell in tableView.visibleCells {
            if let indexPath = tableView.indexPath(for: cell),
               indexPath.row < files.count {
                let fileItem = files[indexPath.row]
                let isPlaying: Bool
                if fileItem.isSong {
                    isPlaying = PlayStateManager.shared.isSongPlaying(title: fileItem.name, filePath: fileItem.path)
                } else {
                    isPlaying = PlayStateManager.shared.isPathPlaying(fileItem.path)
                }
                
                if let categoryCell = cell as? CategoryItemCell {
                    categoryCell.updatePlayingState(isPlaying)
                } else if let fileCell = cell as? FileCell {
                    fileCell.updatePlayingState(isPlaying)
                }
            }
        }
    }
    
    // MARK: - T025: Breadcrumb
    
    /// 根路径友好名称映射
    private static let rootPathNames: [String: String] = [
        "/mnt/sda": "硬盘",
        "/mnt/usb": "U盘",
        "/mnt/tf": "TF卡"
    ]
    
    /// 获取路径的显示名称
    static func displayName(for path: String, fallback: String? = nil) -> String {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        for (rootPath, name) in rootPathNames {
            let rootTrimmed = rootPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if trimmed == rootTrimmed {
                return name
            }
        }
        return fallback ?? (path as NSString).lastPathComponent
    }
    
    /// 更新面包屑导航
    private func updateBreadcrumb() {
        breadcrumbStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 构建完整路径链：navigationStack + currentPath
        var pathChain = navigationStack
        pathChain.append(currentPath)
        
        for (index, path) in pathChain.enumerated() {
            if index > 0 {
                let separator = UILabel()
                separator.text = ">"
                separator.font = .systemFont(ofSize: 12)
                separator.textColor = .textSecondary
                breadcrumbStackView.addArrangedSubview(separator)
            }
            
            let button = UIButton(type: .system)
            let name = Self.displayName(for: path)
            button.setTitle(name, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: index == pathChain.count - 1 ? .semibold : .regular)
            button.setTitleColor(index == pathChain.count - 1 ? .textPrimary : .accent, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(breadcrumbTapped(_:)), for: .touchUpInside)
            button.isEnabled = index < pathChain.count - 1 // 当前层不可点击
            breadcrumbStackView.addArrangedSubview(button)
        }
        
        // 滚动到最右
        DispatchQueue.main.async {
            let rightEdge = self.breadcrumbScrollView.contentSize.width - self.breadcrumbScrollView.bounds.width
            if rightEdge > 0 {
                self.breadcrumbScrollView.setContentOffset(CGPoint(x: rightEdge, y: 0), animated: true)
            }
        }
    }
    
    @objc private func breadcrumbTapped(_ sender: UIButton) {
        let targetIndex = sender.tag
        
        // 第 0 个是初始路径，中间的是导航栈，最后一个是 currentPath
        var pathChain = navigationStack
        pathChain.append(currentPath)
        
        guard targetIndex < pathChain.count - 1 else { return }
        
        // 跳转到目标层级
        currentPath = pathChain[targetIndex]
        navigationStack = Array(navigationStack.prefix(targetIndex))
        if shouldKeepTitleFixed {
            navTitleLabel.text = fixedNavTitle
        } else {
            pageTitle = Self.displayName(for: currentPath)
            navTitleLabel.text = pageTitle
        }
        updateBreadcrumb()
        loadFiles()
    }
}

// MARK: - UITableViewDataSource

extension FileBrowserViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = files[indexPath.row]
        
        // Use CategoryItemCell if it's a song OR if we are in Favorites (assuming favorites are songs or should be displayed as such)
        if item.isSong || isFavorites {
            // 歌曲文件使用 CategoryItemCell（带封面、波形动画）
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CategoryItemCell.reuseIdentifier, for: indexPath) as? CategoryItemCell else {
                return UITableViewCell()
            }
            let isPlaying = PlayStateManager.shared.isSongPlaying(title: item.name, filePath: item.path)
            cell.configure(with: item, isPlaying: isPlaying, ipAddress: ipAddress)
            return cell
        } else {
            // 文件夹使用 FileCell
            guard let cell = tableView.dequeueReusableCell(withIdentifier: FileCell.reuseIdentifier, for: indexPath) as? FileCell else {
                return UITableViewCell()
            }
            let isPlaying = PlayStateManager.shared.isPathPlaying(item.path)
            cell.configure(with: item, isPlaying: isPlaying)
            return cell
        }
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
            // (3) 设备端返回数据 result: 2 成功, -1 失败
            // 注意：有些设备可能返回 0 或其他值表示成功，但根据 user spec: result 2 结果，成功返回文件数据，失败返回-1
            let result = data["result"] as? Int ?? -1
            
            // 只要不是 -1 都视为尝试下一步，或者严格按照 spec == 2
            if result != -1 {
                 // 成功，发送获取文件列表指令
                isWaitingForChangePath = false
                requestPlaylist()
            } else {
                 // 失败
                isWaitingForChangePath = false
                showError()
            }
            
        } else if command == "playlist" {
            // 第四步：收到文件列表数据
            loadingIndicator.stopAnimating()
            
            if let resultCount = data["result"] as? Int, let list = data["list"] as? [[String: Any]] {
                 // 校验数量一致性 (可选)
                 print("Playlist count: \(resultCount), actual list count: \(list.count)")
                
                files = FileItem.fromArray(jsonArray: list)
                
                // 自动进入根目录逻辑：
                // 硬盘("/mnt/sda")，U盘("/mnt/usb")，TF卡("/mnt/tf")
                // 如果只有一个节点挂载，初始化进入时候还需要进入其挂载节点下的内容展示
                let rootPaths = ["/mnt/sda", "/mnt/usb", "/mnt/tf"]
                // 检查当前路径是否是根路径之一 (忽略末尾斜杠差异)
                let isRootPath = rootPaths.contains { root in
                    // 简单的路径匹配，去除末尾 /
                    let cur = currentPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let r = root.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    return cur == r
                }
                
                if isRootPath && shouldAutoEnterSingleRoot {
                    if files.count == 1, let firstItem = files.first, firstItem.isDirectory {
                        shouldAutoEnterSingleRoot = false
                        enterDirectory(firstItem)
                        return
                    }
                }
                
                tableView.reloadData()
                emptyLabel.isHidden = !files.isEmpty
                if files.isEmpty {
                    emptyLabel.text = "暂无文件"
                }
            } else {
                // 有时候 list 可能为空或者格式不对
                files = []
                tableView.reloadData()
                emptyLabel.isHidden = false
            }
        } else if command == "play_state" {
            // 更新全局单例（通知会自动触发 updatePlayingState）
            PlayStateManager.shared.update(from: data)
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        // 如果正在加载中，显示错误
        if loadingIndicator.isAnimating {
            showError()
        }
    }
}

// MARK: - T029: MiniPlayerViewDelegate

extension FileBrowserViewController: MiniPlayerViewDelegate {
    
    func miniPlayerViewDidTapPlay(_ view: MiniPlayerView) {
        TCPSocketManager.shared.send(command: CommandBuilder.playPause())
    }
    
    func miniPlayerViewDidTapNext(_ view: MiniPlayerView) {
        TCPSocketManager.shared.send(command: CommandBuilder.next())
    }
    
    func miniPlayerViewDidTap(_ view: MiniPlayerView) {
        guard let state = PlayStateManager.shared.currentState,
              let ip = ipAddress else { return }
        let playerVC = PlayerViewController(playState: state, ipAddress: ip)
        playerVC.modalPresentationStyle = .fullScreen
        present(playerVC, animated: true)
    }
}

// MARK: - File Cell (仅用于文件夹显示)

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
    
    private lazy var waveformView: WaveformView = {
        let view = WaveformView()
        view.isHidden = true
        return view
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
        containerView.addSubviewWithAutoLayout(waveformView)
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
            nameLabel.trailingAnchor.constraint(equalTo: waveformView.leadingAnchor, constant: -8),
            
            waveformView.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            waveformView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: 20),
            waveformView.heightAnchor.constraint(equalToConstant: 16),
            
            arrowImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            arrowImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with item: FileItem, isPlaying: Bool = false) {
        nameLabel.text = item.name
        iconImageView.image = UIImage(systemName: "folder.fill")
        arrowImageView.isHidden = false
        updatePlayingState(isPlaying)
    }
    
    func updatePlayingState(_ isPlaying: Bool) {
        nameLabel.textColor = isPlaying ? .systemBlue : .textPrimary
        iconImageView.tintColor = isPlaying ? .systemBlue : .accent
        
        if isPlaying {
            waveformView.startAnimating()
        } else {
            waveformView.stopAnimating()
        }
    }
}
