//
//  SCCQRCodeViewController.h
//  SunloginControlSDK
//
//  Created by 潘东 on 2024/1/8.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SCCQRCodeViewController;
/// 扫描二维码回调
@protocol SCCQRCodeDelegate <NSObject>
@optional
/// 扫描到信息
/// - Parameters:
///   - QRCodeViewController: 扫描二维码页
///   - QRCodeStr: 扫描到的信息
- (void)SCCQRCodeViewController:(SCCQRCodeViewController *)QRCodeViewController QRCodeStr:(NSString *)QRCodeStr;
/// 关闭
/// - Parameter QRCodeViewController: 扫描二维码页
- (void)SCCQRCodeCloseViewController:(SCCQRCodeViewController *)QRCodeViewController;
@end

@interface SCCQRCodeViewController : UIViewController
/// 代理回调
@property (assign, nonatomic) id<SCCQRCodeDelegate> delegate;
/// 获取二维码自动暂停后，可调用此方法恢复扫描
- (void)continueScan;
@end

NS_ASSUME_NONNULL_END
