import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig } from '../model/FrameConfig';
import { Album, PhotoRec, loadAlbums, createAlbum, addPhotosToAlbum, removePhoto, removeAlbum } from '../model/AlbumStore';
import { EditParam } from './PhotoEditPage';

/**
 * 图库页：右上角 + 新建相册（沉浸光感弹窗）→ 选择导入图片 → 相册分组多行多列展示。
 * 双指捏合调整列数（1~5），点击照片进入相框编辑页，长按移除。
 */
@Component
export struct GalleryTab {
  pathStack: NavPathStack | null = null;
  @Link customFrames: FrameConfig[];
  @State albums: Album[] = [];
  @State cols: number = 3;
  @State startCols: number = 3;
  @State pageW: number = 360;
  @State showCreate: boolean = false;
  @State albumName: string = '';
  @StorageLink('albumVersion') @Watch('onAlbumsChanged') albumVersion: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  onAlbumsChanged(): void {
    this.reload();
  }

  private reload(): void {
    this.albums = loadAlbums(getContext(this) as common.Context);
  }

  private gap(): number {
    return 10;
  }

  private cellW(): number {
    const pad = 18;
    return (this.pageW - pad * 2 - (this.cols - 1) * this.gap()) / this.cols;
  }

  private groupH(n: number): number {
    const rows = Math.ceil(n / this.cols);
    return rows * this.cellW() + (rows - 1) * this.gap();
  }

  private tmpl(): string {
    let s = '';
    for (let i = 0; i < this.cols; i++) {
      s += '1fr ';
    }
    return s.trim();
  }

  /** 新建相册：确定后弹出图片选择并导入 */
  confirmCreate() {
    const name = this.albumName.trim();
    if (name === '') {
      promptAction.showToast({ message: '请输入相册名称' });
      return;
    }
    const ctx = getContext(this) as common.Context;
    const album = createAlbum(ctx, name);
    this.showCreate = false;
    this.albumName = '';
    this.importPhotos(album.id);
  }

  async importPhotos(albumId: string) {
    try {
      const opt = new photoAccessHelper.PhotoSelectOptions();
      opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 100;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(opt);
      if (result.photoUris.length > 0) {
        addPhotosToAlbum(getContext(this) as common.Context, albumId, result.photoUris);
      }
    } catch (err) {
      const e = err as BusinessError;
      if (e.code !== 13900042 && e.code !== 13900051) { // 用户取消
        promptAction.showToast({ message: `导入失败：${e.message}` });
      }
    }
  }

  openPhoto(album: Album, rec: PhotoRec) {
    if (this.pathStack !== null) {
      this.pathStack.pushPathByName('PhotoEdit', new EditParam(rec.uri, album.id, this.customFrames), true);
    }
  }

  confirmRemove(album: Album, rec: PhotoRec) {
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
          removePhoto(getContext(this) as common.Context, album.id, rec.uri);
        }
      }
    });
  }

  confirmRemoveAlbum(album: Album) {
    AlertDialog.show({
      title: '删除相册',
      message: `删除相册「${album.name}」？`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#D94838',
        action: () => {
          removeAlbum(getContext(this) as common.Context, album.id);
        }
      }
    });
  }

  @Builder
  Card(album: Album, rec: PhotoRec) {
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
      .onClick(() => this.openPhoto(album, rec))
      .gesture(
        LongPressGesture()
          .onAction(() => this.confirmRemove(album, rec))
      )
    }
  }

  @Builder
  AlbumSection(album: Album) {
    Column() {
      Row() {
        Text(album.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        Blank()
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(14)
            .fontColor(['#888888'])
            .onClick(() => this.importPhotos(album.id))
          Text(`${album.photos.length}张`)
            .fontSize(14)
            .fontColor('#888888')
        }
      }
      .width('100%')
      .padding({ top: 22, bottom: 12 })

      if (album.photos.length > 0) {
        Grid() {
          ForEach(album.photos, (rec: PhotoRec) => {
            this.Card(album, rec)
          }, (rec: PhotoRec) => rec.uri)
        }
        .columnsTemplate(this.tmpl())
        .columnsGap(this.gap())
        .rowsGap(this.gap())
        .height(this.groupH(album.photos.length))
        .width('100%')
      } else {
        Text('（空相册，长按可删除）')
          .fontSize(12)
          .fontColor('#BBBBBB')
          .width('100%')
      }
    }
    .width('100%')
    .gesture(
      LongPressGesture()
        .onAction(() => {
          if (album.photos.length === 0) {
            this.confirmRemoveAlbum(album);
          }
        })
    )
  }

  @Builder
  CreateAlbumDialog() {
    Column() {
      Column({ space: 18 }) {
        Text('新建相册')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#222222')
        TextInput({ text: this.albumName, placeholder: '输入相册名称' })
          .width('100%')
          .height(44)
          .fontSize(15)
          .onChange((v: string) => this.albumName = v)
        Row({ space: 14 }) {
          Button('取消', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .backgroundColor('#E8E8E8')
            .fontColor('#333333')
            .onClick(() => {
              this.showCreate = false;
              this.albumName = '';
            })
          Button('确定', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .backgroundColor('#0A59F7')
            .onClick(() => this.confirmCreate())
        }
        .width('100%')
      }
      .width('80%')
      .padding({ left: 22, right: 22, top: 22, bottom: 20 })
      .borderRadius(22)
      .backgroundColor('#F0FFFFFF')
      .backdropBlur(32)   // 沉浸光感：磨砂玻璃弹窗
      .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#40000000')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        // 顶栏：标题 + 新建相册按钮
        Row() {
          Text('图库')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111111')
          Blank()
          Column() {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(22)
              .fontColor(['#333333'])
          }
          .width(46)
          .height(46)
          .borderRadius(23)
          .backgroundColor(Color.White)
          .justifyContent(FlexAlign.Center)
          .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
          .onClick(() => {
            this.showCreate = true;
          })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 10 })

        if (this.albums.length > 0) {
          Scroll() {
            Column() {
              ForEach(this.albums, (album: Album) => {
                this.AlbumSection(album)
              }, (album: Album) => album.id)
            }
            .padding({ left: 18, right: 18, bottom: 104 })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .gesture(
            PinchGesture({ fingers: 2 })
              .onActionStart(() => {
                this.startCols = this.cols;
              })
              .onActionUpdate((e: GestureEvent) => {
                const c = Math.max(1, Math.min(5, Math.round(this.startCols / e.scale)));
                if (c !== this.cols) {
                  this.cols = c;
                }
              })
          )
        } else {
          Column({ space: 14 }) {
            Column() {
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize(30)
                .fontColor(['#0A59F7'])
            }
            .width(64)
            .height(64)
            .borderRadius(32)
            .border({ width: 1, color: '#CCCCCC', style: BorderStyle.Dashed })
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.showCreate = true;
            })
            Text('还没有相册')
              .fontSize(15)
              .fontColor('#666666')
            Text('点右上角 + 新建相册，导入照片开始')
              .fontSize(12)
              .fontColor('#AAAAAA')
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((oldV: Area, newV: Area) => {
        this.pageW = newV.width as number;
      })

      // 沉浸光感弹窗
      if (this.showCreate) {
        this.CreateAlbumDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F2')
  }
}
