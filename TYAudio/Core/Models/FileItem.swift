//
//  FileItem.swift
//  TYAudio
//
//  文件/歌曲数据模型
//

import Foundation

/// 文件类型
enum FileType: Int {
    case directory = 0
    case song = 1
}

/// 文件项目模型
struct FileItem: Identifiable, Equatable {
    let id = UUID()
    let type: FileType
    let name: String
    let path: String
    
    /// 是否是目录
    var isDirectory: Bool {
        return type == .directory
    }
    
    /// 是否是歌曲
    var isSong: Bool {
        return type == .song
    }
    
    /// 从JSON解析
    static func from(json: [String: Any]) -> FileItem? {
        guard let typeValue = json["type"] as? Int,
              let type = FileType(rawValue: typeValue),
              let name = json["name"] as? String,
              let path = json["path"] as? String else {
            return nil
        }
        
        return FileItem(type: type, name: name, path: path)
    }
    
    /// 从JSON数组解析
    static func fromArray(jsonArray: [[String: Any]]) -> [FileItem] {
        return jsonArray.compactMap { from(json: $0) }
    }
}

/// 分类项目模型（专辑、歌手、风格）
struct CategoryItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let type: CategoryType
    let itemCount: Int
    let path: String
    
    /// 过滤 ~!@#$% 分隔符后的显示名称
    var displayName: String {
        let separator = "~!@#$%"
        guard let range = name.range(of: separator) else { return name }
        return String(name[..<range.lowerBound])
    }
    
    /// 从JSON解析
    static func from(json: [String: Any], type: CategoryType) -> CategoryItem? {
        guard let name = json["name"] as? String else {
            return nil
        }
        
        let count = json["count"] as? Int ?? 0
        let path = json["path"] as? String ?? ""
        return CategoryItem(name: name, type: type, itemCount: count, path: path)
    }
}

/// 应用项目模型
struct AppItem: Identifiable, Equatable {
    let id = UUID()
    let packageName: String
    let title: String
    
    /// 从JSON解析
    static func from(json: [String: Any]) -> AppItem? {
        guard let packageName = json["packageName"] as? String,
              let title = json["title"] as? String else {
            return nil
        }
        
        return AppItem(packageName: packageName, title: title)
    }
    
    /// 从JSON数组解析
    static func fromArray(jsonArray: [[String: Any]]) -> [AppItem] {
        return jsonArray.compactMap { from(json: $0) }
    }
}
