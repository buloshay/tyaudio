//
//  SCCDesktopController.h
//  SunloginControlSDK
//
//  Created by 潘东 on 2024/1/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 桌面模式类型（操作模式）
typedef NS_ENUM(NSInteger, SCCDesktopOperationMode) {
    /// 触摸模式
    SCCDesktopOperationModeTouch    = 0,
    /// 指针模式
    SCCDesktopOperationModeCursor
};

/// 桌面模式类型（传输模式）
typedef NS_ENUM(NSInteger, SCCDesktopTransferMode) {
    /// 均衡模式（画质与带宽占用均衡）
    SCCDesktopTransferModeNormal    = 0,
    /// 娱乐模式（更高的帧率、画面质量和带宽占用）
    SCCDesktopTransferModeEntertain,
    /// 极速模式（黑白画面，最低带宽占用）
    SCCDesktopTransferModeTopSpeed
};

/// 远程桌面页状态回调
@protocol SCCDesktopControllerDelegate <NSObject>
/// 远程桌面断开
/// - Parameter isActive: 是否主动断开
- (void)SCCDesktopDisconnect:(BOOL)isActive;
/// 远程桌面已显示
- (void)SCCDesktopDidAppear;
/// 远程桌面已消失
- (void)SCCDesktopDidDisappear;
@end

#pragma mark - ----- 桌面控制器 -----
/// 桌面控制器
@interface SCCDesktopController : NSObject
/// 获取远程桌面 ViewController
- (__kindof UIViewController *)getDesktopViewController;
/// 设置代理
/// - Parameter delegate: 代理对象
- (void)setDesktopDelegate:(id<SCCDesktopControllerDelegate>)delegate;

#pragma mark - 基础控制
/// 关闭远程桌面
- (void)closeDesktop;
/// 暂停接收数据，建议在app进入后台后调用
- (void)pauseReceiveDate;
/// 恢复数据传输，建议在app恢复前台后调用
- (void)resumeReceiveDate;

#pragma mark - 功能控制
/// 当前桌面模式
- (SCCDesktopTransferMode)currentTransferMode;
/// 切换桌面模式
/// - Parameter transferMode: 桌面模式
- (void)switchTransferMode:(SCCDesktopTransferMode)transferMode;

/// 当前操作模式
- (SCCDesktopOperationMode)currentOperationMode;
/// 切换操作模式
/// - Parameter operationMode: 操作模式
- (void)switchOperationMode:(SCCDesktopOperationMode)operationMode;

/// 当前是否显示虚拟鼠标（仅PC触摸模式提供）
- (BOOL)isShowVirtualMouse;
/// 切换是否显示虚拟鼠标（仅PC触摸模式有效）
/// - Parameter isShowVirtualMouse: 虚拟鼠标显示
- (void)switchIsShowVirtualMouse:(BOOL)isShowVirtualMouse;

/// 切换是否显示键盘
/// - Parameter isShow: 键盘显示
- (void)switchIsShowKeyboard:(BOOL)isShow;

/// 当前声音开关状态
- (BOOL)currentIsSoundOn;
/// 切换声音开关，需配置sound session，首次开启声音时间可能会较长，建议增加UI提示
/// - Parameters:
///   - isOn: 打开或关闭声音
///   - complete: 完成操作后回调
- (void)switchSound:(BOOL)isOn complete:(void(^)(BOOL isSucceed, BOOL isSoundOn))complete;

/// 截图
/// - Parameter complete: 完成操作后回调
- (void)getScreenshotComplete:(void(^)(UIImage *screenshot))complete;

/// 开始录制，调用 recordScreenEnd 结束，占用内存过大时，可能会自动中断
/// - Parameters:
///   - filePath: 录制文件路径
///   - complete: 完成操作后回调
- (void)recordScreenToFilePath:(NSString *)filePath complete:(void(^)(BOOL isSucceed, NSString *_Nullable filePath))complete;
/// 结束录制
- (void)recordScreenEnd;

/// 切换屏幕
/// - Parameter complete: 完成操作后回调
- (void)switchScreenComplete:(void(^)(void))complete;

/// 切换用户
- (void)switchConsoleUser;

/// 切换电脑锁屏状态
/// - Parameter isLock: 锁屏或解锁
- (void)switchDestopLock:(BOOL)isLock;

/// 关机
- (void)shutdown;
/// 重启
- (void)reboot;

/// 显示操作指南
- (void)showGuideView;

#pragma mark Android 相关
/// Android 下拉
- (void)androidDropDown;
/// Android 上拉
- (void)androidPullUp;

/// Android 点击返回键
- (void)androidClickBack;
/// Android 点击home键
- (void)androidClickHome;
/// Android 点击菜单键
- (void)androidClickMenu;

/// Android 音量+
- (void)androidVoiceUp;
/// Android 音量-
- (void)androidVoiceDown;

/// Android 屏幕锁屏
- (void)androidScreenLock;

/// Android 切换横屏
- (void)androidLandscape;
/// Android 切换竖屏
- (void)androidVertical;

#pragma mark - 鼠标控制
/// 鼠标左键按下，坐标位于远程桌面ViewController.view
/// - Parameter point: 鼠标坐标
- (void)mouseLeftDownAtPoint:(CGPoint)point;
/// 鼠标左键抬起，坐标位于远程桌面ViewController.view
/// - Parameter point: 鼠标坐标
- (void)mouseLeftUpAtPoint:(CGPoint)point;

/// 鼠标右键按下，坐标位于远程桌面ViewController.view
/// - Parameter point: 鼠标坐标
- (void)mouseRightDownAtPoint:(CGPoint)point;
/// 鼠标右键抬起，坐标位于远程桌面ViewController.view
/// - Parameter point: 鼠标坐标
- (void)mouseRightUpAtPoint:(CGPoint)point;

/// 鼠标中键按下，坐标位于远程桌面ViewController.view
/// - Parameter point: 鼠标坐标
- (void)mouseMidDownAtPoint:(CGPoint)point;
// 鼠标中键抬起，坐标位于远程桌面ViewController.view
/// - Parameter point: 鼠标坐标
- (void)mouseMidUpAtPoint:(CGPoint)point;

/// 鼠标移动到位置，坐标位于远程桌面ViewController.view
/// - Parameter point: 鼠标坐标
- (void)mouseMoveToPoint:(CGPoint)point;

/// 鼠标滚轮准备，坐标位于远程桌面ViewController.view
/// - Parameter point: 鼠标坐标
- (void)mouseWheelStartAtPoint:(CGPoint)point;

/// 鼠标滚轮滚动，坐标位于远程桌面ViewController.view
/// - Parameters:
///   - point: 鼠标坐标
///   - angle: 单次滚动角度 例如向下90度则传入90，向上90度则传入-90
///   - isHorizon: 横向或纵向滚动
- (void)mouseWheelAtPoint:(CGPoint)point angle:(CGFloat)angle isHorizon:(BOOL)isHorizon;

#pragma mark - 键盘控制
/// 键盘按下，按键值详见 SCCDesktopConfig
/// - Parameter keyName: 按键值
- (void)keyboardDownWithKey:(NSString *)keyName;
/// 键盘抬起，按键值详见 SCCDesktopConfig
/// - Parameter keyName: 按键值
- (void)keyboardUpWithKey:(NSString *)keyName;

/// 直接发送字符串
/// - Parameter string: 发送字符串
- (void)sendMessageString:(NSString *)string;
@end

NS_ASSUME_NONNULL_END
