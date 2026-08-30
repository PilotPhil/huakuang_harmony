import { drawing } from '@kit.ArkGraphics2D';
import { common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig } from '../model/FrameConfig';
import { ExifInfo, readExif } from '../model/ExifHelper';

/** 导出的布局结果（像素） */
export class FrameLayout {
  outW: number = 0;
  outH: number = 0;
  m: number = 0;          // 四周边距
  fontPx: number = 0;
  photoTop: number = 0;   // 照片绘制区域的顶部 y
  photoX: number = 0;
  photoW: number = 0;
  photoH: number = 0;
  lines: string[] = [];
}

function hexToArgb(hex: string): number {
  let s = hex.replace('#', '');
  if (s.length === 6) {
    s = `FF${s}`;
  }
  const v = parseInt(s, 16);
  return isNaN(v) ? 0xFF000000 : v;
}

/** 参与排版的文字行（含标题行） */
export function buildLines(frame: FrameConfig, exif: ExifInfo | null): string[] {
  const lines: string[] = [];
  if (frame.showTitle && frame.title.trim() !== '') {
    lines.push(frame.title.trim());
  }
  const items1: string[] = [];
  if (exif !== null) {
    if (frame.showAperture) {
      items1.push(exif.aperture);
    }
    if (frame.showShutter) {
      items1.push(exif.shutter);
    }
    if (frame.showIso) {
      items1.push(exif.iso);
    }
    if (frame.showCamera) {
      items1.push(exif.camera);
    }
  }
  const line1 = items1.filter(s => s !== '').join(' · ');
  if (line1 !== '') {
    lines.push(line1);
  }
  const items2: string[] = [];
  if (exif !== null) {
    if (frame.showFocal) {
      items2.push(exif.focal);
    }
    if (frame.showTime) {
      items2.push(exif.dateStr);
    }
    if (frame.showGps) {
      items2.push(exif.gpsStr);
    }
  }
  const line2 = items2.filter(s => s !== '').join(' · ');
  if (line2 !== '') {
    lines.push(line2);
  }
  return lines;
}

export function computeLayout(frame: FrameConfig, exif: ExifInfo | null, pw: number, ph: number): FrameLayout {
  const lay = new FrameLayout();
  const minDim = Math.min(pw, ph);
  lay.m = Math.round(frame.borderRatio * minDim);
  lay.fontPx = Math.max(8, frame.fontSize * minDim);
  const gap = lay.fontPx * 0.7;
  const lh = lay.fontPx * 1.5;
  lay.lines = buildLines(frame, exif);
  const band = lay.lines.length > 0 ? gap + lay.fontPx * 0.8 + lh * (lay.lines.length - 1) + gap : 0;
  lay.photoW = pw;
  lay.photoH = ph;
  lay.photoX = lay.m;
  lay.photoTop = frame.pos === 'top' ? lay.m + band : lay.m;
  lay.outW = pw + 2 * lay.m;
  lay.outH = ph + 2 * lay.m + band;
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
  canvas.clear(hexToArgb(frame.bg));
  const dst: common2D.Rect = { left: lay.photoX, top: lay.photoTop, right: lay.photoX + lay.photoW, bottom: lay.photoTop + lay.photoH };
  canvas.drawImageRect(pm, dst, new drawing.SamplingOptions(drawing.FilterMode.FILTER_MODE_LINEAR));

  if (lay.lines.length > 0) {
    const font = new drawing.Font();
    font.setSize(lay.fontPx);
    const brush = new drawing.Brush();
    brush.setColor(hexToArgb(frame.textColor));
    canvas.attachBrush(brush);
    const gap = lay.fontPx * 0.7;
    const lh = lay.fontPx * 1.5;
    const baseY = frame.pos === 'top' ? lay.m : lay.photoTop + lay.photoH + gap;
    for (let i = 0; i < lay.lines.length; i++) {
      const blob = drawing.TextBlob.makeFromString(lay.lines[i], font);
      const b = blob.bounds();
      const w = Math.max(0, b.right - b.left);
      let x = lay.photoX;
      if (frame.align === 'center') {
        x = (lay.outW - w) / 2;
      } else if (frame.align === 'right') {
        x = lay.outW - lay.m - w;
      }
      const y = baseY + lay.fontPx * 0.8 + lh * i;
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

/**
 * 编辑页保存：frame 为 null 时原始照片直接存回相册，否则渲染相框后保存。
 * 返回用户确认保存的数量。
 */
export async function exportPhoto(ctx: common.Context, uri: string, frame: FrameConfig | null): Promise<number> {
  const files: string[] = [];
  if (frame === null) {
    const path = `${ctx.cacheDir}/framed_${Date.now()}_orig.jpg`;
    fs.copyFileSync(uri, path);
    files.push(fileUri.getUriFromPath(path));
  } else {
    files.push(await renderOne(ctx, uri, frame, 0));
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
