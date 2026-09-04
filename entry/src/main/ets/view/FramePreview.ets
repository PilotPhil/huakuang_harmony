import { FrameConfig, logoResource } from '../model/FrameConfig';
import { ExifInfo, PhotoItem } from '../model/ExifHelper';
import { buildElementSpecs, computeLayout, FrameElementSpec } from '../service/FrameExporter';

function buildSampleExif(): ExifInfo {
  const exif = new ExifInfo();
  exif.aperture = 'f/2.8';
  exif.shutter = '1/250s';
  exif.iso = 'ISO100';
  exif.focal = '35mm';
  exif.camera = 'FrameStudio Camera';
  exif.dateStr = '2026-08-31 15:30';
  exif.gpsStr = '31°13′N 121°28′E';
  return exif;
}

const SAMPLE_EXIF: ExifInfo = buildSampleExif();

/** 预览缩放后的布局。 */
export class PreviewLayout {
  outW: number = 0;
  outH: number = 0;
  m: number = 0;
  photoTop: number = 0;
  photoW: number = 0;
  photoH: number = 0;
  textAreaW: number = 0;
  textAreaX: number = 0;
  s: number = 0;
  specs: FrameElementSpec[] = [];
}

/** 与导出算法同源的实时预览组件，可选开启元素点击和拖动。 */
@Component
export struct FramePreview {
  @ObjectLink frame: FrameConfig;
  photo: PhotoItem | null = null;
  previewWidth: number = 360;
  radius: number = 4;
  zoom: number = 1;
  offsetX: number = 0;
  offsetY: number = 0;
  interactive: boolean = false;
  selectedElementId: string = '';
  onElementSelect?: (id: string) => void;
  onElementMove?: (id: string, dx: number, dy: number) => void;
  onCanvasSelect?: () => void;
  private dragId: string = '';

  private metrics(): PreviewLayout {
    const p = this.photo;
    const pw = p !== null && p !== undefined && p.width > 0 ? p.width : 1200;
    const ph = p !== null && p !== undefined && p.height > 0 ? p.height : 800;
    const exif = p !== null && p !== undefined ? p.exif : SAMPLE_EXIF;
    const l = computeLayout(this.frame, exif, pw, ph);
    const out = new PreviewLayout();
    out.outW = l.outW;
    out.outH = l.outH;
    out.m = l.m;
    out.photoTop = l.photoTop;
    out.photoW = l.photoW;
    out.photoH = l.photoH;
    out.textAreaW = l.textAreaW;
    out.textAreaX = l.textAreaX;
    out.s = this.previewWidth / l.outW;
    out.specs = buildElementSpecs(this.frame, exif, pw, ph);
    return out;
  }

  private textWidth(lay: PreviewLayout, spec: FrameElementSpec): number {
    const width = spec.boxW > 0 ? spec.boxW * lay.s : lay.textAreaW * lay.s;
    return Math.max(32, width);
  }

  private textX(lay: PreviewLayout, spec: FrameElementSpec): number {
    if (spec.manual) {
      return spec.x * this.previewWidth - this.textWidth(lay, spec) / 2;
    }
    const boxX = spec.boxW > 0 ? spec.boxX * lay.s : lay.textAreaX * lay.s;
    const boxW = spec.boxW > 0 ? spec.boxW * lay.s : lay.textAreaW * lay.s;
    const width = this.textWidth(lay, spec);
    if (spec.align === 'right') return boxX + boxW - width;
    if (spec.align === 'center') return boxX + (boxW - width) / 2;
    return boxX;
  }

  private textAlign(spec: FrameElementSpec): TextAlign {
    if (spec.manual) {
      return TextAlign.Center;
    }
    if (spec.align === 'left') return TextAlign.Start;
    if (spec.align === 'right') return TextAlign.End;
    return TextAlign.Center;
  }

  private previewFontSize(spec: FrameElementSpec, lay: PreviewLayout): number {
    return Math.max(3.2, spec.fontPx * lay.s * 0.95);
  }

  private previewTextHeight(spec: FrameElementSpec, lay: PreviewLayout): number {
    return Math.max(4, this.previewFontSize(spec, lay) * 1.25);
  }

  private previewTextY(spec: FrameElementSpec, lay: PreviewLayout, index: number): number {
    const sourceY = spec.y * lay.outH * lay.s;
    if (spec.manual || index <= 0) {
      return sourceY;
    }
    const previous = lay.specs[index - 1];
    const previousY = this.previewTextY(previous, lay, index - 1);
    return Math.max(sourceY, previousY + this.previewTextHeight(previous, lay) + 0.5);
  }

