import { common } from '@kit.AbilityKit';
import { FrameConfig, buildPresets, loadCustomFrames } from '../model/FrameConfig';
import { GalleryTab } from '../view/GalleryTab';
import { DesignTab } from '../view/DesignTab';
import { SettingsTab } from '../view/SettingsTab';
import { PhotoEditPage, EditParam } from '../view/PhotoEditPage';

@Entry
@Component
struct Index {
  @State frame: FrameConfig = new FrameConfig();
  @State customFrames: FrameConfig[] = [];
  @State tab: number = 0;
  @StorageLink('statusBarH') statusH: number = 0;
  @StorageLink('navBarH') navH: number = 0;
  pathStack: NavPathStack = new NavPathStack();
  private tmp: FrameConfig = buildPresets()[0];

  aboutToAppear(): void {
    this.frame.copyFrom(this.tmp);
    this.customFrames = loadCustomFrames(getContext(this) as common.Context);
  }

  @Builder
  PageMap(name: string, param: object) {
    if (name === 'PhotoEdit') {
      NavDestination() {
        PhotoEditPage({ param: param as EditParam, pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    }
  }

  build() {
    Navigation(this.pathStack) {
      Column() {
        // 内容区（沉浸式：顶部避开状态栏）
        Column() {
          if (this.tab === 0) {
            GalleryTab({ pathStack: this.pathStack, customFrames: this.customFrames })
          } else if (this.tab === 1) {
            DesignTab({ frame: this.frame, customFrames: this.customFrames })
          } else {
            SettingsTab()
          }
        }
        .layoutWeight(1)
        .width('100%')

        // 底部悬浮胶囊导航（参考 3.jpg）
        Row() {
          this.TabButton(0, '图库', $r('sys.symbol.art_gallery'))
          this.TabButton(1, '设计', $r('sys.symbol.paintpalette'))
          this.TabButton(2, '设置', $r('sys.symbol.gearshape'))
        }
        .width('88%')
        .height(60)
        .borderRadius(30)
        .backgroundColor(Color.White)
        .shadow({ radius: 22, color: '#26000000', offsetX: 0, offsetY: 8 })
        .justifyContent(FlexAlign.SpaceEvenly)
        .margin({
          top: 8,
          bottom: Math.max(10, px2vp(this.navH) + 8)
        })
      }
      .width('100%')
      .height('100%')
      .padding({ top: px2vp(this.statusH) })
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.PageMap)
  }

  @Builder
  TabButton(index: number, label: string, icon: Resource) {
    Column({ space: 3 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.tab === index ? '#0A59F7' : '#999999'])
      Text(label)
        .fontSize(11)
        .fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.tab === index ? '#0A59F7' : '#999999')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.tab = index;
    })
  }
}
