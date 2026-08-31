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
      Stack({ alignContent: Alignment.Bottom }) {
        // 内容区（沉浸式：顶部避开状态栏，底部延伸到屏幕底，可滚动到悬浮导航下方）
        Column() {
          if (this.tab === 0) {
            GalleryTab({ pathStack: this.pathStack, customFrames: this.customFrames })
          } else if (this.tab === 1) {
            DesignTab({ frame: this.frame, customFrames: this.customFrames })
          } else {
            SettingsTab()
          }
        }
        .width('100%')
        .height('100%')
        .padding({ top: px2vp(this.statusH) })

        // 底部悬浮胶囊导航：内容区穿透至手势区，胶囊吸附底部（沉浸光感：磨砂玻璃材质）
        Row() {
          this.TabButton(0, '图库', $r('sys.symbol.art_gallery'))
          this.TabButton(1, '设计', $r('sys.symbol.paintpalette'))
          this.TabButton(2, '设置', $r('sys.symbol.gearshape'))
        }
        .width('88%')
        .height(64)
        .borderRadius(32)
        .backgroundColor('#B8FFFFFF')
        .backdropBlur(24)
        .shadow({ radius: 14, color: '#1A000000', offsetX: 0, offsetY: 4 })
        .justifyContent(FlexAlign.SpaceEvenly)
        .margin({ bottom: 10 })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.PageMap)
  }

  @Builder
  TabButton(index: number, label: string, icon: Resource) {
    Column({ space: 4 }) {
      Column() {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([this.tab === index ? '#222222' : '#999999'])
      }
      .width(46)
      .height(46)
      .borderRadius(23)
      .backgroundColor(this.tab === index ? Color.White : Color.Transparent)
      .justifyContent(FlexAlign.Center)
      .shadow(this.tab === index ? { radius: 10, color: '#2E000000', offsetX: 0, offsetY: 2 } : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
      Text(label)
        .fontSize(11)
        .fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.tab === index ? '#222222' : '#999999')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.tab = index;
    })
  }
}
