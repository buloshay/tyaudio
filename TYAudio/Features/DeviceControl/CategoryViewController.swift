//
//  CategoryViewController.swift
//  TYAudio
//
//  分类浏览页面（单曲、专辑、歌手、风格）
//

import UIKit

class CategoryViewController: BaseViewController {
    
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
    
    /// T030: 专辑/歌手网格视图（2列）
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 100, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.delegate = self
        cv.dataSource = self
        cv.register(AlbumGridCell.self, forCellWithReuseIdentifier: AlbumGridCell.reuseIdentifier)
        cv.isHidden = true
        return cv
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .accent
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    /// T029: 底部常驻 MiniPlayer
    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.delegate = self
        return view
    }()
    
    // MARK: - Properties
    
    private let categoryType: CategoryType
    private let ipAddress: String
    private var items: [Any] = []  // 可以是 CategoryItem 或 FileItem
    private var isShowingSongs = false
    private var selectedCategoryName: String?
    private var playStateObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    init(categoryType: CategoryType, ipAddress: String) {
        self.categoryType = categoryType
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
        setupNavBar(title: "") // Title set in updateTitle()
        updateTitle()
        loadCategory()
        TCPSocketManager.shared.addDelegate(self)
        
        // 监听全局播放状态变化
        playStateObserver = NotificationCenter.default.addObserver(
            forName: PlayStateManager.didUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.updatePlayingState()
            // T029: 更新 MiniPlayer
            if let state = PlayStateManager.shared.currentState {
                self.miniPlayerView.update(with: state, ipAddress: self.ipAddress)
            }
        }
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
        
        // Table View
        view.addSubviewWithAutoLayout(tableView)
        // T030: Collection View (grid)
        view.addSubviewWithAutoLayout(collectionView)
        view.addSubviewWithAutoLayout(loadingIndicator)
        
        // T029: MiniPlayer
        view.addSubviewWithAutoLayout(miniPlayerView)
        
        NSLayoutConstraint.activate([
            // T029: MiniPlayer 固定在底部
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            miniPlayerView.heightAnchor.constraint(equalToConstant: 70),
            
            tableView.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: miniPlayerView.topAnchor),
            
            // T030: collectionView 同 tableView 位置
            collectionView.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: miniPlayerView.topAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func updateTitle() {
        if let name = selectedCategoryName {
            navTitleLabel.text = name
        } else {
            switch categoryType {
            case .music: navTitleLabel.text = "单曲"
            case .album: navTitleLabel.text = "专辑"
            case .artist: navTitleLabel.text = "歌手"
            case .style: navTitleLabel.text = "风格"
            }
        }
    }
    
    private func loadCategory() {
        loadingIndicator.startAnimating()
        items = []
        tableView.reloadData()
        collectionView.reloadData()
        
        // 始终使用 count=-1 获取完整数据（count=0 仅通知设备不返回数据）
        let command = CommandBuilder.category(type: categoryType, name: selectedCategoryName ?? "", count: -1,updateList: true)
        print("[Category] 发送指令: type=\(categoryType.rawValue), name=\(selectedCategoryName ?? "")")
        TCPSocketManager.shared.send(command: command)
        
        // 获取播放状态以更新高亮（歌曲列表和分类列表都需要）
        TCPSocketManager.shared.send(command: CommandBuilder.getPlayState())
    }
    
    /// T030: 判断是否使用网格布局（专辑/歌手 + 非歌曲列表）
    private var shouldUseGridLayout: Bool {
        return !isShowingSongs && (categoryType == .album || categoryType == .artist)
    }
    
    /// T030: 切换 tableView / collectionView 显示
    private func updateListViewVisibility() {
        let useGrid = shouldUseGridLayout
        tableView.isHidden = useGrid
        collectionView.isHidden = !useGrid
        if useGrid {
            collectionView.reloadData()
        } else {
            tableView.reloadData()
        }
    }
    
    // MARK: - Actions
    
    override func navBackTapped() {
        if isShowingSongs && categoryType != .music && selectedCategoryName != nil {
            // 从子分类歌曲列表返回到分类列表（仅专辑、歌手、风格有二级结构）
            isShowingSongs = false
            selectedCategoryName = nil
            updateTitle()
            loadCategory()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    private func selectCategory(_ item: CategoryItem) {
        selectedCategoryName = item.name
        isShowingSongs = true
        updateTitle()
        loadCategory()
    }
    
    private func playSong(at index: Int) {
        TCPSocketManager.shared.send(command: CommandBuilder.playAt(index: index))
        
        // 乐观更新到全局单例
        if let fileItem = items[index] as? FileItem {
            PlayStateManager.shared.updateOptimistically(
                index: index,
                title: fileItem.name,
                filePath: fileItem.path
            )
        }
    }
    
    private func updatePlayingState() {
        for cell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell),
                  let categoryCell = cell as? CategoryItemCell else { continue }
            
            let item = items[indexPath.row]
            let isPlaying: Bool
            if let fileItem = item as? FileItem {
                // 歌曲：用标题匹配
                isPlaying = PlayStateManager.shared.isSongPlaying(title: fileItem.name)
            } else if let categoryItem = item as? CategoryItem {
                // 分类项（专辑/歌手/风格）
                isPlaying = PlayStateManager.shared.isCategoryPlaying(name: categoryItem.name, categoryType: categoryType)
            } else {
                isPlaying = false
            }
            categoryCell.updatePlayingState(isPlaying)
        }
    }
}

// MARK: - UITableViewDataSource

extension CategoryViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CategoryItemCell.reuseIdentifier, for: indexPath) as? CategoryItemCell else {
            return UITableViewCell()
        }
        
        let item = items[indexPath.row]
        if let categoryItem = item as? CategoryItem {
            let isPlaying = PlayStateManager.shared.isCategoryPlaying(name: categoryItem.name, categoryType: categoryType)
            cell.configure(with: categoryItem, isPlaying: isPlaying)
        } else if let fileItem = item as? FileItem {
            // 检查是否是当前播放的歌曲
            let isPlaying = PlayStateManager.shared.isSongPlaying(title: fileItem.name)
            cell.configure(with: fileItem, isPlaying: isPlaying, ipAddress: ipAddress)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension CategoryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = items[indexPath.row]
        if let categoryItem = item as? CategoryItem {
            selectCategory(categoryItem)
        } else if item is FileItem {
            playSong(at: indexPath.row)
        }
    }
}

