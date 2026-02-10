//
//  CategoryViewController.swift
//  TYAudio
//
//  分类浏览页面（单曲、专辑、歌手、风格）
//

import UIKit

class CategoryViewController: BaseViewController {
    
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
    
    // MARK: - Properties
    
    private let categoryType: CategoryType
    private var items: [Any] = []  // 可以是 CategoryItem 或 FileItem
    private var isShowingSongs = false
    private var selectedCategoryName: String?
    
    // MARK: - Initialization
    
    init(categoryType: CategoryType) {
        self.categoryType = categoryType
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCategory()
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
        
        updateTitle()
        
        // Table View
        view.addSubviewWithAutoLayout(tableView)
        view.addSubviewWithAutoLayout(loadingIndicator)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func updateTitle() {
        if let name = selectedCategoryName {
            titleLabel.text = name
        } else {
            switch categoryType {
            case .music: titleLabel.text = "单曲"
            case .album: titleLabel.text = "专辑"
            case .artist: titleLabel.text = "歌手"
            case .style: titleLabel.text = "风格"
            }
        }
    }
    
    private func loadCategory() {
        loadingIndicator.startAnimating()
        items = []
        tableView.reloadData()
        
        let command = CommandBuilder.category(type: categoryType, name: selectedCategoryName ?? "")
        TCPSocketManager.shared.send(command: command)
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        if isShowingSongs {
            // 返回分类列表
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
            cell.configure(with: categoryItem)
        } else if let fileItem = item as? FileItem {
            cell.configure(with: fileItem)
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
            
            if let list = data["list"] as? [[String: Any]] {
                // 判断返回的是分类还是歌曲
                if isShowingSongs || categoryType == .music {
                    items = FileItem.fromArray(jsonArray: list)
                } else {
                    items = list.compactMap { CategoryItem.from(json: $0, type: categoryType) }
                }
                tableView.reloadData()
            }
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {
        loadingIndicator.stopAnimating()
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
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubviewWithAutoLayout(containerView)
        containerView.addSubviewWithAutoLayout(iconImageView)
        containerView.addSubviewWithAutoLayout(nameLabel)
        containerView.addSubviewWithAutoLayout(countLabel)
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
            nameLabel.trailingAnchor.constraint(equalTo: countLabel.leadingAnchor, constant: -8),
            
            countLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            arrowImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            arrowImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with item: CategoryItem) {
        nameLabel.text = item.name
        countLabel.text = item.itemCount > 0 ? "\(item.itemCount)首" : ""
        arrowImageView.isHidden = false
        
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
    }
    
    func configure(with item: FileItem) {
        nameLabel.text = item.name
        iconImageView.image = UIImage(systemName: "music.note")
        countLabel.text = ""
        arrowImageView.isHidden = true
    }
}
