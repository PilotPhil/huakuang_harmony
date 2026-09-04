import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig, buildPresets } from '../model/FrameConfig';
import { Album, PhotoRec, loadAlbums, markPhotosProcessed, removePhoto } from '../model/AlbumStore';
import { EditParam } from './PhotoEditPage';
import { setStatusBarStyle } from '../util/WindowUtils';
import { exportPhotos } from '../service/FrameExporter';

/** 图库页进入相册详情页的参数 */
export class AlbumDetailParam {
  albumId: string = '';
  customFrames: FrameConfig[] = [];

  constructor(albumId: string, customFrames: FrameConfig[]) {
    this.albumId = albumId;
    this.customFrames = customFrames;
  }
}

/** 相册详情页：以原来的 N×M 网格展示照片，支持双指调整 1～5 列。 */
@Component
export struct AlbumDetailPage {
  @State album: Album = new Album();
  @State cols: number = 3;
  @State startCols: number = 3;
  @State pageW: number = 360;
  @State exporting: boolean = false;
  @StorageLink('albumVersion') @Watch('onAlbumsChanged') albumVersion: number = 0;
  @StorageLink('statusBarH') statusH: number = 0;
  param: AlbumDetailParam = new AlbumDetailParam('', []);
  pathStack: NavPathStack | null = null;

  aboutToAppear(): void {
    setStatusBarStyle(getContext(this) as common.Context, false);
    this.reload();
  }

  onAlbumsChanged(): void {
    this.reload();
  }

  private reload(): void {
    const found = loadAlbums(getContext(this) as common.Context)
      .find((album: Album) => album.id === this.param.albumId);
    if (found !== undefined) {
      this.album = found;
    }
  }

  private gap(): number {
    return 10;
  }

  private cellW(): number {
    const pad = 18;
    return (this.pageW - pad * 2 - (this.cols - 1) * this.gap()) / this.cols;
  }

  private tmpl(): string {
    let value = '';
    for (let i = 0; i < this.cols; i++) {
      value += '1fr ';
    }
    return value.trim();
  }

  private openPhoto(rec: PhotoRec): void {
    if (this.pathStack !== null) {
      this.pathStack.pushPathByName(
        'PhotoEdit',
        new EditParam(rec.uri, this.album.id, this.param.customFrames, rec.frameId),
        true
      );
    }
  }

  private frameForId(id: string): FrameConfig | null {
    const frames = buildPresets().concat(this.param.customFrames);
    for (const frame of frames) {
      if (frame.id === id) {
        return frame;
      }
    }
    return null;
  }

  private configuredPhotos(): PhotoRec[] {
    const photos: PhotoRec[] = [];
    for (const photo of this.album.photos) {
      if (photo.frameId !== '' && this.frameForId(photo.frameId) !== null) {
        photos.push(photo);
      }
    }
    return photos;
  }

  private confirmBatchExport(): void {
    const ready = this.configuredPhotos().length;
    const pending = this.album.photos.length - ready;
    if (ready === 0) {
      promptAction.showToast({ message: '请先为照片选择相框并暂存' });
      return;
    }
    const message = pending > 0
      ? `本相册共 ${this.album.photos.length} 张照片，其中 ${ready} 张已设置相框，${pending} 张尚未设置。是否仅导出已设置相框的照片？`
      : `本相册共 ${ready} 张照片，均已设置相框。是否现在全部导出？`;
    AlertDialog.show({
      title: '批量导出',
      message: message,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: pending > 0 ? `仅导出 ${ready} 张` : `导出 ${ready} 张`,
        fontColor: '#0A59F7',
        action: () => this.batchExport()
      }
    });
  }

  private async batchExport(): Promise<void> {
    if (this.exporting) {
      return;
    }
    const photos = this.configuredPhotos();
    const uris: string[] = [];
    const frames: FrameConfig[] = [];
    for (const photo of photos) {
      const frame = this.frameForId(photo.frameId);
      if (frame !== null) {
        uris.push(photo.uri);
        frames.push(frame);
      }
    }
    this.exporting = true;
    try {
      const ctx = getContext(this) as common.Context;
      const count = await exportPhotos(ctx, uris, frames);
      if (count > 0) {
        markPhotosProcessed(ctx, this.album.id, uris.slice(0, count));
      }
      promptAction.showToast({ message: count > 0 ? `已导出 ${count} 张照片` : '已取消导出' });
    } catch (err) {
      const e = err as BusinessError;
      promptAction.showToast({ message: `批量导出失败：${e.message}` });
    } finally {
      this.exporting = false;
    }
  }

  private confirmRemove(rec: PhotoRec): void {
    AlertDialog.show({
      title: '移除照片',
      message: '从相册中移除这张照片？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: '#D94838',
        action: () => {
          removePhoto(getContext(this) as common.Context, this.album.id, rec.uri);
        }
      }
    });
  }

  @Builder
  PhotoCard(rec: PhotoRec) {
    GridItem() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Image(rec.uri)
          .width(this.cellW())
          .height(this.cellW())
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
        if (rec.frameId !== '') {
          Text('已设置')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#D90A59F7')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(8)
            .margin(6)
        } else if (!rec.processed) {
          Text('未处理')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#80000000')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(8)
            .margin(6)
        }
      }
      .onClick(() => this.openPhoto(rec))
      .gesture(
        LongPressGesture()
          .onAction(() => this.confirmRemove(rec))
      )
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('‹')
            .fontSize(28)
            .fontColor($r('app.color.text_primary'))
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.surface'))
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: 7, color: '#18000000', offsetX: 0, offsetY: 2 })
        .onClick(() => {
          if (this.pathStack !== null) {
            this.pathStack.pop(true);
          }
        })

        Column({ space: 2 }) {
          Text(this.album.name)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.album.photos.length} 张照片`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        Button(this.exporting ? '导出中…' : '批量导出', { type: ButtonType.Capsule })
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#0A59F7')
          .padding({ left: 16, right: 16 })
          .enabled(!this.exporting && this.album.photos.length > 0)
          .onClick(() => this.confirmBatchExport())
      }
      .width('100%')
      .padding({ left: 14, right: 18, top: px2vp(this.statusH) + 8, bottom: 10 })

      if (this.album.photos.length > 0) {
        Grid() {
          ForEach(this.album.photos, (rec: PhotoRec) => {
            this.PhotoCard(rec)
          }, (rec: PhotoRec) => rec.uri)
        }
        .columnsTemplate(this.tmpl())
        .columnsGap(this.gap())
        .rowsGap(this.gap())
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 18, right: 18, top: 12, bottom: 28 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .gesture(
          PinchGesture({ fingers: 2 })
            .onActionStart(() => {
              this.startCols = this.cols;
            })
            .onActionUpdate((event: GestureEvent) => {
              const next = Math.max(1, Math.min(5, Math.round(this.startCols / event.scale)));
              if (next !== this.cols) {
                this.cols = next;
              }
            })
        )
      } else {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.picture'))
            .fontSize(38)
            .fontColor([$r('app.color.text_disabled')])
          Text('这个相册还没有照片')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.pageW = newValue.width as number;
    })
  }
}
