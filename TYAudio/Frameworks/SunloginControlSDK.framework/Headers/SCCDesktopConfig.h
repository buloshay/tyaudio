//
//  SCCDesktopConfig.h
//  SunloginControlSDK
//
//  Created by 潘东 on 2024/1/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 菜单项
/// 退出
extern NSString *const __RPMenu_Quit;
/// 声音
extern NSString *const __RPMenu_Sound;
/// 切换屏幕
extern NSString *const __RPMenu_SwitchScreen;
/// 录像
extern NSString *const __RPMenu_Video;
/// 截屏
extern NSString *const __RPMenu_ScreenShots;
/// 切换会话
extern NSString *const __RPMenu_ChangeUser;
/// 桌面显示
extern NSString *const __RPMenu_DesktopDisplay;
/// 桌面锁定
extern NSString *const __RPMenu_DesktopLock;
/// 重启
extern NSString *const __RPMenu_Restart;
/// 关机
extern NSString *const __RPMenu_Shutdown;
/// 手势指南
extern NSString *const __RPMenu_GestureGuide;
/* Android */
/// 上拉
extern NSString *const __RPMenu_Android_PullUp;
/// 下拉
extern NSString *const __RPMenu_Android_PullDn;
/// Android home
extern NSString *const __RPMenu_Android_Home;
/// Android back
extern NSString *const __RPMenu_Android_Back;
/// Android menu
extern NSString *const __RPMenu_Android_Menu;
/// 音量+
extern NSString *const __RPMenu_Android_VoiceUp;
/// 音量-
extern NSString *const __RPMenu_Android_VoiceDn;
/// 锁屏
extern NSString *const __RPMenu_Android_Lock;
/// 屏幕横竖屏切换
extern NSString *const __RPMenu_Android_Rotate;

