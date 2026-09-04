import { drawing } from '@kit.ArkGraphics2D';
import { common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig, FrameElement, logoResource } from '../model/FrameConfig';
import { ExifInfo, readExif } from '../model/ExifHelper';

/** 导出的布局结果（像素） */
export class FrameLayout {
  outW: number = 0;
  outH: number = 0;
  m: number = 0;          // 左右及顶部边距
  fontPx: number = 0;
  photoTop: number = 0;   // 照片绘制区域的顶部 y
  photoX: number = 0;
  photoW: number = 0;
  photoH: number = 0;
  textAreaW: number = 0;
  textAreaX: number = 0;
  lines: string[] = [];
}

/** 参与预览和导出的单个文字元素。 */
export class FrameElementSpec {
  id: string = '';
  text: string = '';
  x: number = 0.5;
  y: number = 0.5;
  /** 自动排版时的文字槽位（输出像素），供预览和导出共用。 */
  boxX: number = 0;
  boxW: number = 0;
  fontPx: number = 24;
  color: string = '#1A1A1A';
  bold: boolean = false;
  manual: boolean = false;
  align: string = 'center';
  isLogo: boolean = false;
  logoKey: string = '';
  logoUri: string = '';
}

function hexToArgb(hex: string, opacity: number = 1): number {
  let s = hex.replace('#', '');
  if (s.length === 6) {
    s = `FF${s}`;
  }
  const v = parseInt(s, 16);
  if (isNaN(v)) return 0xFF000000;
  const alpha = (((v >>> 24) & 0xFF) / 255) * Math.max(0, Math.min(1, opacity));
  // JPEG 没有透明通道，导出时将相框颜色合成到白底，避免半透明区域变黑。
  const r = Math.round(((v >>> 16) & 0xFF) * alpha + 255 * (1 - alpha));
  const g = Math.round(((v >>> 8) & 0xFF) * alpha + 255 * (1 - alpha));
  const b = Math.round((v & 0xFF) * alpha + 255 * (1 - alpha));
  return (0xFF000000 | (r << 16) | (g << 8) | b) >>> 0;
}

function elementText(id: string, frame: FrameConfig, exif: ExifInfo | null): string {
  if (id === 'title') return frame.title.trim();
  if (exif === null) return '';
  if (id === 'aperture') return exif.aperture;
  if (id === 'shutter') return exif.shutter;
  if (id === 'iso') return exif.iso;
  if (id === 'focal') return exif.focal;
  if (id === 'camera') return exif.camera;
  if (id === 'time') return exif.dateStr;
  if (id === 'gps') return exif.gpsStr;
  return '';
}

/** 根据相框与照片信息生成独立文字元素。 */
export function buildElementSpecs(frame: FrameConfig, exif: ExifInfo | null,
  pw: number, ph: number): FrameElementSpec[] {
  frame.syncElements();
  const minDim = Math.min(pw, ph);
  const visible: FrameElement[] = [];
  for (const element of frame.elements) {
    const hasValue = element.id === 'logo'
      ? element.logoKey !== '' || element.logoUri !== ''
      : elementText(element.id, frame, exif) !== '';
    if (element.enabled && hasValue) {
      visible.push(element);
    }
  }
  let maxFont = Math.max(8, frame.fontSize * minDim);
  for (const element of visible) {
    maxFont = Math.max(maxFont, Math.max(8, element.fontSize * minDim));
  }
  const gap = maxFont * 0.7;
  const lineH = maxFont * 1.5;
  const horizontal = frame.infoLayout === 'horizontal';
  const lineCount = horizontal ? 1 : visible.length;
  const band = visible.length > 0 ? gap + lineH * lineCount + gap : 0;
  const sideMargin = Math.round((frame.borderSideRatio !== undefined ? frame.borderSideRatio : frame.borderRatio) * minDim);
  const bottomMargin = Math.round((frame.borderBottomRatio !== undefined ? frame.borderBottomRatio : frame.borderRatio) * minDim);
  const outW = pw + sideMargin * 2;
  const outH = ph + sideMargin + bottomMargin + band;
  const photoTop = frame.pos === 'top' ? sideMargin + band : sideMargin;
  const textAreaW = pw * Math.max(0.55, Math.min(1, frame.textAreaRatio));
  const textAreaX = (outW - textAreaW) / 2;
  const specs: FrameElementSpec[] = [];
  for (let i = 0; i < visible.length; i++) {
    const element = visible[i];
    const spec = new FrameElementSpec();
    spec.id = element.id;
    spec.text = elementText(element.id, frame, exif);
    spec.fontPx = Math.max(8, (element.fontSize > 0 ? element.fontSize : frame.fontSize) * minDim);
    spec.color = element.color !== '' ? element.color : frame.textColor;
    spec.bold = element.bold || element.id === 'title';
    spec.manual = element.manual;
    spec.align = frame.align;
    spec.isLogo = element.id === 'logo';
    spec.logoKey = element.logoKey;
    spec.logoUri = element.logoUri;
    if (element.manual) {
      spec.x = Math.max(0.04, Math.min(0.96, element.x));
      spec.y = Math.max(0.03, Math.min(0.97, element.y));
      if (!element.allowInsidePhoto) {
        const bandMin = frame.pos === 'top' ? sideMargin : photoTop + ph;
        const bandMax = frame.pos === 'top' ? photoTop : outH - bottomMargin;
        spec.y = Math.max(bandMin / outH, Math.min(bandMax / outH, spec.y));
      }
    } else {
      spec.boxW = horizontal ? textAreaW / visible.length : textAreaW;
      spec.boxX = horizontal ? textAreaX + spec.boxW * i : textAreaX;
      if (horizontal) {
        spec.x = (spec.boxX + spec.boxW / 2) / outW;
      } else if (frame.align === 'left') {
        spec.x = textAreaX / outW + 0.02;
      } else if (frame.align === 'right') {
        spec.x = (textAreaX + textAreaW) / outW - 0.02;
      } else {
        spec.x = (textAreaX + textAreaW / 2) / outW;
      }
      const localY = frame.pos === 'top'
        ? sideMargin + gap + lineH * (horizontal ? 0 : i)
        : photoTop + ph + gap + lineH * (horizontal ? 0 : i);
      spec.y = (localY + spec.fontPx * 0.15) / outH;
    }
    specs.push(spec);
  }
  return specs;
}

