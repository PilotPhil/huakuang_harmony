import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private updateSystemBars(systemDark: boolean): void {
    const darkPage = AppStorage.get<boolean>('darkPage') ?? false;
    const lightContent = systemDark || darkPage;
    window.getLastWindow(this.context).then((win: window.Window) => {
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: lightContent ? '#FFFFFF' : '#000000',
        navigationBarColor: '#00000000',
        navigationBarContentColor: lightContent ? '#FFFFFF' : '#000000'
      });
    }).catch(() => {
    });
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    AppStorage.setOrCreate('darkPage', false);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 主窗口已创建，加载主页面
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      // 沉浸式：内容延伸至状态栏/手势区，状态栏透明，图标颜色跟随页面
      try {
        const win = windowStage.getMainWindowSync();
        const systemDark = this.context.resourceManager.getConfigurationSync().colorMode ===
          resourceManager.ColorMode.DARK;
        win.setWindowLayoutFullScreen(true);
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: systemDark ? '#FFFFFF' : '#000000',
          navigationBarColor: '#00000000',
          navigationBarContentColor: systemDark ? '#FFFFFF' : '#000000'
        });
        // 记录安全区高度（px），页面内用 px2vp 转换为 vp 做顶部留白
        const top = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        AppStorage.setOrCreate('statusBarH', top.topRect.height);
        const bottom = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        AppStorage.setOrCreate('navBarH', bottom.bottomRect.height);
      } catch (e) {
        hilog.error(DOMAIN, 'testTag', 'Failed to immerse. Cause: %{public}s', JSON.stringify(e));
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    if (newConfig.colorMode !== undefined) {
      this.updateSystemBars(newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
