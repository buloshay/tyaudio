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
        table.register(PlaylistItemCell.self, forCellReuseIdentifier: PlaylistItemCell.reuseIdentifier)
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
    private var currentIndex: Int = 0
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
        
        // 先切换到根目录，再获取当前播放列表
        TCPSocketManager.shared.send(command: CommandBuilder.changePath(dir: "/")) { [weak self] _ in
            TCPSocketManager.shared.send(command: CommandBuilder.getCurrentPlaylist())
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    private func playSong(at index: Int) {
        TCPSocketManager.shared.send(command: CommandBuilder.playAt(index: index))
        currentIndex = index
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension PlaylistViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PlaylistItemCell.reuseIdentifier, for: indexPath) as? PlaylistItemCell else {
            return UITableViewCell()
        }
        let isPlaying = indexPath.row == currentIndex
        cell.configure(with: songs[indexPath.row], isPlaying: isPlaying, ipAddress: ipAddress)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PlaylistViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
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
            if let index = data["current_index"] as? Int {
                currentIndex = index
                tableView.reloadData()
            }
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        loadingIndicator.stopAnimating()
    }
}

// MARK: - Playlist Item Cell

class PlaylistItemCell: UITableViewCell {
    
    static let reuseIdentifier = "PlaylistItemCell"
    
    private lazy var playingIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .playing
        view.setCornerRadius(2)
        view.isHidden = true
        return view
    }()
    
    private lazy var indexLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .textSecondary
        label.textAlignment = .center
        return label
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .textPrimary
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private lazy var playingIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "waveform")
        imageView.tintColor = .playing
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .secondaryBackground
        imageView.setCornerRadius(6)
        imageView.clipsToBounds = true
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = .textSecondary
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
        
        contentView.addSubviewWithAutoLayout(playingIndicator)
        contentView.addSubviewWithAutoLayout(indexLabel)
        contentView.addSubviewWithAutoLayout(coverImageView)
        contentView.addSubviewWithAutoLayout(nameLabel)
        contentView.addSubviewWithAutoLayout(playingIconView)
        
        NSLayoutConstraint.activate([
            playingIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playingIndicator.widthAnchor.constraint(equalToConstant: 4),
            playingIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            indexLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            indexLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 30),
            
            coverImageView.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 4),
            coverImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            coverImageView.widthAnchor.constraint(equalToConstant: 40),
            coverImageView.heightAnchor.constraint(equalToConstant: 40),
            
            nameLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: playingIconView.leadingAnchor, constant: -8),
            
            playingIconView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            playingIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playingIconView.widthAnchor.constraint(equalToConstant: 20),
            playingIconView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with item: FileItem, isPlaying: Bool, ipAddress: String) {
        nameLabel.text = item.name
        playingIndicator.isHidden = !isPlaying
        playingIconView.isHidden = !isPlaying
        indexLabel.isHidden = isPlaying
        
        nameLabel.textColor = isPlaying ? .playing : .textPrimary
        
        // Load cover
        loadCoverImage(item: item, ipAddress: ipAddress)
    }
    
    private func loadCoverImage(item: FileItem, ipAddress: String) {
        coverImageView.image = UIImage(systemName: "music.note") // Reset
        
        guard item.isSong else { return }
        
        var components = URLComponents()
        components.scheme = "http"
        components.host = ipAddress
        components.port = 9012
        components.path = "/cover"
        components.queryItems = [
            URLQueryItem(name: "path", value: item.path),
            URLQueryItem(name: "default", value: "t_img_album.png")
        ]
        
        guard let url = components.url else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.coverImageView.image = image
                }
            }
        }.resume()
    }
}
