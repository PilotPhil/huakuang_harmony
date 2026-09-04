import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig } from '../model/FrameConfig';
import { Album, PhotoRec, loadAlbums, createAlbum, addPhotosToAlbum, removePhoto, removeAlbum } from '../model/AlbumStore';
import { AlbumDetailParam } from './AlbumDetailPage';

const MAX_PILE_PHOTOS = 5;

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
  @State renderVersion: number = 0;
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
    // 同一相册 id 的空态/有照片态需要强制重建，避免 ForEach 复用旧分支。
    this.renderVersion += 1;
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
    this.reload();
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
        const ctx = getContext(this) as common.Context;
        addPhotosToAlbum(ctx, albumId, result.photoUris);
        // 图片选择器返回后直接刷新当前页面，避免必须切换 Tab 才看到预览。
        this.reload();
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
      ForEach(album.photos.slice(Math.max(0, album.photos.length - MAX_PILE_PHOTOS)),
        (rec: PhotoRec, index: number) => {
        this.PilePhoto(album, rec, index, Math.min(album.photos.length, MAX_PILE_PHOTOS))
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
        .backgroundColor($r('app.color.surface_tertiary'))
        .rotate({ angle: -4 })

        Column() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(28)
            .fontColor(['#0A59F7'])
        }
        .width(156)
        .height(104)
        .borderRadius(14)
        .backgroundColor($r('app.color.surface_secondary'))
        .border({ width: 2, color: $r('app.color.border'), style: BorderStyle.Dashed })
        .justifyContent(FlexAlign.Center)
      }
      Text('点击添加照片 · 长按删除相册')
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
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
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${album.photos.length} 张照片`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 8 }) {
        this.AlbumAction($r('sys.symbol.plus'), $r('app.color.text_secondary'),
          $r('app.color.neutral_control'), (): void => {
          this.importPhotos(album.id);
        })
        this.AlbumAction($r('sys.symbol.square_and_pencil'), '#0A59F7', $r('app.color.blue_tint'), (): void => {
          this.openAlbum(album);
        })
        this.AlbumAction($r('sys.symbol.trash'), '#D94838', $r('app.color.red_tint'), (): void => {
          this.confirmRemoveAlbum(album);
        })
      }
    }
    .width('100%')
  }

  @Builder
  AlbumAction(icon: Resource, color: ResourceColor, bg: ResourceColor, action: () => void) {
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
    .backgroundColor($r('app.color.surface'))
    .border({ width: 2, color: $r('app.color.border') })
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
          .fontColor($r('app.color.text_primary'))
        TextInput({ text: this.albumName, placeholder: '输入相册名称' })
          .width('100%')
          .height(44)
          .fontSize(15)
          .onChange((v: string) => this.albumName = v)
        Row({ space: 14 }) {
          Button('取消', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .backgroundColor($r('app.color.surface_tertiary'))
            .fontColor($r('app.color.text_primary'))
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
      .backgroundColor($r('app.color.dialog_glass'))
      .backdropBlur(32)   // 沉浸光感：磨砂玻璃弹窗
      .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.dialog_mask'))
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        // 顶栏：标题 + 新建相册按钮
        Row() {
          Text('相册')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_strong'))
          Blank()
          Column() {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(22)
              .fontColor([$r('app.color.text_primary')])
          }
          .width(46)
          .height(46)
          .borderRadius(23)
          .backgroundColor($r('app.color.button_glass'))
          .backdropBlur(20)
          .border({ width: 1, color: $r('app.color.border_light') })
          .justifyContent(FlexAlign.Center)
          .shadow({ radius: 10, color: '#10000000', offsetX: 0, offsetY: 3 })
          .onClick(() => {
            this.showCreate = true;
          })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: px2vp(this.statusH) + 12, bottom: 14 })
        .backgroundColor($r('app.color.header_glass'))
        .backdropBlur(32)

        if (this.albums.length > 0) {
          Scroll() {
            Column({ space: 18 }) {
              ForEach(this.albums, (album: Album) => {
                this.AlbumSection(album)
              }, (album: Album) => `${album.id}_${album.photos.length}_${this.renderVersion}`)
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
            .border({ width: 1, color: $r('app.color.border'), style: BorderStyle.Dashed })
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.showCreate = true;
            })
            Text('还没有相册')
              .fontSize(15)
              .fontColor($r('app.color.text_secondary'))
            Text('点右上角 + 新建相册，导入照片开始')
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
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
    .backgroundColor($r('app.color.gallery_background'))
  }
}
