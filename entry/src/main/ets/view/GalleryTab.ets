import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig } from '../model/FrameConfig';
import { Album, PhotoRec, loadAlbums, createAlbum, addPhotosToAlbum, removePhoto, removeAlbum } from '../model/AlbumStore';
import { AlbumDetailParam } from './AlbumDetailPage';

/**
 * 图库页：右上角 + 新建相册（沉浸光感弹窗）→ 选择导入图片 → 相册卡片堆叠展示。
 * 点击堆叠中的照片或编辑按钮进入相册详情页，长按照片移除。
 */
@Component
export struct GalleryTab {
  pathStack: NavPathStack | null = null;
  @Link customFrames: FrameConfig[];
  @State albums: Album[] = [];
  @State pageW: number = 360;
  @State showCreate: boolean = false;
  @State albumName: string = '';
  @StorageLink('statusBarH') statusH: number = 0;
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

  private pilePhotoWidth(): number {
    return Math.min(260, Math.max(200, this.pageW * 0.68));
  }

  private pilePhotoHeight(): number {
    return this.pilePhotoWidth() * 2 / 3;
  }

  private pileSpread(total: number): number {
    if (total <= 1) {
      return 0;
    }
    const available = Math.max(0, this.pageW - 76 - this.pilePhotoWidth());
    return Math.min(24, available / (total - 1));
  }

  private pileOffset(index: number, total: number): number {
    return (index - (total - 1) / 2) * this.pileSpread(total);
  }

  private pileAngle(index: number, total: number): number {
    if (index === total - 1) {
      return 0;
    }
    return index % 2 === 0 ? -2.5 : 2.5;
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

  openAlbum(album: Album) {
    if (this.pathStack !== null) {
      this.pathStack.pushPathByName(
        'AlbumDetail',
        new AlbumDetailParam(album.id, this.customFrames),
        true
      );
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
  PilePhoto(album: Album, rec: PhotoRec, index: number, total: number) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(rec.uri)
        .width('100%')
        .height('100%')
        .borderRadius(14)
        .objectFit(ImageFit.Cover)
      if (!rec.processed) {
        Text('未处理')
          .fontSize(10)
          .fontColor(Color.White)
          .backgroundColor('#80000000')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(8)
          .margin(7)
      }
    }
    .width(this.pilePhotoWidth())
    .height(this.pilePhotoHeight())
    .borderRadius(14)
    .border({ width: 3, color: Color.White })
    .shadow({ radius: 10, color: '#33000000', offsetX: 0, offsetY: 5 })
    .rotate({ angle: this.pileAngle(index, total) })
    .translate({ x: this.pileOffset(index, total) })
    .zIndex(index)
    .onClick(() => this.openAlbum(album))
    .gesture(
      LongPressGesture()
        .onAction(() => this.confirmRemove(album, rec))
    )
  }

  @Builder
  PhotoPile(album: Album) {
    Stack({ alignContent: Alignment.Center }) {
      ForEach(album.photos, (rec: PhotoRec, index: number) => {
        this.PilePhoto(album, rec, index, album.photos.length)
      }, (rec: PhotoRec) => rec.uri)
    }
    .width('100%')
    .height(this.pilePhotoHeight() + 24)
    .clip(false)
  }

  @Builder
  EmptyAlbum(album: Album) {
    Column({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
        }
        .width(156)
        .height(104)
        .borderRadius(14)
        .backgroundColor('#F1F1F1')
        .rotate({ angle: -4 })

        Column() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(28)
            .fontColor(['#0A59F7'])
        }
        .width(156)
        .height(104)
        .borderRadius(14)
        .backgroundColor('#F7F7F7')
        .border({ width: 2, color: '#D7D7D7', style: BorderStyle.Dashed })
        .justifyContent(FlexAlign.Center)
      }
      Text('点击添加照片 · 长按删除相册')
        .fontSize(12)
        .fontColor('#AAAAAA')
    }
    .width('100%')
    .height(164)
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.importPhotos(album.id))
  }

  @Builder
  AlbumHeader(album: Album) {
    Row() {
      Column({ space: 2 }) {
        Text(album.name)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#222222')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${album.photos.length} 张照片`)
          .fontSize(12)
          .fontColor('#888888')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 8 }) {
        this.AlbumAction($r('sys.symbol.plus'), '#555555', '#F0F0F0', (): void => {
          this.importPhotos(album.id);
        })
        this.AlbumAction($r('sys.symbol.square_and_pencil'), '#0A59F7', '#EAF1FF', (): void => {
          this.openAlbum(album);
        })
        this.AlbumAction($r('sys.symbol.trash'), '#D94838', '#FFF0EE', (): void => {
          this.confirmRemoveAlbum(album);
        })
      }
    }
    .width('100%')
  }

  @Builder
  AlbumAction(icon: Resource, color: string, bg: string, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(icon)
        .fontSize(17)
        .fontColor([color])
    }
    .width(34)
    .height(34)
    .borderRadius(17)
    .backgroundColor(bg)
    .onClick(action)
  }

  @Builder
  AlbumSection(album: Album) {
    Column() {
      this.AlbumHeader(album)

      if (album.photos.length > 0) {
        this.PhotoPile(album)
      } else {
        this.EmptyAlbum(album)
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(22)
    .backgroundColor(Color.White)
    .border({ width: 2, color: '#D8D8D8' })
    .shadow({ radius: 12, color: '#16000000', offsetX: 0, offsetY: 5 })
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
          Text('相册')
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
          .backgroundColor('#80FFFFFF')
          .backdropBlur(20)
          .border({ width: 1, color: '#CCFFFFFF' })
          .justifyContent(FlexAlign.Center)
          .shadow({ radius: 10, color: '#10000000', offsetX: 0, offsetY: 3 })
          .onClick(() => {
            this.showCreate = true;
          })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: px2vp(this.statusH) + 12, bottom: 14 })
        .backgroundColor('#66FFFFFF')
        .backdropBlur(32)

        if (this.albums.length > 0) {
          Scroll() {
            Column({ space: 18 }) {
              ForEach(this.albums, (album: Album) => {
                this.AlbumSection(album)
              }, (album: Album) => album.id)
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 18, bottom: 120 })
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
    .backgroundColor('#F2F5F7')
  }
}
