import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig, buildPresets } from '../model/FrameConfig';
import { markProcessed, setPhotoFrame } from '../model/AlbumStore';
import { PhotoItem, makePhotoItem } from '../model/ExifHelper';
import { exportPhoto } from '../service/FrameExporter';
import { FramePreview } from './FramePreview';
import { setStatusBarStyle } from '../util/WindowUtils';

/** 图库页跳转编辑页的参数 */
export class EditParam {
  uri: string = '';
  albumId: string = '';
  customFrames: FrameConfig[] = [];
  frameId: string = '';

  constructor(uri: string, albumId: string, customFrames: FrameConfig[], frameId: string = '') {
    this.uri = uri;
    this.albumId = albumId;
    this.customFrames = customFrames;
    this.frameId = frameId;
  }
}

/**
 * 相框编辑页：上部大图预览，下部左右滑动的相框选择条。
 * 第一个为「不使用相框」图标，其余为各相框在本图上的实时预览。
 */
@Component
export struct PhotoEditPage {
  @State selectedId: string = '';
  @State selectedFrameRef: FrameConfig = new FrameConfig();
  @State allFrames: FrameConfig[] = [];
  @State busy: boolean = false;
  @State stagedId: string = '';
  @State previewW: number = 360;
  @State photo: PhotoItem = new PhotoItem();
  @StorageLink('statusBarH') statusH: number = 0;
  @StorageLink('navBarH') navH: number = 0;
  param: EditParam = new EditParam('', '', []);
  pathStack: NavPathStack | null = null;

  aboutToAppear(): void {
    this.allFrames = buildPresets().concat(this.param.customFrames);
    for (const frame of this.allFrames) {
      if (frame.id === this.param.frameId) {
        this.selectFrame(frame);
        this.stagedId = frame.id;
        break;
      }
    }
    setStatusBarStyle(getContext(this) as common.Context, true); // 深色页面：状态栏白色图标
    makePhotoItem(this.param.uri).then((item: PhotoItem) => {
      this.photo = item;
    });
  }

  aboutToDisappear(): void {
    setStatusBarStyle(getContext(this) as common.Context, false); // 回到主页面：恢复深色图标
  }

  private selectedFrame(): FrameConfig | null {
    return this.selectedId === '' ? null : this.selectedFrameRef;
  }

  private selectFrame(frame: FrameConfig): void {
    this.selectedFrameRef = frame;
    this.selectedId = frame.id;
  }

  private selectedName(): string {
    const frame = this.selectedFrame();
    return frame === null ? '无边框' : frame.name;
  }

  private tilePreviewWidth(): number {
    return this.photo.height > this.photo.width ? 54 : 78;
  }

  private isStaged(): boolean {
    return this.selectedId !== '' && this.selectedId === this.stagedId;
  }

  private stage(): void {
    const frame = this.selectedFrame();
    if (frame === null) {
      promptAction.showToast({ message: '请先选择一个相框' });
      return;
    }
    setPhotoFrame(getContext(this) as common.Context, this.param.albumId, this.photo.uri, frame.id);
    this.stagedId = frame.id;
    promptAction.showToast({ message: `已暂存「${frame.name}」` });
  }

