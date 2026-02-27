//
//  DeviceScannerViewController.swift
//  TYAudio
//
//  设备扫描页面
//

import UIKit
import AVFoundation
import AudioToolbox

protocol DeviceScannerViewControllerDelegate: AnyObject {
    func deviceScannerViewController(_ controller: DeviceScannerViewController, didAddDevice device: Device)
}

class DeviceScannerViewController: BaseViewController {
    
    // MARK: - UI Components
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .textPrimary
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "添加设备"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        return label
    }()
    
    private lazy var segmentControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["自动扫描", "手动添加", "扫码添加"])
        control.selectedSegmentIndex = 0
        control.backgroundColor = .cardBackground
        control.selectedSegmentTintColor = .accent
        control.setTitleTextAttributes([.foregroundColor: UIColor.textSecondary], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.background], for: .selected)
        control.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        return control
    }()
    
    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.text = "请确认手机与设备在同一局域网内"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .textSecondary
        label.textAlignment = .center
        return label
    }()
    
    // 自动扫描视图
    private lazy var scanContainerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var scanAnimationView: UIView = {
        let view = UIView()
        view.backgroundColor = .accent.withAlphaComponent(0.1)
        view.setCornerRadius(100)
        return view
    }()
    
    private lazy var scanIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "wave.3.right.circle.fill")
        imageView.tintColor = .accent
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.text = "正在扫描..."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .textPrimary
        label.textAlignment = .center
        return label
    }()
    
    private lazy var progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .accent
        progress.trackTintColor = .cardBackground
        progress.setCornerRadius(2)
        return progress
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.register(ScanResultCell.self, forCellReuseIdentifier: ScanResultCell.reuseIdentifier)
        return table
    }()
    
    private lazy var rescanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重新扫描", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.accent, for: .normal)
        button.addTarget(self, action: #selector(rescanTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    // 手动添加视图
    private lazy var manualContainerView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()
    
    private lazy var ipTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "请输入设备IP地址"
        textField.font = .systemFont(ofSize: 16)
        textField.textColor = .textPrimary
        textField.backgroundColor = .cardBackground
        textField.setCornerRadius(12)
        textField.keyboardType = .decimalPad
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftViewMode = .always
        textField.attributedPlaceholder = NSAttributedString(string: "请输入设备IP地址", attributes: [.foregroundColor: UIColor.textSecondary])
        return textField
    }()
    
    private lazy var addManualButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("添加设备", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.setTitleColor(.background, for: .normal)
        button.backgroundColor = .accent
        button.setCornerRadius(12)
        button.addTarget(self, action: #selector(addManualDeviceTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    
    weak var delegate: DeviceScannerViewControllerDelegate?
    
    private let scanner = DeviceScanner()
    private var foundDevices: [Device] = []
    
    // QR Scanner properties
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // QR Scanner UI
    private lazy var qrContainerView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = .black
        return view
    }()
    
    private lazy var qrFrameView: UIView = {
        let view = UIView()
        view.layer.borderColor = UIColor.accent.cgColor
        view.layer.borderWidth = 2
        view.setCornerRadius(12)
        return view
    }()
    
    private lazy var qrHintLabel: UILabel = {
        let label = UILabel()
        label.text = "将二维码放入框内扫描"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        scanner.delegate = self
        startScanning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        scanner.stopScan()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        navigationController?.setNavigationBarHidden(true, animated: false)
        hideCustomNavBar()
        
        // Header
        view.addSubviewWithAutoLayout(closeButton)
        view.addSubviewWithAutoLayout(titleLabel)
        view.addSubviewWithAutoLayout(segmentControl)
        view.addSubviewWithAutoLayout(hintLabel)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            segmentControl.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 20),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            segmentControl.heightAnchor.constraint(equalToConstant: 36),
            
            hintLabel.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 16),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // Scan Container
        view.addSubviewWithAutoLayout(scanContainerView)
        scanContainerView.addSubviewWithAutoLayout(scanAnimationView)
        scanContainerView.addSubviewWithAutoLayout(scanIconView)
        scanContainerView.addSubviewWithAutoLayout(progressLabel)
        scanContainerView.addSubviewWithAutoLayout(progressView)
        scanContainerView.addSubviewWithAutoLayout(tableView)
        scanContainerView.addSubviewWithAutoLayout(rescanButton)
        
        NSLayoutConstraint.activate([
            scanContainerView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 30),
            scanContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            scanAnimationView.topAnchor.constraint(equalTo: scanContainerView.topAnchor, constant: 20),
            scanAnimationView.centerXAnchor.constraint(equalTo: scanContainerView.centerXAnchor),
            scanAnimationView.widthAnchor.constraint(equalToConstant: 200),
            scanAnimationView.heightAnchor.constraint(equalToConstant: 200),
            
            scanIconView.centerXAnchor.constraint(equalTo: scanAnimationView.centerXAnchor),
            scanIconView.centerYAnchor.constraint(equalTo: scanAnimationView.centerYAnchor),
            scanIconView.widthAnchor.constraint(equalToConstant: 80),
            scanIconView.heightAnchor.constraint(equalToConstant: 80),
            
            progressLabel.topAnchor.constraint(equalTo: scanAnimationView.bottomAnchor, constant: 20),
            progressLabel.centerXAnchor.constraint(equalTo: scanContainerView.centerXAnchor),
            
            progressView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: scanContainerView.leadingAnchor, constant: 60),
            progressView.trailingAnchor.constraint(equalTo: scanContainerView.trailingAnchor, constant: -60),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            rescanButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            rescanButton.centerXAnchor.constraint(equalTo: scanContainerView.centerXAnchor),
            
            tableView.topAnchor.constraint(equalTo: rescanButton.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: scanContainerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: scanContainerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: scanContainerView.bottomAnchor)
        ])
        
        // Manual Container
        view.addSubviewWithAutoLayout(manualContainerView)
        manualContainerView.addSubviewWithAutoLayout(ipTextField)
        manualContainerView.addSubviewWithAutoLayout(addManualButton)
        
        NSLayoutConstraint.activate([
            manualContainerView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 30),
            manualContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            manualContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            manualContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            ipTextField.topAnchor.constraint(equalTo: manualContainerView.topAnchor, constant: 40),
            ipTextField.leadingAnchor.constraint(equalTo: manualContainerView.leadingAnchor, constant: 24),
            ipTextField.trailingAnchor.constraint(equalTo: manualContainerView.trailingAnchor, constant: -24),
            ipTextField.heightAnchor.constraint(equalToConstant: 50),
            
            addManualButton.topAnchor.constraint(equalTo: ipTextField.bottomAnchor, constant: 24),
            addManualButton.leadingAnchor.constraint(equalTo: ipTextField.leadingAnchor),
            addManualButton.trailingAnchor.constraint(equalTo: ipTextField.trailingAnchor),
            addManualButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // QR Container
        view.addSubviewWithAutoLayout(qrContainerView)
        qrContainerView.addSubviewWithAutoLayout(qrFrameView)
        qrContainerView.addSubviewWithAutoLayout(qrHintLabel)
        
        NSLayoutConstraint.activate([
            qrContainerView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 30),
            qrContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            qrContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            qrContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            qrFrameView.centerXAnchor.constraint(equalTo: qrContainerView.centerXAnchor),
            qrFrameView.centerYAnchor.constraint(equalTo: qrContainerView.centerYAnchor, constant: -40),
            qrFrameView.widthAnchor.constraint(equalToConstant: 250),
            qrFrameView.heightAnchor.constraint(equalToConstant: 250),
            
            qrHintLabel.topAnchor.constraint(equalTo: qrFrameView.bottomAnchor, constant: 24),
            qrHintLabel.centerXAnchor.constraint(equalTo: qrContainerView.centerXAnchor)
        ])
    }
    
    private func startScanning() {
        foundDevices = []
        tableView.reloadData()
        progressView.progress = 0
        progressLabel.text = "正在扫描..."
        rescanButton.isHidden = true
        startScanAnimation()
        scanner.startScan()
    }
    
    private func startScanAnimation() {
        UIView.animate(withDuration: 1.5, delay: 0, options: [.repeat, .autoreverse]) {
            self.scanAnimationView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            self.scanAnimationView.alpha = 0.5
        }
    }
    
    private func stopScanAnimation() {
        scanAnimationView.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.3) {
            self.scanAnimationView.transform = .identity
            self.scanAnimationView.alpha = 1
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func segmentChanged() {
        let selectedIndex = segmentControl.selectedSegmentIndex
        
        // Hide all containers
        scanContainerView.isHidden = true
        manualContainerView.isHidden = true
        qrContainerView.isHidden = true
        
        // Stop QR session if not on QR tab
        if selectedIndex != 2 {
            stopQRScanning()
        }
        
        switch selectedIndex {
        case 0: // 自动扫描
            scanContainerView.isHidden = false
            hintLabel.text = "请确认手机与设备在同一局域网内"
            if foundDevices.isEmpty {
                startScanning()
            }
        case 1: // 手动添加
            manualContainerView.isHidden = false
            hintLabel.text = "请输入设备IP地址"
        case 2: // 扫码添加
            qrContainerView.isHidden = false
            hintLabel.text = "扫描设备二维码添加"
            startQRScanning()
        default:
            break
        }
    }
    
    @objc private func rescanTapped() {
        startScanning()
    }
    
    @objc private func addManualDeviceTapped() {
        guard let ip = ipTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !ip.isEmpty else {
            showAlert(title: "提示", message: "请输入IP地址")
            return
        }
        
        // T017: 前置校验 — IP 格式 + TCP 可达性
        validateAndAddDevice(ip: ip, port: 8001, model: nil)
    }
    
    private func addDevice(_ device: Device) {
        delegate?.deviceScannerViewController(self, didAddDevice: device)
        dismiss(animated: true)
    }
    
    /// T016/T017/T018: 统一校验后添加设备
    private func validateAndAddDevice(ip: String, port: UInt16 = 8001, model: String?) {
        // 第一步：IP 格式校验
        guard DeviceReachabilityValidator.isValidIP(ip) else {
            showAlert(title: "IP 格式错误", message: "请输入正确的 IP 地址，例如 192.168.1.100")
            return
        }
        
        // 第二步：TCP 可达性校验
        showLoading(message: "正在检测设备连通性...")
        DeviceReachabilityValidator.checkReachability(ip: ip, port: port) { [weak self] reachable in
            guard let self = self else { return }
            self.hideLoading()
            
            if reachable {
                var device = Device(ipAddress: ip, port: port)
                if let m = model {
                    device = Device(ipAddress: ip, port: port, model: m)
                }
                self.addDevice(device)
            } else {
                self.showAlert(title: "连接不可用", message: "无法连接到 \(ip):\(port)，请确认设备已开机且在同一局域网内")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - QR Scanner
    
    private func startQRScanning() {
        guard captureSession == nil else {
            captureSession?.startRunning()
            return
        }
        
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.showCameraPermissionAlert()
                    }
                }
            }
        default:
            showCameraPermissionAlert()
        }
    }
    
    private func stopQRScanning() {
        captureSession?.stopRunning()
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showAlert(title: "错误", message: "无法访问摄像头")
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
        }
        
        // Setup preview layer
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = qrContainerView.bounds
        qrContainerView.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
        
        captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "需要相机权限",
            message: "请在设置中允许访问相机以扫描二维码",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }
    
    private func handleQRCode(_ code: String) {
        // Stop scanning
        stopQRScanning()
        
        print("Scanned QR Code: \(code)")
        
        // Try to parse the QR code
        var ipAddress: String?
        var model: String?
        let port = 8001
        
        // 1. Try "Model; IP" format (e.g. "TY-i60; 192.168.1.3")
        if code.contains(";") {
            let components = code.components(separatedBy: ";")
            if components.count >= 2 {
                let p1 = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let p2 = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check if the second part is an IP
                let ipComponents = p2.components(separatedBy: ".")
                if ipComponents.count == 4, ipComponents.allSatisfy({ Int($0) != nil && Int($0)! >= 0 && Int($0)! <= 255 }) {
                    model = p1
                    ipAddress = p2
                }
            }
        }
        
        // 2. Try JSON format: {"ip":"192.168.x.x","model":"xxx"}
        if ipAddress == nil, let data = code.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            ipAddress = json["ip"] as? String
            model = json["model"] as? String
        }
        
        // 3. Try plain IP address
        if ipAddress == nil {
            // Validate IP format
            let components = code.components(separatedBy: ".")
            if components.count == 4, components.allSatisfy({ Int($0) != nil && Int($0)! >= 0 && Int($0)! <= 255 }) {
                ipAddress = code
            }
        }
        
        guard let ip = ipAddress else {
            showAlert(title: "无效二维码", message: "未能识别设备信息: \(code)\n请确认二维码正确")
            // Resume scanning after alert dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startQRScanning()
            }
            return
        }
        
        // T018: 扫码添加也走统一校验链路
        validateAndAddDevice(ip: ip, port: UInt16(port), model: model)
    }
}

