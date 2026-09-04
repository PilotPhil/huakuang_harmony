import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';

/** 切换沉浸式状态栏图标颜色：dark=true 时白色图标（深色页面），否则深色图标 */
export async function setStatusBarStyle(ctx: common.Context, dark: boolean): Promise<void> {
  try {
    AppStorage.setOrCreate('darkPage', dark);
    const systemDark = ctx.resourceManager.getConfigurationSync().colorMode ===
      resourceManager.ColorMode.DARK;
    const lightContent = dark || systemDark;
    const win = await window.getLastWindow(ctx);
    win.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: lightContent ? '#FFFFFF' : '#000000',
      navigationBarColor: '#00000000',
      navigationBarContentColor: lightContent ? '#FFFFFF' : '#000000'
    });
  } catch (err) {
    // 非关键路径，忽略
  }
}