// MARK: - TCPSocketManagerDelegate

extension CategoryViewController: TCPSocketManagerDelegate {
    
    func tcpSocketManager(_ manager: TCPSocketManager, didChangeState state: TCPConnectionState) {}
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
        if command == "category" {
            loadingIndicator.stopAnimating()
            
            let resultCount = data["result"] as? Int ?? 0
            print("[Category] 收到响应: result=\(resultCount)")
            
            if let list = data["list"] as? [[String: Any]] {
                // 根据 list 项的 type 字段判断：1=歌曲，0=分类
                let isSongList = list.first.flatMap { $0["type"] as? Int } == 1
                
                if isSongList || categoryType == .music {
                    isShowingSongs = true
                    items = FileItem.fromArray(jsonArray: list)
                } else {
                    isShowingSongs = (selectedCategoryName != nil)
                    items = list.compactMap { CategoryItem.from(json: $0, type: categoryType) }
                }
                
                // T030: 根据类型切换 table/grid 显示
                updateListViewVisibility()
                print("[Category] 解析完成: \(items.count)条, isSongList=\(isSongList), useGrid=\(shouldUseGridLayout)")
            }
        } else if command == "play_state" {
            // 更新全局单例（通知会自动触发 updatePlayingState）
            PlayStateManager.shared.update(from: data)
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        loadingIndicator.stopAnimating()
    }
}

// MARK: - T029: MiniPlayerViewDelegate

