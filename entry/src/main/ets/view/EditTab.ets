import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig, buildPresets } from '../model/FrameConfig';
import { PhotoItem, makePhotoItem } from '../model/ExifHelper';
import { exportFrames } from '../service/FrameExporter';
import { FramePreview } from './FramePreview';

@Component
export struct EditTab {
  @ObjectLink frame: FrameConfig;
  frames: FrameConfig[] = buildPresets();
  @State photos: PhotoItem[] = [];
  @State busy: boolean = false;
  @State showPreview: boolean = false;
  @State previewW: number = 380;


  async pickPhotos() {
    try {
      const opt = new photoAccessHelper.PhotoSelectOptions();
      opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 20;
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
    }
  }

  removePhoto(index: number) {
    this.photos.splice(index, 1);
  }

  async doExport() {
    if (this.photos.length === 0) {
      promptAction.showToast({ message: '请先选择照片' });
      return;
    }
    this.busy = true;
    try {
      const ctx = getContext(this) as common.Context;
      const uris: string[] = [];
      for (const p of this.photos) {
        uris.push(p.uri);
      }
      const n = await exportFrames(ctx, uris, this.frame);
      promptAction.showToast({ message: `已保存 ${n} 张到相册` });
    } catch (err) {
      const e = err as BusinessError;
      promptAction.showToast({ message: `导出失败：${e.message}` });
    } finally {
      this.busy = false;
    }
  }

  @Builder
  PhotoGridTile(item: PhotoItem, index: number) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(item.uri)
        .width(88)
        .height(88)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
      Text('✕')
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor('#CC000000')
        .width(20)
        .height(20)
        .textAlign(TextAlign.Center)
        .borderRadius(10)
        .margin(4)
        .onClick(() => this.removePhoto(index))
    }
  }

  build() {
    Stack() {
      Scroll() {
      Column({ space: 14 }) {
        // 1. 照片选择
        this.SectionTitle('1. 选择照片（可多选）')
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.photos, (item: PhotoItem, index: number) => {
              this.PhotoGridTile(item, index)
            }, (item: PhotoItem) => item.uri)
            // 追加按钮
            Column() {
              Text('＋')
                .fontSize(30)
                .fontColor('#666666')
            }
            .width(88)
            .height(88)
            .borderRadius(10)
            .border({ width: 1, color: '#CCCCCC', style: BorderStyle.Dashed })
            .justifyContent(FlexAlign.Center)
            .onClick(() => this.pickPhotos())
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)

        // 2. 选择相框
        this.SectionTitle('2. 选择相框')
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.frames, (f: FrameConfig) => {
              Column({ space: 4 }) {
                Row() {
                }
                .width(56)
                .height(40)
                .borderRadius(6)
                .backgroundColor(f.bg)
                .border({
                  width: this.frame.id === f.id ? 3 : 1,
                  color: this.frame.id === f.id ? '#0A59F7' : '#DDDDDD'
                })
                Text(f.name)
                  .fontSize(12)
                  .fontColor(this.frame.id === f.id ? '#0A59F7' : '#333333')
              }
              .onClick(() => this.frame.copyFrom(f))
            }, (f: FrameConfig) => f.id)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)

        // 3. 当前相框预览
        this.SectionTitle(`3. 预览（${this.frame.name}）`)
        Row() {
          if (this.photos.length > 0) {
            FramePreview({
              frame: this.frame,
              photo: this.photos.length > 0 ? this.photos[0] : null,
              previewWidth: this.previewW,
              radius: 6
            })
          } else {
            FramePreview({ frame: this.frame, photo: null, previewWidth: this.previewW, radius: 6 })
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .onAreaChange((oldV: Area, newV: Area) => {
          this.previewW = newV.width as number * 0.94;
        })

        Text(this.photos.length > 0
          ? `已选 ${this.photos.length} 张 · 点击「预览」查看全部，导出时将批量加框`
          : '提示：预览与导出的文字布局一致，含光圈/快门/ISO/焦距/时间/位置等 EXIF 信息')
          .fontSize(12)
          .fontColor('#999999')

        // 4. 操作
        Row({ space: 12 }) {
          Button('预览全部', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .backgroundColor('#333333')
            .enabled(this.photos.length > 0)
            .onClick(() => {
              this.showPreview = true;
            })
          Button(this.busy ? '导出中…' : '导出到相册', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .backgroundColor('#0A59F7')
            .enabled(this.photos.length > 0 && !this.busy)
            .onClick(() => this.doExport())
        }
      }
      .padding(16)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)

      if (this.showPreview) {
        this.PreviewOverlay()
      }
    }
  }

  @Builder
  PreviewOverlay() {
    Column() {
      Row() {
        Text('预览')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('关闭')
          .fontSize(15)
          .fontColor('#0A59F7')
          .onClick(() => this.showPreview = false)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      Scroll() {
        Column({ space: 20 }) {
          ForEach(this.photos, (item: PhotoItem) => {
            FramePreview({ frame: this.frame, photo: item, previewWidth: this.previewW, radius: 6 })
          }, (item: PhotoItem) => item.uri)
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  SectionTitle(text: string) {
    Text(text)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor('#333333')
      .width('100%')
  }
}
