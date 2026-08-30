import { common } from '@kit.AbilityKit';
import { FrameConfig, buildPresets, loadCustomFrames } from '../model/FrameConfig';
import { EditTab } from '../view/EditTab';
import { DesignTab } from '../view/DesignTab';
import { SettingsTab } from '../view/SettingsTab';

@Entry
@Component
struct Index {
  @State frame: FrameConfig = new FrameConfig();
  @State customFrames: FrameConfig[] = [];
  @State tab: number = 0;
  private tmp: FrameConfig = buildPresets()[0];

  aboutToAppear(): void {
    this.frame.copyFrom(this.tmp);
    this.customFrames = loadCustomFrames(getContext(this) as common.Context);
  }

  build() {
    Column() {
      // 内容区
      Column() {
        if (this.tab === 0) {
          EditTab({ frame: this.frame })
        } else if (this.tab === 1) {
          DesignTab({ frame: this.frame, customFrames: this.customFrames })
        } else {
          SettingsTab()
        }
      }
      .layoutWeight(1)

      // 底部导航
      Row() {
        this.TabButton(0, '编辑', '🖼')
        this.TabButton(1, '设计', '🎨')
        this.TabButton(2, '设置', '⚙️')
      }
      .width('100%')
      .height(58)
      .backgroundColor('#FAFAFA')
      .border({ width: { top: 0.5 }, color: '#E5E5E5' })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TabButton(index: number, label: string, icon: string) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(18)
      Text(label)
        .fontSize(11)
        .fontColor(this.tab === index ? '#0A59F7' : '#999999')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.tab === index ? '#EEF4FF' : Color.Transparent)
    .borderRadius(10)
    .margin(4)
    .onClick(() => {
      this.tab = index;
    })
  }
}