extension CategoryViewController: MiniPlayerViewDelegate {
    
    func miniPlayerViewDidTapPlay(_ view: MiniPlayerView) {
        TCPSocketManager.shared.send(command: CommandBuilder.playPause())
    }
    
    func miniPlayerViewDidTapNext(_ view: MiniPlayerView) {
        TCPSocketManager.shared.send(command: CommandBuilder.next())
    }
    
    func miniPlayerViewDidTap(_ view: MiniPlayerView) {
        guard let state = PlayStateManager.shared.currentState else { return }
        let playerVC = PlayerViewController(playState: state, ipAddress: ipAddress)
        playerVC.modalPresentationStyle = .fullScreen
        present(playerVC, animated: true)
    }
}

// MARK: - Category Item Cell

class CategoryItemCell: UITableViewCell {
    
    static let reuseIdentifier = "CategoryItemCell"
    
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
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .textPrimary
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .textSecondary
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
    
    /// nameLabel 左侧约束：跟随 coverImageView（歌曲模式）
    private var nameLabelToCoverConstraint: NSLayoutConstraint!
    /// nameLabel 左侧约束：跟随 iconImageView（分类模式）
    private var nameLabelToIconConstraint: NSLayoutConstraint!
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubviewWithAutoLayout(containerView)
        containerView.addSubviewWithAutoLayout(iconImageView)
        containerView.addSubviewWithAutoLayout(coverImageView)
        containerView.addSubviewWithAutoLayout(waveformView)
        containerView.addSubviewWithAutoLayout(nameLabel)
        containerView.addSubviewWithAutoLayout(countLabel)
        containerView.addSubviewWithAutoLayout(arrowImageView)
        
        // 创建两个互斥的 nameLabel leading 约束
        nameLabelToCoverConstraint = nameLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 12)
        nameLabelToIconConstraint = nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12)
        
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
            
            waveformView.trailingAnchor.constraint(equalTo: countLabel.leadingAnchor, constant: -8),
            waveformView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: 20),
            waveformView.heightAnchor.constraint(equalToConstant: 16),
            
            // 默认使用 cover 约束（歌曲模式）
            nameLabelToCoverConstraint,
            nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: waveformView.leadingAnchor, constant: -8),
            
            countLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            arrowImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            arrowImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with item: CategoryItem, isPlaying: Bool = false) {
        nameLabel.text = item.displayName
        
        nameLabel.textColor = isPlaying ? .systemBlue : .textPrimary
        countLabel.text = item.itemCount > 0 ? "\(item.itemCount)首" : ""
        arrowImageView.isHidden = false
        iconImageView.isHidden = false
        coverImageView.isHidden = true
        
        switch item.type {
        case .album:
            iconImageView.image = UIImage(systemName: "square.stack.fill")
        case .artist:
            iconImageView.image = UIImage(systemName: "person.fill")
        case .style:
            iconImageView.image = UIImage(systemName: "guitars.fill")
        case .music:
            iconImageView.image = UIImage(systemName: "music.note")
        }
        iconImageView.tintColor = isPlaying ? .systemBlue : .accent
        
        if isPlaying {
            waveformView.startAnimating()
        } else {
            waveformView.stopAnimating()
        }
        
        // Reset constraints for non-song items
        updateConstraintsForSong(false)
    }
    
    func configure(with item: FileItem, isPlaying: Bool = false, ipAddress: String? = nil) {
        nameLabel.text = item.name
        // Ensure blue color as requested
        nameLabel.textColor = isPlaying ? .systemBlue : .textPrimary
        
        countLabel.text = ""
        arrowImageView.isHidden = true
        iconImageView.isHidden = true
        coverImageView.isHidden = false
        
        if isPlaying {
            waveformView.startAnimating()
        } else {
            waveformView.stopAnimating()
        }
        
        // Reset constraints for song items
        updateConstraintsForSong(true)
        
        // Load cover
        coverImageView.image = UIImage(systemName: "music.note")
        coverImageView.tintColor = isPlaying ? .systemBlue : .textSecondary
        
        if let ip = ipAddress {
             let urlStr = "http://\(ip):9012/cover?path=\(item.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&default=t_img_album.png"
             if let url = URL(string: urlStr) {
                 loadImage(from: url)
             }
        }
    }
    
    private func updateConstraintsForSong(_ isSong: Bool) {
        // 切换 nameLabel 的 leading 约束，避免重复添加
        nameLabelToCoverConstraint.isActive = isSong
        nameLabelToIconConstraint.isActive = !isSong
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
    
    func updatePlayingState(_ isPlaying: Bool) {
        // Only update UI elements related to playing state, do NOT reload image
        nameLabel.textColor = isPlaying ? .systemBlue : .textPrimary
        coverImageView.tintColor = isPlaying ? .systemBlue : .textSecondary
        iconImageView.tintColor = isPlaying ? .systemBlue : .accent
        
        if isPlaying {
            waveformView.startAnimating()
        } else {
            waveformView.stopAnimating()
        }
    }
}

