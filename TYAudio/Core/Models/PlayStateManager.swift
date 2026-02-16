//
//  PlayStateManager.swift
//  TYAudio
//
//  播放状态全局单例管理器
//

import Foundation

/// 播放状态全局单例，跨页面共享当前播放信息
class PlayStateManager {
    
    static let shared = PlayStateManager()
    
    /// 播放状态更新通知
    static let didUpdateNotification = Notification.Name("PlayStateManagerDidUpdate")
    
    /// 当前播放状态
    private(set) var currentState: PlayState?
    
    private init() {}
    
    /// 从 TCP play_state 消息更新状态并广播通知
    func update(from json: [String: Any]) {
        currentState = PlayState.from(json: json)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
    }
    
    /// 乐观更新（用户点击播放时立即更新，无需等待 TCP 回调）
    func updateOptimistically(index: Int, title: String, filePath: String) {
        if currentState == nil {
            currentState = PlayState()
        }
        currentState?.currentIndex = index
        currentState?.status = 1
        currentState?.title = title
        currentState?.filePath = filePath
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
    }
    
    /// 判断给定目录路径是否包含当前播放的内容（基于 album 字段中的目录路径）
    /// 例如：albumPath = "/storage/.../Volume2"
    /// itemPath = "/storage/emulated/0/Music"  → true（父目录）
    /// itemPath = "/storage/.../Volume2"       → true（精确匹配）
    func isPathPlaying(_ itemPath: String) -> Bool {
        guard let albumPath = currentState?.albumPath,
              currentState?.isPlaying == true,
              !albumPath.isEmpty,
              !itemPath.isEmpty else { return false }
        
        // 精确匹配（当前播放目录）
        if albumPath == itemPath { return true }
        
        // 目录前缀匹配：itemPath 是 albumPath 的父目录
        let dirPath = itemPath.hasSuffix("/") ? itemPath : itemPath + "/"
        return albumPath.hasPrefix(dirPath)
    }
    
    /// 判断给定歌曲是否为当前播放的歌曲（标题匹配 或 file_path 精确匹配）
    func isSongPlaying(title: String, filePath: String? = nil) -> Bool {
        guard let state = currentState,
              state.isPlaying else { return false }
        
        // 标题匹配
        if !title.isEmpty && state.title == title { return true }
        
        // file_path 精确匹配（ISO 等文件名与标题不一致时的兜底）
        if let path = filePath, !path.isEmpty, !state.filePath.isEmpty {
            return state.filePath == path
        }
        
        return false
    }
    
    /// 判断分类项（专辑/歌手/风格）是否包含当前播放的内容
    func isCategoryPlaying(name: String, categoryType: CategoryType) -> Bool {
        guard let state = currentState,
              state.isPlaying,
              !name.isEmpty else { return false }
        
        switch categoryType {
        case .album:
            // 专辑 name 格式与 play_state.album 一致："专辑名~!@#$%目录路径"
            return state.album == name
        case .artist:
            // 歌手名与 play_state.artist 匹配
            return state.artist == name
        case .style, .music:
            return false
        }
    }
}