  private logoWidth(lay: PreviewLayout, spec: FrameElementSpec): number {
    const slotW = spec.boxW > 0 ? spec.boxW * lay.s : lay.textAreaW * lay.s;
    return Math.max(18, Math.min(slotW * 0.82, spec.fontPx * lay.s * 4.5));
  }

  private logoHeight(lay: PreviewLayout, spec: FrameElementSpec): number {
    return Math.max(14, spec.fontPx * lay.s * 1.5);
  }

  private logoX(lay: PreviewLayout, spec: FrameElementSpec): number {
    const width = this.logoWidth(lay, spec);
    if (spec.manual) return spec.x * this.previewWidth - width / 2;
    const boxX = spec.boxW > 0 ? spec.boxX * lay.s : lay.textAreaX * lay.s;
    const boxW = spec.boxW > 0 ? spec.boxW * lay.s : lay.textAreaW * lay.s;
    if (spec.align === 'right') return boxX + boxW - width;
    if (spec.align === 'center') return boxX + (boxW - width) / 2;
    return boxX;
  }

  private frameBackground(): string {
    let hex = this.frame.bg.replace('#', '');
    if (hex.length === 8) hex = hex.substring(2);
    if (hex.length !== 6) hex = 'FFFFFF';
    const alpha = Math.round(255 * Math.max(0, Math.min(1, this.frame.opacity)));
    const alphaHex = alpha.toString(16).padStart(2, '0').toUpperCase();
    return `#${alphaHex}${hex}`;
  }

  private effectTint(): string {
    let tint = '#30FFFFFF';
    if (this.frame.effect === 'immersive') tint = '#32DDEBFF';
    if (this.frame.effect === 'transparent') tint = '#28FFFFFF';
    if (this.frame.effect === 'frosted') tint = '#66FFFFFF';
    const alpha = Math.round(parseInt(tint.substring(1, 3), 16) * this.frame.opacity);
    return `#${alpha.toString(16).padStart(2, '0').toUpperCase()}${tint.substring(3)}`;
  }

  private effectBlur(): number {
    if (this.frame.effect === 'gaussian') return 22;
    if (this.frame.effect === 'frosted') return 14;
    if (this.frame.effect === 'immersive') return 8;
    return 3;
  }

  private selectElement(id: string): void {
    if (this.onElementSelect !== undefined) {
      this.onElementSelect(id);
    }
  }

  build() {
    this.PreviewCanvas(this.metrics())
  }