// MARK: - T030: UICollectionViewDataSource

extension CategoryViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return shouldUseGridLayout ? items.count : 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AlbumGridCell.reuseIdentifier, for: indexPath) as? AlbumGridCell else {
            return UICollectionViewCell()
        }
        
        if let categoryItem = items[indexPath.item] as? CategoryItem {
            let isPlaying = PlayStateManager.shared.isCategoryPlaying(name: categoryItem.name, categoryType: categoryType)
            cell.configure(with: categoryItem, ipAddress: ipAddress, isPlaying: isPlaying)
        }
        
        return cell
    }
}

// MARK: - T030: UICollectionViewDelegate

extension CategoryViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let categoryItem = items[indexPath.item] as? CategoryItem {
            selectCategory(categoryItem)
        }
    }
}

// MARK: - T030: UICollectionViewDelegateFlowLayout

extension CategoryViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 2 列网格，间距 12，左右边距 16
        let totalSpacing: CGFloat = 16 * 2 + 12
        let itemWidth = (collectionView.bounds.width - totalSpacing) / 2
        // 高度 = 封面(正方形) + 名称区域(40pt)
        let itemHeight = itemWidth + 40
        return CGSize(width: itemWidth, height: itemHeight)
    }
}

// MARK: - T030: AlbumGridCell

class AlbumGridCell: UICollectionViewCell {
    
    static let reuseIdentifier = "AlbumGridCell"
    
    private lazy var coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .secondaryBackground
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = .textSecondary
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private var currentImageTask: URLSessionDataTask?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentImageTask?.cancel()
        currentImageTask = nil
        coverImageView.image = UIImage(systemName: "music.note")
        coverImageView.tintColor = .textSecondary
        nameLabel.text = nil
        nameLabel.textColor = .textPrimary
    }
    
    private func setupUI() {
        contentView.backgroundColor = .cardBackground
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
        
        contentView.addSubviewWithAutoLayout(coverImageView)
        contentView.addSubviewWithAutoLayout(nameLabel)
        
        NSLayoutConstraint.activate([
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalTo: coverImageView.widthAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6)
        ])
    }
    
    func configure(with item: CategoryItem, ipAddress: String, isPlaying: Bool = false) {
        nameLabel.text = item.displayName
        nameLabel.textColor = isPlaying ? .systemBlue : .textPrimary
        
        // 加载封面：/cover?path={path}&default=t_img_album.png
        guard !item.path.isEmpty else { return }
        let encodedPath = item.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "http://\(ipAddress):9012/cover?path=\(encodedPath)&default=t_img_album.png"
        guard let url = URL(string: urlStr) else { return }
        
        currentImageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.coverImageView.image = image
                    self?.coverImageView.contentMode = .scaleAspectFill
                }
            }
        }
        currentImageTask?.resume()
    }
}
