//
//  CommandBuilder.swift
//  TYAudio
//
//  指令构建器，封装所有TY-i60协议指令
//

import Foundation

/// 播放模式
enum PlayMode: Int {
    case sequence = 0    // 顺序播放
    case single = 1      // 单曲循环
    case shuffle = 2     // 随机播放
    case loop = 3        // 列表循环
}

/// 分类类型
enum CategoryType: String {
    case music = "music"
    case album = "album"
    case artist = "artist"
    case style = "style"
}

/// 流媒体类型
enum StreamingType: String {
    case tidal = "tidal"
    case qobuz = "qobuz"
    case deezer = "deezer"
    case highresaudio = "highresaudio"
}

/// 指令构建器
struct CommandBuilder {
    
    // MARK: - 文件操作
    
    /// 切换目录
    static func changePath(dir: String) -> [String: Any] {
        return [
            "command": "change_path",
            "dir": dir
        ]
    }
    
    /// 获取文件列表
    static func playlist(nameOnly: Bool = false, current: Bool = false) -> [String: Any] {
        return [
            "command": "playlist",
            "name_only": nameOnly,
            "current": current
        ]
    }
    
    // MARK: - 应用控制
    
    /// 获取应用列表
    static func appList() -> [String: Any] {
        return [
            "command": "app",
            "action": "list",
            "package": ""
        ]
    }
    
    /// 启动应用
    static func launchApp(package: String) -> [String: Any] {
        return [
            "command": "app",
            "action": "start",
            "package": package
        ]
    }
    
    // MARK: - 分类模块
    
    /// 获取分类列表（单曲、专辑、歌手、风格）
    static func category(type: CategoryType, name: String = "", count: Int = -1, updateList: Bool = true) -> [String: Any] {
        return [
            "command": "category",
            "type": type.rawValue,
            "name": name,
            "name_only": false,
            "update_list": updateList,
            "count": count,
            "check_exist": true
        ]
    }
    
    // MARK: - 收藏模块
    
    /// 切换到收藏目录
    static func switchToFavorites() -> [String: Any] {
        return changePath(dir: "/")
    }
    
    /// 获取收藏列表
    static func getFavorites() -> [String: Any] {
        return playlist(nameOnly: false, current: false)
    }
    
    // MARK: - 播放控制
    
    /// 上一首
    static func previous() -> [String: Any] {
        return ["command": "prev"]
    }
    
    /// 下一首
    static func next() -> [String: Any] {
        return ["command": "next"]
    }
    
    /// 播放/暂停当前歌曲
    static func playPause() -> [String: Any] {
        return [
            "command": "play",
            "current": true,
            "index": -1
        ]
    }
    
    /// 播放指定位置的歌曲
    static func playAt(index: Int) -> [String: Any] {
        return [
            "command": "play",
            "current": true,
            "index": index
        ]
    }
    
    /// 设置播放模式
    static func setPlayMode(_ mode: PlayMode) -> [String: Any] {
        return [
            "command": "play_mode",
            "value": mode.rawValue
        ]
    }
    
    /// 跳转进度
    static func seek(position: Int) -> [String: Any] {
        return [
            "command": "seek",
            "position": position
        ]
    }
    
    /// 获取当前播放状态
    static func getPlayState() -> [String: Any] {
        return ["command": "play_state"]
    }
    
    /// 获取当前播放列表
    static func getCurrentPlaylist() -> [String: Any] {
        return playlist(nameOnly: false, current: true)
    }
    
    // MARK: - 流媒体
    
    /// 启动流媒体应用
    static func launchStreaming(_ type: StreamingType) -> [String: Any] {
        return launchApp(package: type.rawValue)
    }
    
    /// 获取屏幕镜像会话信息
    /// - Returns: 屏幕镜像会话请求指令
    /// - Note: 返回包含 address, session, sound_session 的响应
    static func getScreenMirrorSession() -> [String: Any] {
        return ["command": "screen_mirror_session"]
    }
    
    // MARK: - 设备属性
    
    /// 获取设备属性（用于扫描验证）
    static func getProperty(name: String = "ro.product.model") -> [String: Any] {
        return [
            "command": "property",
            "name": name
        ]
    }
    
    // MARK: - 其他
    
    /// Pong响应
    static func pong() -> [String: Any] {
        return ["command": "pong"]
    }
    
    /// NAS应用
    static func launchNAS() -> [String: Any] {
        return launchApp(package: "nas")
    }
    
    /// 设置应用
    static func launchSettings() -> [String: Any] {
        return launchApp(package: "setting")
    }
    
    // MARK: - 远程控制
    
    /// 发送按键事件
    /// - Parameter key: 按键类型 (home/back)
    static func sendKey(_ key: String) -> [String: Any] {
        return [
            "command": "key",
            "key": key
        ]
    }
    
    /// 发送主页键
    static func sendHomeKey() -> [String: Any] {
        return sendKey("home")
    }
    
    /// 发送返回键
    static func sendBackKey() -> [String: Any] {
        return sendKey("back")
    }
}
