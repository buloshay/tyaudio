//
//  PlayState.swift
//  TYAudio
//
//  播放状态数据模型
//

import Foundation

/// 播放状态
struct PlayState {
    var status: Int = 0          // 1=播放，其他=暂停
    var playMode: PlayMode = .sequence
    var isFavorite: Bool = false
    var progress: Int = 0        // 当前进度（秒）
    var duration: Int = 0        // 总时长（秒）
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var cover: String?           // 流媒体封面URL
    var filePath: String = ""
    var currentIndex: Int = 0
    var fileCount: Int = 0
    
    /// 是否正在播放
    var isPlaying: Bool {
        return status == 1
    }
    
    /// 格式化的当前时间
    var formattedProgress: String {
        return formatTime(progress)
    }
    
    /// 格式化的总时长
    var formattedDuration: String {
        return formatTime(duration)
    }
    
    /// 播放进度百分比
    var progressPercent: Float {
        guard duration > 0 else { return 0 }
        return Float(progress) / Float(duration)
    }
    
    /// 获取封面URL
    func getCoverURL(ipAddress: String, port: Int = 9012) -> URL? {
        if let coverURL = cover, !coverURL.isEmpty {
            return URL(string: coverURL)
        }
        
        guard !filePath.isEmpty else { return nil }
        
        var components = URLComponents()
        components.scheme = "http"
        components.host = ipAddress
        components.port = port
        components.path = "/cover"
        components.queryItems = [
            URLQueryItem(name: "path", value: filePath),
            URLQueryItem(name: "default", value: "t_img_album.png")
        ]
        
        return components.url
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    /// 从JSON解析播放状态
    static func from(json: [String: Any]) -> PlayState {
        var state = PlayState()
        
        state.status = json["status"] as? Int ?? 0
        state.progress = json["progress"] as? Int ?? 0
        state.duration = json["duration"] as? Int ?? 0
        state.title = json["title"] as? String ?? ""
        state.artist = json["artist"] as? String ?? ""
        state.album = json["album"] as? String ?? ""
        state.cover = json["cover"] as? String
        state.filePath = json["file_path"] as? String ?? ""
        state.currentIndex = json["current_index"] as? Int ?? 0
        state.fileCount = json["file_count"] as? Int ?? 0
        state.isFavorite = (json["fav"] as? Int ?? 0) == 1
        
        if let modeValue = json["play_mode"] as? Int,
           let mode = PlayMode(rawValue: modeValue) {
            state.playMode = mode
        }
        
        return state
    }
}
