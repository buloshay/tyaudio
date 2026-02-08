//
//  UIColor+Extensions.swift
//  TYAudio
//
//  颜色扩展
//

import UIKit

extension UIColor {
    
    // MARK: - 主题色
    
    /// 主色调 - 深蓝
    static let primary = UIColor(hex: "#1E3A5F")
    
    /// 强调色 - 金色
    static let accent = UIColor(hex: "#D4AF37")
    
    /// 背景色
    static let background = UIColor(hex: "#0D1B2A")
    
    /// 次要背景
    static let secondaryBackground = UIColor(hex: "#1B2838")
    
    /// 卡片背景
    static let cardBackground = UIColor(hex: "#243447")
    
    /// 文字主色
    static let textPrimary = UIColor.white
    
    /// 文字次要色
    static let textSecondary = UIColor(hex: "#8899A6")
    
    /// 分割线
    static let separator = UIColor(hex: "#2C3E50")
    
    /// 播放中状态色
    static let playing = UIColor(hex: "#1DB954")
    
    // MARK: - Hex Initializer
    
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
