import { FrameConfig } from '../model/FrameConfig';
import { PhotoItem } from '../model/ExifHelper';
import { computeLayout, FrameLayout } from '../service/FrameExporter';

/** 预览缩放后的布局（px） */
export class PreviewLayout {
  outW: number = 0;
  outH: number = 0;
  m: number = 0;
  fontPx: number = 0;
  photoTop: number = 0;
  photoW: number = 0;
  photoH: number = 0;
  s: number = 0;
  lines: string[] = [];
}

/** 与导出算法同源的实时预览组件 */
@Component
export struct FramePreview {
  @ObjectLink frame: FrameConfig;
  photo: PhotoItem | null = null;
  previewWidth: number = 360;
  radius: number = 4;

  private metrics(): PreviewLayout {
    const p = this.photo;
    const pw = p !== null && p !== undefined && p.width > 0 ? p.width : 1200;
    const ph = p !== null && p !== undefined && p.height > 0 ? p.height : 800;
    const l = computeLayout(this.frame, p !== null && p !== undefined ? p.exif : null, pw, ph);
    const out = new PreviewLayout();
    out.outW = l.outW;
    out.outH = l.outH;
    out.m = l.m;
    out.fontPx = l.fontPx;
    out.photoTop = l.photoTop;
    out.photoW = l.photoW;
    out.photoH = l.photoH;
    out.s = this.previewWidth / l.outW;
    out.lines = l.lines;
    return out;
  }

  private textAlignValue(): TextAlign {
    if (this.frame.align === 'left') {
      return TextAlign.Start;
    }
    if (this.frame.align === 'right') {
      return TextAlign.End;
    }
    return TextAlign.Center;
  }

  build() {
    Column() {
      Column() {
        if (this.frame.pos === 'top') {
          this.TextBand(this.metrics())
        }
        if (this.photo !== null && this.photo !== undefined) {
          Image(this.photo!.uri)
            .width(this.metrics().photoW * this.metrics().s)
            .height(this.metrics().photoH * this.metrics().s)
            .objectFit(ImageFit.Fill)
            .borderRadius(1 * this.metrics().s)
        } else {
          Column() {
            Text('示例照片')
              .fontSize(Math.max(10, 14 * this.metrics().s))
              .fontColor('#888888')
              .fontWeight(FontWeight.Bold)
          }
          .width(this.metrics().photoW * this.metrics().s)
          .height(this.metrics().photoH * this.metrics().s)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#D8D8D8')
          .borderRadius(1 * this.metrics().s)
        }
        if (this.frame.pos === 'bottom') {
          this.TextBand(this.metrics())
        }
      }
      .width(this.previewWidth)
      .padding({
        left: this.metrics().m * this.metrics().s,
        right: this.metrics().m * this.metrics().s,
        top: Math.max(4, this.metrics().photoTop * this.metrics().s),
        bottom: Math.max(4, (this.metrics().outH - this.metrics().photoTop - this.metrics().photoH) * this.metrics().s)
      })
      .backgroundColor(this.frame.bg)
      .borderRadius(this.radius * this.metrics().s)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  TextBand(lay: PreviewLayout) {
    Column() {
      ForEach(lay.lines, (line: string) => {
        Text(line)
          .fontSize(Math.max(8, lay.fontPx * lay.s * 0.95))
          .fontColor(this.frame.textColor)
          .width('100%')
          .textAlign(this.textAlignValue())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: lay.fontPx * lay.s * 0.7 })
      }, (line: string) => line)
    }
    .width('100%')
  }
}
