import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

/** 切换沉浸式状态栏图标颜色：dark=true 时白色图标（深色页面），否则深色图标 */
export async function setStatusBarStyle(ctx: common.Context, dark: boolean): Promise<void> {
  try {
    const win = await window.getLastWindow(ctx);
    win.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: dark ? '#FFFFFF' : '#000000'
    });
  } catch (err) {
    // 非关键路径，忽略
  }
}