class LogoBitmap {
  pixelMap: image.PixelMap | null = null;
  width: number = 0;
  height: number = 0;
}

/** 读取内置或用户 Logo，并按信息字号限制其最大宽度。 */
async function loadLogoBitmap(ctx: common.Context, spec: FrameElementSpec,
  maxWidth: number): Promise<LogoBitmap | null> {
  let source: image.ImageSource | null = null;
  let fd: number = -1;
  try {
    if (spec.logoUri !== '') {
      const file = fs.openSync(spec.logoUri, fs.OpenMode.READ_ONLY);
      fd = file.fd;
      source = image.createImageSource(fd);
    } else {
      const resource = logoResource(spec.logoKey);
      if (resource === null) return null;
      const bytes = await ctx.resourceManager.getMediaContent(resource);
      source = image.createImageSource(bytes.buffer as ArrayBuffer);
    }
    const info = await source.getImageInfo();
    if (info.size.width <= 0 || info.size.height <= 0) return null;
    const width = Math.max(16, Math.min(maxWidth, spec.fontPx * 4.5));
    const height = Math.max(12, width * info.size.height / info.size.width);
    const pixelMap = await source.createPixelMap({
      desiredSize: { width: Math.round(width), height: Math.round(height) }
    });
    const result = new LogoBitmap();
    result.pixelMap = pixelMap;
    result.width = width;
    result.height = height;
    return result;
  } catch (err) {
    return null;
  } finally {
    if (source !== null) source.release();
    if (fd >= 0) fs.closeSync(fd);
  }
}

/** 参与兼容旧调用的文字行列表。 */
export function buildLines(frame: FrameConfig, exif: ExifInfo | null): string[] {
  return buildElementSpecs(frame, exif, 1200, 800).map((spec: FrameElementSpec) => spec.text);
}

export function computeLayout(frame: FrameConfig, exif: ExifInfo | null, pw: number, ph: number): FrameLayout {
  const lay = new FrameLayout();
  const minDim = Math.min(pw, ph);
  lay.m = Math.round((frame.borderSideRatio !== undefined ? frame.borderSideRatio : frame.borderRatio) * minDim);
  lay.fontPx = Math.max(8, frame.fontSize * minDim);
  const specs = buildElementSpecs(frame, exif, pw, ph);
  lay.lines = specs.map((spec: FrameElementSpec) => spec.text);
  let maxFont = lay.fontPx;
  for (const spec of specs) {
    maxFont = Math.max(maxFont, spec.fontPx);
  }
  const lineCount = frame.infoLayout === 'horizontal' ? 1 : specs.length;
  const band = specs.length > 0 ? maxFont * 0.7 + maxFont * 1.5 * lineCount + maxFont * 0.7 : 0;
  const sideMargin = lay.m;
  const bottomMargin = Math.round((frame.borderBottomRatio !== undefined ? frame.borderBottomRatio : frame.borderRatio) * minDim);
  lay.photoW = pw;
  lay.photoH = ph;
  lay.textAreaW = pw * Math.max(0.55, Math.min(1, frame.textAreaRatio));
  lay.textAreaX = (pw + 2 * lay.m - lay.textAreaW) / 2;
  lay.photoX = lay.m;
  lay.photoTop = frame.pos === 'top' ? sideMargin + band : sideMargin;
  lay.outW = pw + 2 * lay.m;
  lay.outH = ph + sideMargin + bottomMargin + band;
  return lay;
}

