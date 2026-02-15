//
//  FileBrowserViewController.swift
//  TYAudio
//
//  文件浏览器
//

import UIKit

class FileBrowserViewController: BaseViewController {
    
    // MARK: - UI Components
    

    
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
    private var ipAddress: String?
    private var files: [FileItem] = []
    private var navigationStack: [String] = []
    private var shouldAutoEnterSingleRoot: Bool = false
    /// 标记是否正在等待 change_path 响应
    private var isWaitingForChangePath: Bool = false
    
    // Add playState to track current playing song
    private var currentPlayState: PlayState?
    
    // MARK: - Initialization
    
    init(path: String, title: String, isFavorites: Bool = false, ipAddress: String? = nil, shouldAutoEnterSingleRoot: Bool = false) {
        self.currentPath = path
        self.pageTitle = title
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
        setupNavBar(title: pageTitle)
        TCPSocketManager.shared.addDelegate(self)
        loadFiles()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        
        // Table View
        view.addSubviewWithAutoLayout(tableView)
        view.addSubviewWithAutoLayout(loadingIndicator)
        view.addSubviewWithAutoLayout(emptyLabel)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
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
        navTitleLabel.text = item.name
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
        let item = files[indexPath.row]
        let isPlaying = item.isSong && item.name == currentPlayState?.title
        cell.configure(with: item, isPlaying: isPlaying, ipAddress: ipAddress)
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
                
                if isRootPath {
                    if files.count == 1, let firstItem = files.first, firstItem.isDirectory {
                        // 只有一个挂载点，自动进入
                        // 注意：这里 directly 调用 enterDirectory 会 push stack，用户想必希望能够 back 回来么？
                        // 通常"初始化进入"意味着用户点进来不仅看到sda，而是直接看到sda1的内容。
                        // 如果用户点 back，应该退回到上一级界面（设备列表），而不是退回到 sda（空壳）。
                        // 但为了稳妥，且遵循 "先获取根其根目录下挂载... 直接展示... 初始化进入时候还需要进入"，
                        // 这里我们使用 enterDirectory，这样用户按 back 会回到这个根列表。
                        // 如果想跳过，需要修改 navigationStack。
                        // 鉴于用户描述“如果超过一个节点... 如果只有一个节点...”，保留层级比较符合直觉。
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
            currentPlayState = PlayState.from(json: data)
            // Refresh to update highlights
            tableView.reloadData()
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        // 如果正在加载中，显示错误
        if loadingIndicator.isAnimating {
            showError()
        }
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
    
    private lazy var coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 4
        imageView.backgroundColor = .secondaryBackground
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var waveformView: WaveformView = {
        let view = WaveformView()
        view.isHidden = true
        return view
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
        containerView.addSubviewWithAutoLayout(coverImageView)
        containerView.addSubviewWithAutoLayout(waveformView)
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
            
            coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            coverImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            coverImageView.widthAnchor.constraint(equalToConstant: 40),
            coverImageView.heightAnchor.constraint(equalToConstant: 40),
            
            waveformView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            waveformView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: 20),
            waveformView.heightAnchor.constraint(equalToConstant: 16),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: waveformView.leadingAnchor, constant: -8),
            
            arrowImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            arrowImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with item: FileItem, isPlaying: Bool = false, ipAddress: String? = nil) {
        nameLabel.text = item.name
        nameLabel.textColor = isPlaying ? .accent : .textPrimary
        
        if item.isDirectory {
            iconImageView.image = UIImage(systemName: "folder.fill")
            iconImageView.isHidden = false
            coverImageView.isHidden = true
            arrowImageView.isHidden = false
            waveformView.stopAnimating()
            
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12).isActive = true
        } else {
            // init state
            iconImageView.isHidden = true
            coverImageView.isHidden = false
            arrowImageView.isHidden = true
            
            if isPlaying {
                waveformView.startAnimating()
            } else {
                waveformView.stopAnimating()
            }
            
            nameLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 12).isActive = true
            
            // Load cover
            coverImageView.image = UIImage(systemName: "music.note")
            coverImageView.tintColor = isPlaying ? .accent : .textSecondary
            
            // Only load cover if it's a song (type 1) and we have an IP
            if item.type == .song, let ip = ipAddress {
                let urlStr = "http://\(ip):9012/cover?path=\(item.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&default=t_img_album.png"
                if let url = URL(string: urlStr) {
                   loadImage(from: url)
                }
            }
        }
    }
    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.coverImageView.image = image
                }
            }
        }.resume()
    }
}
