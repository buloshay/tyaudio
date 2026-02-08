//
//  DeviceListViewController.swift
//  TYAudio
//
//  我的设备列表页面
//

import UIKit

class DeviceListViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "我的设备"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()
    
    private lazy var versionLabel: UILabel = {
        let label = UILabel()
        label.text = "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .textSecondary
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.register(DeviceCell.self, forCellReuseIdentifier: DeviceCell.reuseIdentifier)
        table.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 100, right: 0)
        return table
    }()
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.isHidden = true
        
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "hifispeaker.2")
        imageView.tintColor = .textSecondary
        imageView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.text = "暂无设备"
        label.font = .systemFont(ofSize: 18)
        label.textColor = .textSecondary
        label.textAlignment = .center
        
        let subLabel = UILabel()
        subLabel.text = "点击下方按钮添加设备"
        subLabel.font = .systemFont(ofSize: 14)
        subLabel.textColor = .textSecondary.withAlphaComponent(0.6)
        subLabel.textAlignment = .center
        
        let stack = UIStackView(arrangedSubviews: [imageView, label, subLabel], axis: .vertical, spacing: 12, alignment: .center)
        view.addSubviewWithAutoLayout(stack)
        stack.centerInSuperview()
        imageView.setSize(width: 80, height: 80)
        
        return view
    }()
    
    private lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("添加设备", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.setTitleColor(.background, for: .normal)
        button.backgroundColor = .accent
        button.setCornerRadius(25)
        button.addTarget(self, action: #selector(addDeviceTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    
    private var devices: [Device] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadDevices()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDevices()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Header
        view.addSubviewWithAutoLayout(headerView)
        headerView.addSubviewWithAutoLayout(titleLabel)
        headerView.addSubviewWithAutoLayout(versionLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 120),
            
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            
            versionLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            versionLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])
        
        // Table View
        view.addSubviewWithAutoLayout(tableView)
        view.addSubviewWithAutoLayout(emptyStateView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
        
        // Add Button
        view.addSubviewWithAutoLayout(addButton)
        NSLayoutConstraint.activate([
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func loadDevices() {
        devices = DeviceManager.shared.devices
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !devices.isEmpty
        tableView.isHidden = devices.isEmpty
    }
    
    // MARK: - Actions
    
    @objc private func addDeviceTapped() {
        let scannerVC = DeviceScannerViewController()
        scannerVC.delegate = self
        let nav = UINavigationController(rootViewController: scannerVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
    
    private func connectToDevice(_ device: Device) {
        DeviceManager.shared.setCurrentDevice(device)
        let controlVC = DeviceControlViewController(device: device)
        navigationController?.pushViewController(controlVC, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension DeviceListViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: DeviceCell.reuseIdentifier, for: indexPath) as? DeviceCell else {
            return UITableViewCell()
        }
        cell.configure(with: devices[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DeviceListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        connectToDevice(devices[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            guard let self = self else { return }
            let device = self.devices[indexPath.row]
            DeviceManager.shared.removeDevice(device)
            self.devices.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.updateEmptyState()
            completion(true)
        }
        deleteAction.backgroundColor = .systemRed
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - DeviceScannerViewControllerDelegate

extension DeviceListViewController: DeviceScannerViewControllerDelegate {
    
    func deviceScannerViewController(_ controller: DeviceScannerViewController, didAddDevice device: Device) {
        DeviceManager.shared.addDevice(device)
        loadDevices()
    }
}

// MARK: - Device Cell

class DeviceCell: UITableViewCell {
    
    static let reuseIdentifier = "DeviceCell"
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.setCornerRadius(12)
        return view
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "hifispeaker.fill")
        imageView.tintColor = .accent
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .textPrimary
        return label
    }()
    
    private lazy var addressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
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
        containerView.addSubviewWithAutoLayout(addressLabel)
        containerView.addSubviewWithAutoLayout(arrowImageView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 18),
            nameLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -12),
            
            addressLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            addressLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            arrowImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            arrowImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with device: Device) {
        nameLabel.text = device.displayName
        addressLabel.text = device.address
    }
}