#pragma mark - 键盘key
/* 字母 A-Z */
/// A
extern NSString *const __kb_A;
/// B
extern NSString *const __kb_B;
/// C
extern NSString *const __kb_C;
/// D
extern NSString *const __kb_D;
/// E
extern NSString *const __kb_E;
/// F
extern NSString *const __kb_F;
/// G
extern NSString *const __kb_G;
/// H
extern NSString *const __kb_H;
/// I
extern NSString *const __kb_I;
/// J
extern NSString *const __kb_J;
/// K
extern NSString *const __kb_K;
/// L
extern NSString *const __kb_L;
/// M
extern NSString *const __kb_M;
/// N
extern NSString *const __kb_N;
/// O
extern NSString *const __kb_O;
/// P
extern NSString *const __kb_P;
/// Q
extern NSString *const __kb_Q;
/// R
extern NSString *const __kb_R;
/// S
extern NSString *const __kb_S;
/// T
extern NSString *const __kb_T;
/// U
extern NSString *const __kb_U;
/// V
extern NSString *const __kb_V;
/// W
extern NSString *const __kb_W;
/// X
extern NSString *const __kb_X;
/// Y
extern NSString *const __kb_Y;
/// Z
extern NSString *const __kb_Z;
/* 数字 */
/// 1
extern NSString *const __kb_1;
/// 2
extern NSString *const __kb_2;
/// 3
extern NSString *const __kb_3;
/// 4
extern NSString *const __kb_4;
/// 5
extern NSString *const __kb_5;
/// 6
extern NSString *const __kb_6;
/// 7
extern NSString *const __kb_7;
/// 8
extern NSString *const __kb_8;
/// 9
extern NSString *const __kb_9;
/// 0
extern NSString *const __kb_0;
/* 功能键 F1-F12 */
/// F1
extern NSString *const __kb_F1;
/// F2
extern NSString *const __kb_F2;
/// F3
extern NSString *const __kb_F3;
/// F4
extern NSString *const __kb_F4;
/// F5
extern NSString *const __kb_F5;
/// F6
extern NSString *const __kb_F6;
/// F7
extern NSString *const __kb_F7;
/// F8
extern NSString *const __kb_F8;
/// F9
extern NSString *const __kb_F9;
/// F10
extern NSString *const __kb_F10;
/// F11
extern NSString *const __kb_F11;
/// F12
extern NSString *const __kb_F12;
/* 功能键 上下左右 */
/// 方向键 上
extern NSString *const __kb_Up;
/// 方向键 左
extern NSString *const __kb_Left;
/// 方向键 下
extern NSString *const __kb_Down;
/// 方向键 右
extern NSString *const __kb_Right;
/* 功能键 */
/// Alt
extern NSString *const __kb_Alt;
/// Tab
extern NSString *const __kb_Tab;
/// End
extern NSString *const __kb_End;
/// Ctrl
extern NSString *const __kb_Ctrl;
/// Win
extern NSString *const __kb_Win;
/// Home
extern NSString *const __kb_Home;
/// Page Dn
extern NSString *const __kb_PageDn;
/// Page Up
extern NSString *const __kb_PageUp;
/// Shift
extern NSString *const __kb_Shift;
/// Spac
extern NSString *const __kb_Space;
/// ScrLK
extern NSString *const __kb_ScrLK;
/// Pause
extern NSString *const __kb_Pause;
/// Insert
extern NSString *const __kb_Insert;
/// Delete
extern NSString *const __kb_Delete;
/// PrtScr
extern NSString *const __kb_PrtScr;
/// Esc
extern NSString *const __kb_Esc;
/// Enter
extern NSString *const __kb_Enter;
/// Backapace
extern NSString *const __kb_Back;
/// Caps Lock
extern NSString *const __kb_CapsLock;
/// 右Shift
extern NSString *const __kb_ShiftR;
/// 右Ctrl
extern NSString *const __kb_CtrlR;
/// 右Alt
extern NSString *const __kb_AltR;
/// 右Win
extern NSString *const __kb_WinR;
/* 符号键 */
/// ~ `
extern NSString *const __kb_Tilde;
/// _ -
extern NSString *const __kb_Subtract;
/// + =
extern NSString *const __kb_Equal;
/// { [
extern NSString *const __kb_LeftBracket;
/// } ]
extern NSString *const __kb_RightBracket;
/// | 反斜杠
extern NSString *const __kb_BackSlash;
/// : ;
extern NSString *const __kb_Semicolon;
/// " '
extern NSString *const __kb_Apostrophe;
/// < ,
extern NSString *const __kb_Separator;
/// > .
extern NSString *const __kb_Decimal;
/// ? 斜杠
extern NSString *const __kb_Slash;
/* 小键盘 */
/// 小键盘锁定
extern NSString *const __kb_numLock;
/// 小键盘 /
extern NSString *const __kb_numDivide;
/// 小键盘 *
extern NSString *const __kb_numMutiply;
/// 小键盘 -
extern NSString *const __kb_numSub;
/// 小键盘 +
extern NSString *const __Kb_numAdd;
/// 小键盘 .
extern NSString *const __kb_numDel;
/// 小键盘 0
extern NSString *const __kb_num0;
/// 小键盘 1
extern NSString *const __kb_num1;
/// 小键盘 2
extern NSString *const __kb_num2;
/// 小键盘 3
extern NSString *const __kb_num3;
/// 小键盘 4
extern NSString *const __kb_num4;
/// 小键盘 5
extern NSString *const __kb_num5;
/// 小键盘 6
extern NSString *const __kb_num6;
/// 小键盘 7
extern NSString *const __kb_num7;
/// 小键盘 8
extern NSString *const __kb_num8;
/// 小键盘 9
extern NSString *const __kb_num9;

#pragma mark - 桌面配置
/// 桌面配置对象
@interface SCCDesktopConfig : NSObject <NSCopying>
/// 是否显示状态栏（default:NO）
@property (assign, nonatomic) BOOL isShowStatusBar;
/// 是否显示默认UI，如关闭需自行调用SCCDesktopController方法，自行绘制菜单等UI（default:YES）
/// 如设置为NO，menuArr、isShowOperationModeBar、isShowDesktopModeBar、isShowInitiativeAlert、isShowPassivityAlert 均无效
@property (assign, nonatomic) BOOL isEnableUI;
/// 菜单项（期望的菜单项，是否开启控制、被控系统等因素影响最终显示）
@property (copy, nonatomic) NSArray *menuArr;
/// 是否显示操作模式切换栏（default:YES, 包括操作模式切换、虚拟鼠标开关、键盘输入）
@property (assign, nonatomic) BOOL isShowOperationModeBar;
/// 是否显示桌面模式切换栏（default:YES）
@property (assign, nonatomic) BOOL isShowDesktopModeBar;
/// 是否显示主动断开弹窗（default:YES，点击退出时的二次确认弹窗）
@property (assign, nonatomic) BOOL isShowActDisconnectAlert;
/// 是否显示被动断开弹窗（default:YES，被控端关闭或连接中断的提示弹窗， 此项关闭时，远控断开后将直接关闭远程桌面）
@property (assign, nonatomic) BOOL isShowPasDisconnectAlert;
@end

NS_ASSUME_NONNULL_END