/** 渲染一张：解码 -> 画布绘制 -> JPEG -> 沙箱文件，返回 file:// URI */
async function renderOne(ctx: common.Context, uri: string, frame: FrameConfig, index: number): Promise<string> {
  const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  const src = image.createImageSource(file.fd);
  const info = await src.getImageInfo();
  let dw = info.size.width;
  let dh = info.size.height;
  const cap = 4096;
  const scale = Math.min(1, cap / Math.max(dw, dh));
  if (scale < 1) {
    dw = Math.round(dw * scale);
    dh = Math.round(dh * scale);
  }
  const pm = await src.createPixelMap({ desiredSize: { width: dw, height: dh } });
  const exif = await readExif(src);
  src.release();
  fs.closeSync(file.fd);

  const lay = computeLayout(frame, exif, dw, dh);
  const outPm = image.createPixelMapSync({
    size: { width: lay.outW, height: lay.outH },
    pixelFormat: image.PixelMapFormat.RGBA_8888
  });
  const canvas = new drawing.Canvas(outPm);
  canvas.clear(hexToArgb(frame.bg, frame.opacity));
  const dst: common2D.Rect = { left: lay.photoX, top: lay.photoTop, right: lay.photoX + lay.photoW, bottom: lay.photoTop + lay.photoH };
  canvas.drawImageRect(pm, dst, new drawing.SamplingOptions(drawing.FilterMode.FILTER_MODE_LINEAR));

  const specs = buildElementSpecs(frame, exif, dw, dh);
  if (specs.length > 0) {
    const font = new drawing.Font();
    const brush = new drawing.Brush();
    canvas.attachBrush(brush);
    for (const spec of specs) {
      if (spec.isLogo) {
        const slotW = spec.boxW > 0 ? spec.boxW : lay.textAreaW;
        const logo = await loadLogoBitmap(ctx, spec, Math.max(16, slotW * 0.82));
        if (logo !== null && logo.pixelMap !== null) {
          let x = lay.textAreaX;
          if (spec.manual) {
            x = spec.x * lay.outW - logo.width / 2;
          } else if (spec.align === 'center') {
            x = spec.boxW > 0 ? spec.boxX + (spec.boxW - logo.width) / 2 : lay.textAreaX + (lay.textAreaW - logo.width) / 2;
          } else if (spec.align === 'right') {
            x = spec.boxW > 0 ? spec.boxX + spec.boxW - logo.width : lay.textAreaX + lay.textAreaW - logo.width;
          } else if (spec.boxW > 0) {
            x = spec.boxX;
          }
          const y = spec.manual ? spec.y * lay.outH - logo.height / 2 : spec.y * lay.outH;
          canvas.drawImageRect(logo.pixelMap, {
            left: x,
            top: y,
            right: x + logo.width,
            bottom: y + logo.height
          });
          logo.pixelMap.release();
        }
        continue;
      }
      font.setSize(spec.fontPx);
      font.enableEmbolden(spec.bold);
      brush.setColor(hexToArgb(spec.color));
      const blob = drawing.TextBlob.makeFromString(spec.text, font);
      const b = blob.bounds();
      const w = Math.max(0, b.right - b.left);
      let x = lay.photoX;
      if (spec.manual) {
        x = spec.x * lay.outW - w / 2;
      } else if (spec.align === 'center') {
        x = spec.boxW > 0 ? spec.boxX + (spec.boxW - w) / 2 : lay.textAreaX + (lay.textAreaW - w) / 2;
      } else if (spec.align === 'right') {
        x = spec.boxW > 0 ? spec.boxX + spec.boxW - w : lay.textAreaX + lay.textAreaW - w;
      } else if (spec.boxW > 0) {
        x = spec.boxX;
      }
      const y = spec.manual
        ? spec.y * lay.outH + spec.fontPx * 0.8
        : spec.y * lay.outH + spec.fontPx * 0.8;
      canvas.drawTextBlob(blob, x, y);
    }
    canvas.detachBrush();
    canvas.detachPen();
  }

  const packer = image.createImagePacker();
  const buf = await packer.packing(outPm, { format: 'image/jpeg', quality: 94 });
  packer.release();
  pm.release();
  outPm.release();

  const path = `${ctx.cacheDir}/framed_${Date.now()}_${index}.jpg`;
  const outFile = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
  fs.writeSync(outFile.fd, buf);
  fs.closeSync(outFile.fd);
  return fileUri.getUriFromPath(path);
}

/** 批量渲染并通过一次系统对话框保存，返回用户确认保存的数量。 */
export async function exportPhotos(ctx: common.Context, uris: string[], frames: FrameConfig[]): Promise<number> {
  const files: string[] = [];
  const count = Math.min(uris.length, frames.length);
  for (let i = 0; i < count; i++) {
    files.push(await renderOne(ctx, uris[i], frames[i], i));
  }
  if (files.length === 0) {
    return 0;
  }
  const helper = photoAccessHelper.getPhotoAccessHelper(ctx);
  const configs: photoAccessHelper.PhotoCreationConfig[] = [];
  for (let i = 0; i < files.length; i++) {
    configs.push({
      title: `相框_${i + 1}`,
      fileNameExtension: 'jpg',
      photoType: photoAccessHelper.PhotoType.IMAGE
    });
  }
  const saved = await helper.showAssetsCreationDialog(files, configs);
  return saved.length;
}

/** 单张照片导出。 */
export async function exportPhoto(ctx: common.Context, uri: string, frame: FrameConfig): Promise<number> {
  return exportPhotos(ctx, [uri], [frame]);
}