  async exportCurrent() {
    if (this.busy) {
      return;
    }
    const frame = this.selectedFrame();
    if (frame === null) {
      promptAction.showToast({ message: '请先选择一个相框' });
      return;
    }
    this.busy = true;
    try {
      const ctx = getContext(this) as common.Context;
      const n = await exportPhoto(ctx, this.photo.uri, frame);
      if (n > 0) {
        markProcessed(ctx, this.param.albumId, this.photo.uri);
      }
      promptAction.showToast({ message: n > 0 ? '已导出到相册' : '已取消导出' });
    } catch (err) {
      const e = err as BusinessError;
      promptAction.showToast({ message: `导出失败：${e.message}` });
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      // 极简顶栏
      Row() {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(21)
            .fontColor([Color.White])
        }
        .width(42)
        .height(42)
        .borderRadius(21)
        .backgroundColor('#22FFFFFF')
        .backdropBlur(20)
        .border({ width: 1, color: '#24FFFFFF' })
        .onClick(() => {
          if (this.pathStack !== null) {
            this.pathStack.pop(true);
          }
        })
        Column({ space: 2 }) {
          Text('照片套框')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text(this.photo.uri.split('/').pop()?.substring(0, 22) ?? '')
            .fontSize(11)
            .fontColor('#77777D')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12, right: 12 })
        Row({ space: 8 }) {
          Button(this.isStaged() ? '已暂存' : '暂存', { type: ButtonType.Capsule })
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isStaged() ? '#AFC8FF' : Color.White)
            .backgroundColor(this.isStaged() ? '#263A64' : '#22FFFFFF')
            .height(38)
            .padding({ left: 14, right: 14 })
            .enabled(!this.busy)
            .onClick(() => this.stage())
          Button(this.busy ? '导出中…' : '导出', { type: ButtonType.Capsule })
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#3478F6')
            .height(38)
            .padding({ left: 14, right: 14 })
            .shadow({ radius: 12, color: '#403478F6', offsetX: 0, offsetY: 4 })
            .enabled(!this.busy)
            .onClick(() => this.exportCurrent())
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: px2vp(this.statusH) + 8, bottom: 10 })

      // 沉浸式大图预览
      Stack() {
        if (this.selectedFrame() === null) {
          Image(this.photo.uri)
            .width('92%')
            .height('92%')
            .objectFit(ImageFit.Contain)
            .borderRadius(8)
            .shadow({ radius: 24, color: '#80000000', offsetX: 0, offsetY: 8 })
        } else {
          this.SelectedFramePreview()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#08090A')
      .onAreaChange((oldV: Area, newV: Area) => {
        this.previewW = (newV.width as number) * 0.90;
      })

      // 浮起的相框托盘
      Column({ space: 10 }) {
        Column() {
        }
        .width(34)
        .height(4)
        .borderRadius(2)
        .backgroundColor('#4A4A4F')

        Row() {
          Text('选择相框')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Blank()
          Text(this.selectedName())
            .fontSize(11)
            .fontColor('#B8CFFF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(12)
            .backgroundColor('#263A64')
        }
        .width('100%')

        Scroll() {
          Row({ space: 10 }) {
            this.NoFrameTile()
            ForEach(this.allFrames, (f: FrameConfig) => {
              this.FrameTile(f)
            }, (f: FrameConfig) => f.id)
          }
          .padding({ right: 6 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16, top: 10, bottom: Math.max(12, px2vp(this.navH) + 8) })
      .margin({ left: 8, right: 8, top: 8, bottom: 8 })
      .borderRadius(24)
      .backgroundColor('#EE1C1C1E')
      .backdropBlur(28)
      .border({ width: 1, color: '#20FFFFFF' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#08090A')
  }

  @Builder
  SelectedFramePreview() {
    Scroll() {
      Row() {
        FramePreview({
          frame: this.selectedFrameRef,
          photo: this.photo,
          previewWidth: this.previewW,
          radius: 5
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 24, bottom: 24 })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
    .align(Alignment.Center)
  }

  @Builder
  NoFrameTile() {
    Column({ space: 7 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.photo.uri !== '') {
          Image(this.photo.uri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        }
        Text('原图')
          .fontSize(10)
          .fontColor(Color.White)
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .borderRadius(9)
          .backgroundColor('#99000000')
      }
      .width(80)
      .height(86)
      .borderRadius(9)
      .backgroundColor('#0E0E0F')
      .clip(true)
      Text('无边框')
        .fontSize(11)
        .fontWeight(this.selectedId === '' ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selectedId === '' ? Color.White : '#8E8E93')
    }
    .width(92)
    .height(122)
    .padding(5)
    .borderRadius(13)
    .backgroundColor(this.selectedId === '' ? '#24324C' : '#252527')
    .border({
      width: this.selectedId === '' ? 2 : 1,
      color: this.selectedId === '' ? '#5A94FF' : '#18FFFFFF'
    })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectedId = '';
    })
  }

  @Builder
  FrameTile(f: FrameConfig) {
    Column({ space: 7 }) {
      Stack({ alignContent: Alignment.Center }) {
        FramePreview({
          frame: f,
          photo: this.photo,
          previewWidth: this.tilePreviewWidth(),
          radius: 3
        })
      }
      .width(80)
      .height(86)
      .borderRadius(9)
      .backgroundColor('#0E0E0F')
      .clip(true)
      Text(f.name)
        .fontSize(11)
        .fontWeight(this.selectedId === f.id ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selectedId === f.id ? Color.White : '#8E8E93')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(92)
    .height(122)
    .padding(5)
    .borderRadius(13)
    .backgroundColor(this.selectedId === f.id ? '#24324C' : '#252527')
    .border({
      width: this.selectedId === f.id ? 2 : 1,
      color: this.selectedId === f.id ? '#5A94FF' : '#18FFFFFF'
    })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectFrame(f);
    })
  }
}
