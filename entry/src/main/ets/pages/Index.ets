import { common } from '@kit.AbilityKit';
import { FrameConfig, buildPresets, loadCustomFrames } from '../model/FrameConfig';
import { GalleryTab } from '../view/GalleryTab';
import { DesignTab } from '../view/DesignTab';
import { SettingsTab } from '../view/SettingsTab';
import { PhotoEditPage, EditParam } from '../view/PhotoEditPage';
import { AlbumDetailPage, AlbumDetailParam } from '../view/AlbumDetailPage';
import { FrameDesignPage, FrameDesignParam } from '../view/FrameDesignPage';

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
    } else if (name === 'AlbumDetail') {
      NavDestination() {
        AlbumDetailPage({ param: param as AlbumDetailParam, pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'FrameDesign') {
      NavDestination() {
        FrameDesignPage({
          param: param as FrameDesignParam,
          customFrames: this.customFrames,
          pathStack: this.pathStack
        })
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
            DesignTab({
              frame: this.frame,
              customFrames: this.customFrames,
              pathStack: this.pathStack
            })
          } else {
            SettingsTab()
          }
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.tab === 0 ? 0 : px2vp(this.statusH) })

        // 底部悬浮胶囊导航（参考 pic/6：白色胶囊 ~60% 宽、选中蓝色、未选中黑色）
        Row() {
          this.TabButton(0, '相册', $r('sys.symbol.art_gallery'))
          this.TabButton(1, '设计', $r('sys.symbol.paintpalette'))
          this.TabButton(2, '设置', $r('sys.symbol.gearshape'))
        }
        .width('62%')
        .height(66)
        .borderRadius(33)
        .backgroundColor($r('app.color.nav_glass'))
        .backdropBlur(24)
        .shadow({ radius: 18, color: '#22000000', offsetX: 0, offsetY: 6 })
        .justifyContent(FlexAlign.SpaceEvenly)
        .margin({ bottom: 26 })
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
    Column({ space: 5 }) {
      SymbolGlyph(icon)
        .fontSize(25)
        .fontColor([this.tab === index ? '#0A59F7' : $r('app.color.text_primary')])
      Text(label)
        .fontSize(12)
        .fontWeight(this.tab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.tab === index ? '#0A59F7' : $r('app.color.text_primary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.tab = index;
    })
  }
}