// MARK: - DeviceScannerDelegate

extension DeviceScannerViewController: DeviceScannerDelegate {
    
    func deviceScanner(_ scanner: DeviceScanner, didUpdateState state: ScanningState) {
        switch state {
        case .scanning(let progress):
            progressView.progress = progress
            progressLabel.text = "正在扫描... \(Int(progress * 100))%"
            
        case .completed(let devices):
            stopScanAnimation()
            progressView.progress = 1
            progressLabel.text = "扫描完成，发现 \(devices.count) 个设备"
            rescanButton.isHidden = false
            
        case .failed(let error):
            stopScanAnimation()
            progressLabel.text = error.localizedDescription
            rescanButton.isHidden = false
            
        case .idle:
            break
        }
    }
    
    func deviceScanner(_ scanner: DeviceScanner, didFindDevice device: Device) {
        foundDevices.append(device)
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension DeviceScannerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return foundDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ScanResultCell.reuseIdentifier, for: indexPath) as? ScanResultCell else {
            return UITableViewCell()
        }
        let device = foundDevices[indexPath.row]
        cell.configure(with: device)
        cell.onAddTapped = { [weak self] in
            self?.addDevice(device)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DeviceScannerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension DeviceScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let stringValue = metadataObject.stringValue else {
            return
        }
        
        // Vibrate to indicate successful scan
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        handleQRCode(stringValue)
    }
}

// MARK: - Scan Result Cell

class ScanResultCell: UITableViewCell {
    
    static let reuseIdentifier = "ScanResultCell"
    
    var onAddTapped: (() -> Void)?
    
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
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .textPrimary
        return label
    }()
    
    private lazy var addressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .textSecondary
        return label
    }()
    
    private lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("添加", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(.background, for: .normal)
        button.backgroundColor = .accent
        button.setCornerRadius(15)
        button.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        return button
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
        containerView.addSubviewWithAutoLayout(addButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -12),
            
            addressLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            addressLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            addButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            addButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 60),
            addButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    func configure(with device: Device) {
        nameLabel.text = device.displayName
        addressLabel.text = device.address
    }
    
    @objc private func addTapped() {
        onAddTapped?()
    }
}
