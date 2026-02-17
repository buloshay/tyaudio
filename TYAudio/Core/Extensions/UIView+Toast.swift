//
//  UIView+Toast.swift
//  TYAudio
//
//  Created by Gemini on 2026/02/17.
//

import UIKit

extension UIView {
    func showToast(message: String, duration: TimeInterval = 2.0) {
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14)
        toastLabel.textAlignment = .center
        toastLabel.text = message
        toastLabel.alpha = 0.0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        
        // Calculate size based on text
        let maxSize = CGSize(width: self.bounds.width - 40, height: self.bounds.height)
        var expectedSize = toastLabel.sizeThatFits(maxSize)
        expectedSize.width += 20 // Padding
        expectedSize.height += 10 // Padding
        
        toastLabel.frame = CGRect(x: (self.bounds.width - expectedSize.width) / 2,
                                  y: self.bounds.height - 100,
                                  width: expectedSize.width,
                                  height: expectedSize.height)
        
        self.addSubview(toastLabel)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            toastLabel.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: .curveEaseIn, animations: {
                toastLabel.alpha = 0.0
            }, completion: { _ in
                toastLabel.removeFromSuperview()
            })
        })
    }
}
