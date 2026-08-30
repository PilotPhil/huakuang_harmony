import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';

/** 从照片中读出的信息 */
export class ExifInfo {
  aperture: string = '';   // f/1.8
  shutter: string = '';    // 1/125s
  iso: string = '';        // ISO100
  focal: string = '';      // 24mm
  camera: string = '';     // 机型
  dateStr: string = '';    // 2024-05-01 12:34
  gpsStr: string = '';     // 31°13′N 121°28′E
}

export class PhotoItem {
  uri: string = '';
  width: number = 0;
  height: number = 0;
  exif: ExifInfo | null = null;
}

async function prop(src: image.ImageSource, key: image.PropertyKey): Promise<string> {
  try {
    return await src.getImageProperty(key);
  } catch (err) {
    return '';
  }
}

function rationalToNumber(s: string): number {
  const parts = s.split('/');
  if (parts.length === 2) {
    const a = parseFloat(parts[0]);
    const b = parseFloat(parts[1]);
    return b !== 0 ? a / b : NaN;
  }
  return parseFloat(s);
}

function trimNum(n: number): string {
  if (isNaN(n) || !isFinite(n)) {
    return '';
  }
  if (Math.abs(n) >= 100) {
    return String(Math.round(n));
  }
  return String(Math.round(n * 10) / 10);
}

function formatShutter(raw: string): string {
  if (raw === '') {
    return '';
  }
  const clean = raw.replace(' sec.', '').replace('sec', 's');
  if (clean.indexOf('/') >= 0) {
    return `${clean}s`;
  }
  const v = parseFloat(clean);
  if (isNaN(v)) {
    return `${clean}s`;
  }
  if (v < 1) {
    const inv = Math.round(1 / v);
    return inv > 0 ? `1/${inv}s` : `${clean}s`;
  }
  return `${Math.round(v * 10) / 10}s`;
}

function formatAperture(raw: string): string {
  const n = rationalToNumber(raw);
  return isNaN(n) ? '' : `f/${trimNum(n)}`;
}

function formatIso(raw: string): string {
  return raw !== '' ? `ISO${raw}` : '';
}

function formatFocal(raw: string): string {
  const n = rationalToNumber(raw);
  return isNaN(n) ? '' : `${trimNum(n)}mm`;
}

function formatDate(raw: string): string {
  if (raw === '') {
    return '';
  }
  const parts = raw.split(' ');
  if (parts.length < 2) {
    return raw;
  }
  return `${parts[0].replaceAll(':', '-')} ${parts[1].substring(0, 5)}`;
}

function formatDms(raw: string, ref: string, hemi1: string, hemi2: string): string {
  const parts = raw.split(',');
  if (parts.length < 3) {
    return '';
  }
  const d = parseFloat(parts[0]);
  const m = parseFloat(parts[1]);
  const s = parseFloat(parts[2]);
  if (isNaN(d) || isNaN(m) || isNaN(s)) {
    return '';
  }
  const hemi = ref === hemi1 ? hemi1 : hemi2;
  return `${Math.round(d)}°${String(Math.round(m)).padStart(2, '0')}′${String(Math.round(s)).padStart(2, '0')}″${hemi}`;
}

function formatGps(rawLat: string, refLat: string, rawLon: string, refLon: string): string {
  const lat = formatDms(rawLat, refLat, 'N', 'S');
  const lon = formatDms(rawLon, refLon, 'E', 'W');
  if (lat === '' || lon === '') {
    return '';
  }
  return `${lat} ${lon}`;
}

export async function readExif(src: image.ImageSource): Promise<ExifInfo> {
  const info = new ExifInfo();
  const rawAperture = await prop(src, image.PropertyKey.F_NUMBER);
  const rawShutter = await prop(src, image.PropertyKey.EXPOSURE_TIME);
  const rawIso = await prop(src, image.PropertyKey.ISO_SPEED_RATINGS);
  const rawFocal = await prop(src, image.PropertyKey.FOCAL_LENGTH);
  const make = await prop(src, image.PropertyKey.MAKE);
  const model = await prop(src, image.PropertyKey.MODEL);
  const rawDate = await prop(src, image.PropertyKey.DATE_TIME_ORIGINAL);
  const rawLat = await prop(src, image.PropertyKey.GPS_LATITUDE);
  const refLat = await prop(src, image.PropertyKey.GPS_LATITUDE_REF);
  const rawLon = await prop(src, image.PropertyKey.GPS_LONGITUDE);
  const refLon = await prop(src, image.PropertyKey.GPS_LONGITUDE_REF);

  info.aperture = formatAperture(rawAperture);
  info.shutter = formatShutter(rawShutter);
  info.iso = formatIso(rawIso);
  info.focal = formatFocal(rawFocal);
  info.camera = model !== '' ? model : make;
  info.dateStr = formatDate(rawDate);
  info.gpsStr = formatGps(rawLat, refLat, rawLon, refLon);
  return info;
}

/** 读取选中照片的尺寸与 EXIF（相册 URI 需先经 fs 打开取得 fd） */
export async function makePhotoItem(uri: string): Promise<PhotoItem> {
  const item = new PhotoItem();
  item.uri = uri;
  const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  const src = image.createImageSource(file.fd);
  try {
    const info = await src.getImageInfo();
    item.width = info.size.width;
    item.height = info.size.height;
    item.exif = await readExif(src);
  } finally {
    src.release();
    fs.closeSync(file.fd);
  }
  return item;
}
