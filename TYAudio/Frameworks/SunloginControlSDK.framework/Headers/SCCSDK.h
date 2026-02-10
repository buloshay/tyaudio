//
//  SCCSDK.h
//  controlclient
//
//  Created by 潘东 on 2024/1/3.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SunloginControlSDK/SCCDesktopConfig.h>
#import <SunloginControlSDK/SCCDesktopController.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - ----- 远控系统枚举 -----
/// 远控系统枚举
typedef NS_ENUM(NSUInteger, SCCRemoteSystem) {
    /* 桌面操作系统 */
    /// Windows
    SCCRemoteSystemWindows,
    /// MacOS
    SCCRemoteSystemMacOS,
    /// Linux
    SCCRemoteSystemLinux,
    /* 移动操作系统 */
    /// Android
    SCCRemoteSystemAndroid = 100,
    /// iOS
    SCCRemoteSystemIOS
};

#pragma mark - ----- 连接状态回调 -----
/// 连接状态回调
@protocol SCCSDKConnectStateDelegate <NSObject>
@optional
/// 正在连接
- (void)SCCSDKConnecting;
/// 即将连接成功
- (void)SCCSDKConnectWillSucceed;
/// 连接成功
- (void)SCCSDKConnectSucceed;
/// 连接失败
- (void)SCCSDKConnectFailedWithErrorCode:(NSInteger)errorCode errorMessage:(NSString *)errorMessage;
@end


#pragma mark - ----- SCCSDK -----
@class SCCDesktopController;
@interface SCCSDK : NSObject

/// SDK单例方法
+ (instancetype)sdk;

/// 获取菜单项名称，有些菜单可能有多种状态，由数组全部返回
/// - Parameter key: 菜单项 RPMenu key
+ (NSArray<NSString *> *)getMenuTitleNameWithKey:(NSString *)key;

#pragma mark - 远程插件
/// 连接远程桌面方法，成功后回调 SCCDesktopController 远程桌面控制器
/// - Parameters:
///   - address: 客户端生成的 address
///   - session: 客户端生成的 session
///   - soundSession: 客户端生成的声音 session （可选，如无需连接声音可不传）
///   - system: 客户端系统
///   - desktopConfig: 桌面样式配置
///   - delegate: 状态代理
///   - complete: 连接成功后回调 SCCDesktopController 远程桌面控制器
- (void)connectRemoteDestopWithAddress:(NSString *)address
                               session:(NSString *)session
                          soundSession:(NSString *_Nullable)soundSession
                                system:(SCCRemoteSystem)system
                         desktopConfig:(SCCDesktopConfig *)desktopConfig
                              delegate:(id<SCCSDKConnectStateDelegate>)delegate
                              complete:(void(^)(SCCDesktopController *desktopController))complete;

#pragma mark - 转发通道
/// 连接转发端口
/// - Parameters:
///   - address: 客户端生成的 address
///   - session: 客户端生成的 session
///   - ip: 客户端 ip （可选）
///   - delegate: 状态代理
- (void)connectPortForwardWithAddress:(NSString *)address
                              session:(NSString *)session
                                   ip:(NSString *_Nullable)ip
                             delegate:(id<SCCSDKConnectStateDelegate>)delegate;
/// 断开端口转发
- (void)disconnectPortForward;

/// 创建转发通道
/// - Parameters:
///   - port: 端口
///   - complete: 完成回调
- (void)createChannelWithPort:(NSUInteger)port complete:(void(^)(BOOL isSucceed, NSString *ipAndPort))complete;
/// 销毁一个已创建的转发通道
- (void)deleteChannelWithPort:(NSUInteger)port;

#pragma mark - 数据传输
/// 连接数据传输
/// - Parameters:
///   - address: 客户端生成的 address
///   - session: 客户端生成的 session
///   - ip: 客户端 ip （可选）
///   - delegate: 状态代理
///   - recvDataComplete: 接收到数据回调
- (void)connectDataTransferWithAddress:(NSString *)address
                               session:(NSString *)session
                                    ip:(NSString *)ip
                              delegate:(id<SCCSDKConnectStateDelegate>)delegate
                      recvDataComplete:(void(^)(NSString *recvData))recvDataComplete;
/// 断开数据传输
- (void)disconnectDataTransfer;

/// 发送数据
/// - Parameter data: 发送的信息
- (void)sendData:(NSString *)data;

@end

NS_ASSUME_NONNULL_END
