import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig } from '../model/FrameConfig';
import { PhotoItem, makePhotoItem } from '../model/ExifHelper';
import { EditParam } from './PhotoEditPage';

/**
 * 图库页：从相册多选图片后以 n×m 网格展示，双指捏合调整列数（m: 1~5）。
 * 点击图片进入相框编辑页。
 */
@Component
export struct GalleryTab {
  pathStack: NavPathStack | null = null;
  @Link customFrames: FrameConfig[];
  @State photos: PhotoItem[] = [];
  @State cols: number = 3;
  @State startCols: number = 3;
  @State pickBusy: boolean = false;

  private tmpl(): string {
    let s = '';
    for (let i = 0; i < this.cols; i++) {
      s += '1fr ';
    }
    return s.trim();
  }

  async pickPhotos() {
    if (this.pickBusy) {
      return;
    }
    this.pickBusy = true;
    try {
      const opt = new photoAccessHelper.PhotoSelectOptions();
      opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 100;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(opt);
      for (const uri of result.photoUris) {
        if (this.photos.some(p => p.uri === uri)) {
          continue;
        }
        const item = await makePhotoItem(uri);
        this.photos.push(item);
      }
    } catch (err) {
      const e = err as BusinessError;
      if (e.code !== 13900042 && e.code !== 13900051) { // 用户取消
        promptAction.showToast({ message: `选择失败：${e.message}` });
      }
    } finally {
      this.pickBusy = false;
    }
  }

  removePhoto(index: number) {
    this.photos.splice(index, 1);
  }

  openPhoto(item: PhotoItem) {
    if (this.pathStack !== null) {
      this.pathStack.pushPathByName('PhotoEdit', new EditParam(item, this.customFrames), true);
    }
  }

  @Builder
  Tile(item: PhotoItem, index: number) {
    GridItem() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(item.uri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
        Text('JPEG')
          .fontSize(11)
          .fontColor('#F5F5F5')
          .fontWeight(FontWeight.Bold)
          .margin({ right: 7, bottom: 5 })
          .textShadow({ radius: 2, color: '#AA000000', offsetX: 0, offsetY: 1 })
        Stack({ alignContent: Alignment.TopEnd }) {
          Text('✕')
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .width(22)
            .height(22)
            .borderRadius(11)
            .textAlign(TextAlign.Center)
            .margin(5)
            .onClick(() => this.removePhoto(index))
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .borderRadius(2)
      .clip(true)
      .onClick(() => this.openPhoto(item))
    }
    .aspectRatio(1)
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('图库')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111111')
        Blank()
        Button('选择照片', { type: ButtonType.Capsule })
          .fontSize(13)
          .backgroundColor('#0A59F7')
          .fontColor(Color.White)
          .height(34)
          .onClick(() => this.pickPhotos())
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 12, bottom: 10 })

      Text(this.photos.length > 0
        ? `共 ${this.photos.length} 张 · ${this.cols} 列 · 双指捏合调整列数（1~5）`
        : '提示：双指捏合可调整图片列数（1~5 列），点击图片进入相框编辑')
        .fontSize(12)
        .fontColor('#999999')
        .width('100%')
        .padding({ left: 18 })

      // 网格
      if (this.photos.length > 0) {
        Grid() {
          ForEach(this.photos, (item: PhotoItem, index: number) => {
            this.Tile(item, index)
          }, (item: PhotoItem) => item.uri)
        }
        .columnsTemplate(this.tmpl())
        .columnsGap(2)
        .rowsGap(2)
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 2, right: 2, top: 10, bottom: 10 })
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
        Column({ space: 18 }) {
          Column() {
            Text('＋')
              .fontSize(36)
              .fontColor('#0A59F7')
          }
          .width(68)
          .height(68)
          .borderRadius(34)
          .border({ width: 1, color: '#CCCCCC', style: BorderStyle.Dashed })
          .justifyContent(FlexAlign.Center)
          .onClick(() => this.pickPhotos())
          Text('从相册选择照片')
            .fontSize(14)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
