import { common } from '@kit.AbilityKit';
import { FrameConfig } from '../model/FrameConfig';
import { Album, PhotoRec, loadAlbums, removePhoto } from '../model/AlbumStore';
import { EditParam } from './PhotoEditPage';
import { setStatusBarStyle } from '../util/WindowUtils';

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
        new EditParam(rec.uri, this.album.id, this.param.customFrames),
        true
      );
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
        if (!rec.processed) {
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
            .fontColor('#222222')
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(Color.White)
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
            .fontColor('#222222')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.album.photos.length} 张照片`)
            .fontSize(12)
            .fontColor('#888888')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
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
            .fontColor(['#BBBBBB'])
          Text('这个相册还没有照片')
            .fontSize(14)
            .fontColor('#888888')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F2')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.pageW = newValue.width as number;
    })
  }
}
