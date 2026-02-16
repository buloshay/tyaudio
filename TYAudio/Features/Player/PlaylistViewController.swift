//
//  PlaylistViewController.swift
//  TYAudio
//
//  当前播放列表
//

import UIKit

class PlaylistViewController: BaseViewController {
    
    // MARK: - UI Components
    

    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.register(CategoryItemCell.self, forCellReuseIdentifier: CategoryItemCell.reuseIdentifier)
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 100, right: 0)
        return table
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .accent
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Properties
    
    private var songs: [FileItem] = []
    private var currentPlayState: PlayState?
    private var ipAddress: String
    
    // MARK: - Initialization
    
    init(ipAddress: String) {
        self.ipAddress = ipAddress
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavBar(title: "播放列表", hideLeftButton: true)
        
        // Adjust height for Playlist (Original 60 + 10 = 70)
        if let heightConstraint = customNavigationBar.constraints.first(where: { $0.firstAttribute == .height }) {
            heightConstraint.constant = 70
        }
        
        setRightButton(image: UIImage(systemName: "xmark"), action: #selector(closeTapped))
        loadPlaylist()
        TCPSocketManager.shared.addDelegate(self)
        
        // 确保导航栏在最上层，防止被 tableView 遮挡
        view.bringSubviewToFront(customNavigationBar)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        
        // Table View
        view.addSubviewWithAutoLayout(tableView)
        view.addSubviewWithAutoLayout(loadingIndicator)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor, constant: 40)
        ])
    }
    
    private func loadPlaylist() {
        loadingIndicator.startAnimating()
        
        // 获取当前播放列表 + 播放状态（解决首次打开 index=0 的问题）
        TCPSocketManager.shared.send(command: CommandBuilder.getCurrentPlaylist())
        TCPSocketManager.shared.send(command: CommandBuilder.getPlayState())
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    private func playSong(at index: Int) {
        TCPSocketManager.shared.send(command: CommandBuilder.playAt(index: index))
        
        // Optimistically update state
        if currentPlayState == nil {
            currentPlayState = PlayState()
        }
        currentPlayState?.currentIndex = index
        currentPlayState?.status = 1 // Playing
        
        if index < songs.count, let fileItem = songs[index] as FileItem? {
            currentPlayState?.title = fileItem.name
            currentPlayState?.filePath = fileItem.path
        }
        
        updatePlayingState()
    }
    
    /// 逐 cell 更新播放状态，避免 reloadData 导致的闪烁
    private func updatePlayingState() {
        guard let current = currentPlayState else { return }
        
        for cell in tableView.visibleCells {
            if let indexPath = tableView.indexPath(for: cell),
               let categoryCell = cell as? CategoryItemCell,
               indexPath.row < songs.count {
                let fileItem = songs[indexPath.row]
                let isPlaying = fileItem.name == current.title
                categoryCell.updatePlayingState(isPlaying)
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension PlaylistViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CategoryItemCell.reuseIdentifier, for: indexPath) as? CategoryItemCell else {
            return UITableViewCell()
        }
        let item = songs[indexPath.row]
        let isPlaying = item.name == currentPlayState?.title
        cell.configure(with: item, isPlaying: isPlaying, ipAddress: ipAddress)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PlaylistViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        playSong(at: indexPath.row)
    }
}

// MARK: - TCPSocketManagerDelegate

extension PlaylistViewController: TCPSocketManagerDelegate {
    
    func tcpSocketManager(_ manager: TCPSocketManager, didChangeState state: TCPConnectionState) {}
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
        if command == "playlist" {
            loadingIndicator.stopAnimating()
            
            if let list = data["list"] as? [[String: Any]] {
                songs = FileItem.fromArray(jsonArray: list)
                tableView.reloadData()
            }
        } else if command == "play_state" {
            currentPlayState = PlayState.from(json: data)
            PlayStateManager.shared.update(from: data)
            updatePlayingState()
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        loadingIndicator.stopAnimating()
    }
}
