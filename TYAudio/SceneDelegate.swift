//
//  SceneDelegate.swift
//  TYAudio
//
//  Created by tang on 2026/2/8.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    // MARK: - Background Keep-Alive
    
    /// 后台任务标识
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        let deviceListVC = DeviceListViewController()
        let navigationController = UINavigationController(rootViewController: deviceListVC)
        navigationController.setNavigationBarHidden(true, animated: false)
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        
        // 结束后台保活任务
        endBackgroundKeepAlive()
        
        // App 回到前台，检测 TCP 连接状态并自动重连
        TCPSocketManager.shared.handleAppDidBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        
        // 申请后台执行时间，保持 TCP 连接存活
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: "TCPKeepAlive"
        ) { [weak self] in
            // 超时回调：系统即将终止后台任务
            self?.endBackgroundKeepAlive()
        }
        print("[App] Background task started, ID: \(backgroundTaskID)")
    }

    private func endBackgroundKeepAlive() {
        guard backgroundTaskID != .invalid else { return }
        print("[App] Ending background task")
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

}

