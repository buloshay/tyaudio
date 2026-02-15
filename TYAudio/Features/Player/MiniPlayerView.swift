//
//  MiniPlayerView.swift
//  TYAudio
//
//  底部迷你播放器
//

import UIKit

protocol MiniPlayerViewDelegate: AnyObject {
    func miniPlayerViewDidTapPlay(_ view: MiniPlayerView)
    func miniPlayerViewDidTapNext(_ view: MiniPlayerView)
    func miniPlayerViewDidTap(_ view: MiniPlayerView)
}

class MiniPlayerView: UIView {
    
    // MARK: - UI Components
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        return view
    }()
    
    private lazy var coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = .accent
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .secondaryBackground
        imageView.setCornerRadius(6)
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "未在播放"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .textPrimary
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private lazy var artistLabel: UILabel = {
        let label = UILabel()
        label.text = "-"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .textSecondary
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private lazy var playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.tintColor = .textPrimary
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
    
    private lazy var progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .accent
        progress.trackTintColor = .separator
        progress.progress = 0
        return progress
    }()
    
    // MARK: - Properties
    
    weak var delegate: MiniPlayerViewDelegate?
    private var isPlaying = false
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .clear
        
        addSubviewWithAutoLayout(containerView)
        containerView.addSubviewWithAutoLayout(progressView)
        containerView.addSubviewWithAutoLayout(coverImageView)
        containerView.addSubviewWithAutoLayout(titleLabel)
        containerView.addSubviewWithAutoLayout(artistLabel)
        containerView.addSubviewWithAutoLayout(playButton)
        containerView.addSubviewWithAutoLayout(nextButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            progressView.topAnchor.constraint(equalTo: containerView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            coverImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            coverImageView.widthAnchor.constraint(equalToConstant: 48),
            coverImageView.heightAnchor.constraint(equalToConstant: 48),
            
            titleLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: coverImageView.topAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -12),
            
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            nextButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            nextButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.heightAnchor.constraint(equalToConstant: 44),
            
            playButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -8),
            playButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        containerView.addGestureRecognizer(tap)
    }
    
    // MARK: - Public Methods
    
    func update(with state: PlayState, ipAddress: String) {
        titleLabel.text = state.title.isEmpty ? "未在播放" : state.title
        artistLabel.text = state.artist.isEmpty ? "-" : state.artist
        isPlaying = state.isPlaying
        
        let playIcon = state.isPlaying ? "pause.fill" : "play.fill"
        playButton.setImage(UIImage(systemName: playIcon), for: .normal)
        
        progressView.progress = state.progressPercent
        
        // Load cover image
        if let url = state.getCoverURL(ipAddress: ipAddress) {
            loadCoverImage(from: url)
        } else {
            coverImageView.image = UIImage(systemName: "music.note")
        }
    }
    
    private func loadCoverImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("[MiniPlayerView] Load cover failed: \(error.localizedDescription)")
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                print("[MiniPlayerView] Load cover success")
                DispatchQueue.main.async {
                    self?.coverImageView.image = image
                }
            } else {
                print("[MiniPlayerView] Load cover failed: Invalid data or image")
            }
        }.resume()
    }
    
    // MARK: - Actions
    
    @objc private func playTapped() {
        delegate?.miniPlayerViewDidTapPlay(self)
    }
    
    @objc private func nextTapped() {
        delegate?.miniPlayerViewDidTapNext(self)
    }
    
    @objc private func viewTapped() {
        delegate?.miniPlayerViewDidTap(self)
    }
}
