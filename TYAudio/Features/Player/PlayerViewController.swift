//
//  PlayerViewController.swift
//  TYAudio
//
//  完整播放页面
//

import UIKit

class PlayerViewController: BaseViewController {
    
    // MARK: - UI Components
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        button.tintColor = .textPrimary
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var playlistButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "list.bullet"), for: .normal)
        button.tintColor = .textPrimary
        button.addTarget(self, action: #selector(playlistTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var coverContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.setCornerRadius(20)
        view.addShadow(color: .black, opacity: 0.3, offset: CGSize(width: 0, height: 10), radius: 20)
        return view
    }()
    
    private lazy var coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = .accent
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .secondaryBackground
        imageView.setCornerRadius(16)
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    private lazy var artistLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .textSecondary
        label.textAlignment = .center
        return label
    }()
    
    private lazy var albumLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .textSecondary.withAlphaComponent(0.7)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var progressSlider: UISlider = {
        let slider = UISlider()
        slider.minimumTrackTintColor = .accent
        slider.maximumTrackTintColor = .separator
        slider.thumbTintColor = .accent
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside])
        return slider
    }()
    
    private lazy var currentTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .textSecondary
        return label
    }()
    
    private lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .textSecondary
        label.textAlignment = .right
        return label
    }()
    
    private lazy var playModeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "repeat"), for: .normal)
        button.tintColor = .textSecondary
        button.addTarget(self, action: #selector(playModeTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var previousButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "backward.fill"), for: .normal)
        button.tintColor = .textPrimary
        button.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        button.tintColor = .accent
        button.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        button.tintColor = .textPrimary
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var favoriteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "heart"), for: .normal)
        button.tintColor = .textSecondary
        button.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    
    private var playState: PlayState
    private var ipAddress: String
    private var isDraggingSlider = false
    private var progressTimer: Timer?
    
    // MARK: - Initialization
    
    init(playState: PlayState, ipAddress: String) {
        self.playState = playState
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
        updateUI()
        startProgressTimer()
        TCPSocketManager.shared.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopProgressTimer()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .background
        
        // Header
        view.addSubviewWithAutoLayout(closeButton)
        view.addSubviewWithAutoLayout(playlistButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            playlistButton.topAnchor.constraint(equalTo: closeButton.topAnchor),
            playlistButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            playlistButton.widthAnchor.constraint(equalToConstant: 44),
            playlistButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Cover
        view.addSubviewWithAutoLayout(coverContainerView)
        coverContainerView.addSubviewWithAutoLayout(coverImageView)
        
        let coverSize: CGFloat = UIScreen.main.bounds.width - 80
        NSLayoutConstraint.activate([
            coverContainerView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 30),
            coverContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coverContainerView.widthAnchor.constraint(equalToConstant: coverSize),
            coverContainerView.heightAnchor.constraint(equalToConstant: coverSize),
            
            coverImageView.topAnchor.constraint(equalTo: coverContainerView.topAnchor, constant: 8),
            coverImageView.leadingAnchor.constraint(equalTo: coverContainerView.leadingAnchor, constant: 8),
            coverImageView.trailingAnchor.constraint(equalTo: coverContainerView.trailingAnchor, constant: -8),
            coverImageView.bottomAnchor.constraint(equalTo: coverContainerView.bottomAnchor, constant: -8)
        ])
        
        // Song Info
        view.addSubviewWithAutoLayout(titleLabel)
        view.addSubviewWithAutoLayout(artistLabel)
        view.addSubviewWithAutoLayout(albumLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: coverContainerView.bottomAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            albumLabel.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 4),
            albumLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            albumLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
        
        // Progress
        view.addSubviewWithAutoLayout(progressSlider)
        view.addSubviewWithAutoLayout(currentTimeLabel)
        view.addSubviewWithAutoLayout(durationLabel)
        
        NSLayoutConstraint.activate([
            progressSlider.topAnchor.constraint(equalTo: albumLabel.bottomAnchor, constant: 30),
            progressSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            progressSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            currentTimeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 8),
            currentTimeLabel.leadingAnchor.constraint(equalTo: progressSlider.leadingAnchor),
            
            durationLabel.topAnchor.constraint(equalTo: currentTimeLabel.topAnchor),
            durationLabel.trailingAnchor.constraint(equalTo: progressSlider.trailingAnchor)
        ])
        
        // Controls
        let controlsStack = UIStackView(arrangedSubviews: [playModeButton, previousButton, playButton, nextButton, favoriteButton], axis: .horizontal, spacing: 0, alignment: .center, distribution: .equalSpacing)
        view.addSubviewWithAutoLayout(controlsStack)
        
        NSLayoutConstraint.activate([
            controlsStack.topAnchor.constraint(equalTo: currentTimeLabel.bottomAnchor, constant: 30),
            controlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            controlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
        
        // Set button sizes
        playModeButton.setSize(width: 32, height: 32)
        previousButton.setSize(width: 44, height: 44)
        playButton.setSize(width: 70, height: 70)
        nextButton.setSize(width: 44, height: 44)
        favoriteButton.setSize(width: 32, height: 32)
        
        // Scale images
        playButton.imageView?.contentMode = .scaleAspectFit
        playButton.contentVerticalAlignment = .fill
        playButton.contentHorizontalAlignment = .fill
    }
    
    private func updateUI() {
        titleLabel.text = playState.title.isEmpty ? "未知歌曲" : playState.title
        artistLabel.text = playState.artist.isEmpty ? "未知艺术家" : playState.artist
        albumLabel.text = playState.album.isEmpty ? "" : playState.album
        
        currentTimeLabel.text = playState.formattedProgress
        durationLabel.text = playState.formattedDuration
        
        if !isDraggingSlider {
            progressSlider.value = playState.progressPercent
        }
        
        let playIcon = playState.isPlaying ? "pause.circle.fill" : "play.circle.fill"
        playButton.setImage(UIImage(systemName: playIcon), for: .normal)
        
        updatePlayModeButton()
        
        let heartIcon = playState.isFavorite ? "heart.fill" : "heart"
        favoriteButton.setImage(UIImage(systemName: heartIcon), for: .normal)
        favoriteButton.tintColor = playState.isFavorite ? .systemRed : .textSecondary
        
        // Load cover
        if let url = playState.getCoverURL(ipAddress: ipAddress) {
            loadCoverImage(from: url)
        }
    }
    
    private func updatePlayModeButton() {
        let icon: String
        switch playState.playMode {
        case .sequence:
            icon = "arrow.right"
        case .single:
            icon = "repeat.1"
        case .shuffle:
            icon = "shuffle"
        case .loop:
            icon = "repeat"
        }
        playModeButton.setImage(UIImage(systemName: icon), for: .normal)
        playModeButton.tintColor = playState.playMode == .sequence ? .textSecondary : .accent
    }
    
    private func loadCoverImage(from url: URL) {
        print("[PlayerViewController] Loading cover from: \(url.absoluteString)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("[PlayerViewController] Load cover failed: \(error.localizedDescription)")
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                print("[PlayerViewController] Load cover success")
                DispatchQueue.main.async {
                    self?.coverImageView.image = image
                }
            } else {
                 print("[PlayerViewController] Load cover failed: Invalid data or image")
            }
        }.resume()
    }
    
    // MARK: - Progress Timer
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.playState.isPlaying, !self.isDraggingSlider else { return }
            self.playState.progress += 1
            if self.playState.progress > self.playState.duration {
                self.playState.progress = self.playState.duration
            }
            self.currentTimeLabel.text = self.playState.formattedProgress
            self.progressSlider.value = self.playState.progressPercent
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        print("[User Action] PlayerViewController - closeTapped")
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func playlistTapped() {
        print("[User Action] PlayerViewController - playlistTapped")
        let playlistVC = PlaylistViewController()
        playlistVC.modalPresentationStyle = .pageSheet
        if let sheet = playlistVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(playlistVC, animated: true, completion: nil)
    }
    
    @objc private func sliderValueChanged() {
        isDraggingSlider = true
        let time = Int(progressSlider.value * Float(playState.duration))
        currentTimeLabel.text = formatTime(time)
    }
    
    @objc private func sliderTouchUp() {
        print("[User Action] PlayerViewController - sliderTouchUp: \(progressSlider.value)")
        stopProgressTimer() // Stop timer while seeking
        let position = Int(progressSlider.value * Float(playState.duration))
        TCPSocketManager.shared.send(command: CommandBuilder.seek(position: position))
        playState.progress = position
        isDraggingSlider = false
        startProgressTimer() // Restart timer after seek
    }
    
    @objc private func playModeTapped() {
        print("[User Action] PlayerViewController - playModeTapped")
        var newMode = playState.playMode.rawValue + 1
        if newMode > 3 { newMode = 0 }
        playState.playMode = PlayMode(rawValue: newMode) ?? .sequence
        updatePlayModeButton()
        TCPSocketManager.shared.send(command: CommandBuilder.setPlayMode(playState.playMode))
    }
    
    @objc private func previousTapped() {
        print("[User Action] PlayerViewController - previousTapped")
        TCPSocketManager.shared.send(command: CommandBuilder.previous())
    }
    
    @objc private func playTapped() {
        print("[User Action] PlayerViewController - playTapped")
        TCPSocketManager.shared.send(command: CommandBuilder.playPause())
        playState.status = playState.isPlaying ? 0 : 1
        updateUI()
    }
    
    @objc private func nextTapped() {
        print("[User Action] PlayerViewController - nextTapped")
        TCPSocketManager.shared.send(command: CommandBuilder.next())
    }
    
    @objc private func favoriteTapped() {
        print("[User Action] PlayerViewController - favoriteTapped")
        // TODO: Toggle favorite
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - TCPSocketManagerDelegate

extension PlayerViewController: TCPSocketManagerDelegate {
    
    func tcpSocketManager(_ manager: TCPSocketManager, didChangeState state: TCPConnectionState) {}
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveData data: [String: Any], command: String) {
        if command == "play_state" {
            playState = PlayState.from(json: data)
            updateUI()
        }
    }
    
    func tcpSocketManager(_ manager: TCPSocketManager, didReceiveError error: Error) {}
}