  @Builder
  PreviewCanvas(lay: PreviewLayout) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
      }
      .width(this.previewWidth)
      .height(lay.outH * lay.s)
      .backgroundColor(this.frameBackground())
      .borderRadius(this.radius * lay.s)

      if (this.photo !== null && this.photo !== undefined) {
        Image(this.photo.uri)
          .width(lay.photoW * lay.s)
          .height(lay.photoH * lay.s)
          .objectFit(ImageFit.Fill)
          .position({ x: lay.m * lay.s, y: lay.photoTop * lay.s })
      } else {
        Column() {
          Text(this.interactive ? '点击选择示例照片' : '示例照片')
            .fontSize(Math.max(10, 14 * lay.s))
            .fontColor('#888888')
            .fontWeight(FontWeight.Bold)
        }
        .width(lay.photoW * lay.s)
        .height(lay.photoH * lay.s)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#D8D8D8')
        .position({ x: lay.m * lay.s, y: lay.photoTop * lay.s })
      }

      // 特殊效果只覆盖照片外的相框区域，避免把照片本身模糊或染色。
      this.EffectOverlay(lay)

      if (this.interactive && this.onCanvasSelect !== undefined) {
        Column() {
        }
        .width(this.previewWidth)
        .height(lay.outH * lay.s)
        .backgroundColor('#00FFFFFF')
        .onClick(() => this.onCanvasSelect!())
      }

      ForEach(lay.specs, (spec: FrameElementSpec, index: number) => {
        this.ElementText(spec, lay, index)
      }, (spec: FrameElementSpec) => spec.id)
    }
    .width(this.previewWidth)
    .height(lay.outH * lay.s)
    .scale({ x: this.zoom, y: this.zoom })
    .translate({ x: this.offsetX, y: this.offsetY })
    .clip(true)
  }

  @Builder
  EffectOverlay(lay: PreviewLayout) {
    if (this.frame.effect !== 'none') {
      this.EffectPatch(lay.s, 0, 0, lay.m, lay.outH)
      this.EffectPatch(lay.s, lay.outW - lay.m, 0, lay.m, lay.outH)
      this.EffectPatch(lay.s, lay.m, 0, lay.photoW, lay.photoTop)
      this.EffectPatch(lay.s, lay.m, lay.photoTop + lay.photoH, lay.photoW,
        lay.outH - lay.photoTop - lay.photoH)
    }
  }

  @Builder
  EffectPatch(scale: number, x: number, y: number, width: number, height: number) {
    Column()
      .width(width * scale)
      .height(height * scale)
      .backgroundColor(this.effectTint())
      .backdropBlur(this.effectBlur())
      .position({ x: x * scale, y: y * scale })
  }

  @Builder
  ElementText(spec: FrameElementSpec, lay: PreviewLayout, index: number) {
    if (spec.isLogo) {
      this.LogoElement(spec, lay, index)
    } else if (this.interactive) {
      this.InteractiveElementText(spec, lay)
    } else {
      this.StaticElementText(spec, lay, index)
    }
  }

  @Builder
  LogoElement(spec: FrameElementSpec, lay: PreviewLayout, index: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (spec.logoUri !== '') {
        Image(spec.logoUri)
          .width(this.logoWidth(lay, spec))
          .height(this.logoHeight(lay, spec))
          .objectFit(ImageFit.Contain)
      } else if (logoResource(spec.logoKey) !== null) {
        Image(logoResource(spec.logoKey) as Resource)
          .width(this.logoWidth(lay, spec))
          .height(this.logoHeight(lay, spec))
          .objectFit(ImageFit.Contain)
      }
    }
    .width(this.logoWidth(lay, spec))
    .height(this.logoHeight(lay, spec))
    .position({
      x: this.logoX(lay, spec),
      y: spec.manual ? spec.y * lay.outH * lay.s - this.logoHeight(lay, spec) / 2 : this.previewTextY(spec, lay, index)
    })
    .border({
      width: this.interactive && this.selectedElementId === spec.id ? 1 : 0,
      color: '#0A59F7',
      style: BorderStyle.Dashed
    })
    .onClick(() => this.selectElement(spec.id))
    .gesture(
      PanGesture()
        .onActionStart(() => {
          this.dragId = spec.id;
          this.selectElement(spec.id);
        })
        .onActionUpdate((event: GestureEvent) => {
          if (this.onElementMove !== undefined && this.dragId === spec.id) {
            this.onElementMove(spec.id, event.offsetX / (this.previewWidth * this.zoom),
              event.offsetY / (lay.outH * lay.s * this.zoom));
          }
        })
        .onActionEnd(() => {
          this.dragId = '';
        })
    )
  }

  @Builder
  StaticElementText(spec: FrameElementSpec, lay: PreviewLayout, index: number) {
    Text(spec.text)
      .fontSize(this.previewFontSize(spec, lay))
      .fontColor(spec.color)
      .fontWeight(spec.bold || spec.id === 'title' ? FontWeight.Bold : FontWeight.Normal)
      .width(this.textWidth(lay, spec))
      .height(this.previewTextHeight(spec, lay))
      .textAlign(this.textAlign(spec))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .position({ x: this.textX(lay, spec), y: this.previewTextY(spec, lay, index) })
      .padding({ left: 2, right: 2 })
  }

  @Builder
  InteractiveElementText(spec: FrameElementSpec, lay: PreviewLayout) {
    Text(spec.text)
      .fontSize(Math.max(8, spec.fontPx * lay.s * 0.95))
      .fontColor(spec.color)
      .fontWeight(spec.bold || spec.id === 'title' ? FontWeight.Bold : FontWeight.Normal)
      .width(this.textWidth(lay, spec))
      .height(Math.max(24, spec.fontPx * lay.s * 1.8))
      .textAlign(this.textAlign(spec))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .position({ x: this.textX(lay, spec), y: spec.y * lay.outH * lay.s })
      .border({
        width: this.selectedElementId === spec.id ? 1 : 0,
        color: '#0A59F7',
        style: BorderStyle.Dashed
      })
      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
      .onClick(() => this.selectElement(spec.id))
      .gesture(
        PanGesture()
          .onActionStart(() => {
            this.dragId = spec.id;
            this.selectElement(spec.id);
          })
          .onActionUpdate((event: GestureEvent) => {
            if (this.onElementMove !== undefined && this.dragId === spec.id) {
              this.onElementMove(spec.id, event.offsetX / (this.previewWidth * this.zoom),
                event.offsetY / (lay.outH * lay.s * this.zoom));
            }
          })
          .onActionEnd(() => {
            this.dragId = '';
          })
      )
  }
}
