//
//  WaveformView.swift
//  TYAudio
//
//  Shared Waveform View Component
//
//

import UIKit

class WaveformView: UIView {
    
    // MARK: - Properties
    
    private let barCount = 4
    private var bars: [UIView] = []
    private var isAnimating = false
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Remove stack view approach, use manual layout relative to bounds
        for _ in 0..<barCount {
            let bar = UIView()
            bar.backgroundColor = .systemBlue // Use systemBlue as requested/standard
            bar.layer.cornerRadius = 1
            
            // Set anchor point to bottom center so scaling happens from bottom
            bar.layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            
            addSubview(bar)
            bars.append(bar)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let width = bounds.width
        let height = bounds.height
        
        // Calculate bar width and spacing
        let spacing: CGFloat = 2.0
        let totalSpacing = spacing * CGFloat(barCount - 1)
        let barWidth = (width - totalSpacing) / CGFloat(barCount)
        
        for (index, bar) in bars.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            
            // Position using center-bottom anchor reasoning
            // Since anchorPoint is (0.5, 1.0), position should be (center_x, bottom_y)
            let centerX = x + barWidth / 2
            let bottomY = height
            
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: height)
            bar.layer.position = CGPoint(x: centerX, y: bottomY)
        }
    }
    
    // MARK: - Animation
    
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        isHidden = false
        
        // Randomize initial delays for a more organic look
        let durations: [CFTimeInterval] = [0.6, 0.7, 0.5, 0.8]
        let beginTimes: [CFTimeInterval] = [0.0, 0.3, 0.1, 0.4]
        
        for (index, bar) in bars.enumerated() {
            // Scale Y animation
            let animation = CAKeyframeAnimation(keyPath: "transform.scale.y")
            animation.values = [0.1, 0.6, 1.0, 0.4, 0.1]
            animation.keyTimes = [0.0, 0.2, 0.5, 0.8, 1.0]
            
            // Varied duration for each bar
            animation.duration = durations[index % durations.count]
            
            animation.repeatCount = .infinity
            animation.autoreverses = true
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            // Stagger start times
            animation.beginTime = CACurrentMediaTime() + beginTimes[index % beginTimes.count]
            
            bar.layer.add(animation, forKey: "waveformRaw")
        }
    }
    
    func stopAnimating() {
        isAnimating = false
        isHidden = true
        for bar in bars {
            bar.layer.removeAllAnimations()
        }
    }
}
