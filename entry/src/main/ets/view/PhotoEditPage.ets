import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig, buildPresets } from '../model/FrameConfig';
import { PhotoItem } from '../model/ExifHelper';
import { exportPhoto } from '../service/FrameExporter';
import { FramePreview } from './FramePreview';
import { setStatusBarStyle } from '../util/WindowUtils';

/** 图库页跳转编辑页的参数 */
export class EditParam {
  photo: PhotoItem = new PhotoItem();
  customFrames: FrameConfig[] = [];

  constructor(photo: PhotoItem, customFrames: FrameConfig[]) {
    this.photo = photo;
    this.customFrames = customFrames;
  }
}

/**
 * 相框编辑页：上部大图预览，下部左右滑动的相框选择条。
 * 第一个为「不使用相框」图标，其余为各相框在本图上的实时预览。
 */
@Component
export struct PhotoEditPage {
  @State selectedId: string = '';
  @State allFrames: FrameConfig[] = [];
  @State busy: boolean = false;
  @State previewW: number = 360;
  @StorageLink('statusBarH') statusH: number = 0;
  param: EditParam = new EditParam(new PhotoItem(), []);
  pathStack: NavPathStack | null = null;

  aboutToAppear(): void {
    this.allFrames = buildPresets().concat(this.param.customFrames);
    setStatusBarStyle(getContext(this) as common.Context, true); // 深色页面：状态栏白色图标
  }

  aboutToDisappear(): void {
    setStatusBarStyle(getContext(this) as common.Context, false); // 回到主页面：恢复深色图标
  }

  private selectedFrame(): FrameConfig | null {
    for (const f of this.allFrames) {
      if (f.id === this.selectedId) {
        return f;
      }
    }
    return null;
  }

  async save() {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const ctx = getContext(this) as common.Context;
      const n = await exportPhoto(ctx, this.param.photo.uri, this.selectedFrame());
      promptAction.showToast({ message: n > 0 ? '已保存到相册' : '已取消保存' });
    } catch (err) {
      const e = err as BusinessError;
      promptAction.showToast({ message: `保存失败：${e.message}` });
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Column() {
          Text('‹')
            .fontSize(26)
            .fontColor(Color.White)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('#2A2A2A')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.pathStack !== null) {
            this.pathStack.pop(true);
          }
        })
        Text(this.param.photo.uri.split('/').pop()?.substring(0, 18) ?? '')
          .fontSize(14)
          .fontColor('#BBBBBB')
          .margin({ left: 12 })
          .maxLines(1)
        Blank()
        Button(this.busy ? '保存中…' : '保存', { type: ButtonType.Capsule })
          .fontSize(14)
          .backgroundColor('#0A59F7')
          .height(36)
          .enabled(!this.busy)
          .onClick(() => this.save())
      }
      .width('100%')
      .height(56)
      .padding({ left: 14, right: 14, top: px2vp(this.statusH) })

      // 大图预览
      Stack() {
        if (this.selectedFrame() === null) {
          Image(this.param.photo.uri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else {
          Scroll() {
            Column() {
              FramePreview({
                frame: this.selectedFrame()!,
                photo: this.param.photo,
                previewWidth: this.previewW,
                radius: 2
              })
            }
            .width('100%')
          }
          .scrollBar(BarState.Off)
          .align(Alignment.Center)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#0D0D0D')
      .onAreaChange((oldV: Area, newV: Area) => {
        this.previewW = (newV.width as number) * 0.96;
      })

      // 相框选择条
      Text(this.selectedFrame() === null ? '当前：无边框' : `当前：${this.selectedFrame()!.name}`)
        .fontSize(12)
        .fontColor('#888888')
        .width('100%')
        .padding({ left: 20, top: 10, bottom: 4 })
      Scroll() {
        Row({ space: 10 }) {
          this.NoFrameTile()
          ForEach(this.allFrames, (f: FrameConfig) => {
            this.FrameTile(f)
          }, (f: FrameConfig) => f.id)
        }
        .padding({ left: 16, right: 16, top: 4, bottom: 14 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111111')
  }

  @Builder
  NoFrameTile() {
    Column({ space: 6 }) {
      Text('⊖')
        .fontSize(44)
        .fontColor('#999999')
      Text('无边框')
        .fontSize(10)
        .fontColor(this.selectedId === '' ? Color.White : '#888888')
    }
    .width(104)
    .height(150)
    .borderRadius(10)
    .backgroundColor('#1C1C1C')
    .border({
      width: this.selectedId === '' ? 3 : 1,
      color: this.selectedId === '' ? Color.White : '#444444'
    })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectedId = '';
    })
  }

  @Builder
  FrameTile(f: FrameConfig) {
    Column({ space: 6 }) {
      FramePreview({
        frame: f,
        photo: this.param.photo,
        previewWidth: 96,
        radius: 2
      })
      Text(f.name)
        .fontSize(10)
        .fontColor(this.selectedId === f.id ? Color.White : '#888888')
    }
    .width(96)
    .height(150)
    .padding(4)
    .borderRadius(10)
    .backgroundColor('#1C1C1C')
    .border({
      width: this.selectedId === f.id ? 3 : 1,
      color: this.selectedId === f.id ? Color.White : '#444444'
    })
    .onClick(() => {
      this.selectedId = f.id;
    })
  }
}
