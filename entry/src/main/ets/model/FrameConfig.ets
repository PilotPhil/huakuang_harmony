import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const STORE_NAME = 'huakuang_store';
const KEY_FRAMES = 'custom_frames';
const KEY_LOGIN = 'logged_in';

/** 相框中可独立选择与排版的元素。位置为相框归一化坐标。 */
@Observed
export class FrameElement {
  id: string = '';
  label: string = '';
  enabled: boolean = false;
  x: number = 0.5;
  y: number = -1;
  manual: boolean = false;
  fontSize: number = 0.030;
  color: string = '#1A1A1A';
  bold: boolean = false;
  /** 手动排版时是否允许元素进入照片区域。 */
  allowInsidePhoto: boolean = false;
  /** logo 元素使用的内置品牌 key；custom 时配合 logoUri 使用。 */
  logoKey: string = '';
  /** 用户从系统图库选择的自定义 logo URI。 */
  logoUri: string = '';
}

export function buildFrameElements(): FrameElement[] {
  const ids: string[] = ['title', 'aperture', 'shutter', 'iso', 'focal', 'camera', 'time', 'gps', 'logo'];
  const labels: string[] = ['自定义文字', '光圈', '快门', 'ISO', '焦距', '相机型号', '拍摄时间', '经纬度', '相机 Logo'];
  const out: FrameElement[] = [];
  for (let i = 0; i < ids.length; i++) {
    const e = new FrameElement();
    e.id = ids[i];
    e.label = labels[i];
    e.enabled = ['aperture', 'shutter', 'iso', 'focal', 'time'].indexOf(e.id) >= 0;
    out.push(e);
  }
  return out;
}

/**
 * 相框配置：边框颜色/厚度、文字颜色/字号、显示哪些曝光要素、对齐方式等。
 * 全部为原始类型字段，配合 @Observed 做深度刷新。
 */
@Observed
export class FrameConfig {
  id: string = 'preset_minimal';
  name: string = '极简白';
  bg: string = '#FFFFFF';       // 相框底色
  textColor: string = '#1A1A1A';
  borderRatio: number = 0.05;   // 旧配置兼容字段，默认同步上/左/右白边
  fontSize: number = 0.030;     // 字号 = fontSize * min(照片宽,高)
  align: string = 'center';     // left | center | right
  /** 信息带内的排列方向：vertical | horizontal。 */
  infoLayout: string = 'vertical';
  pos: string = 'bottom';       // top | bottom
  showAperture: boolean = true;
  showShutter: boolean = true;
  showIso: boolean = true;
  showFocal: boolean = true;
  showCamera: boolean = false;
  showTime: boolean = true;
  showGps: boolean = false;
  showTitle: boolean = false;
  showLogo: boolean = false;
  title: string = '';
  textAreaRatio: number = 1.0; // 文字区域相对照片宽度
  /** 上、左、右三边白边宽度，按照片短边比例。 */
  borderSideRatio: number = 0.05;
  /** 下方白边宽度，按照片短边比例。 */
  borderBottomRatio: number = 0.05;
  /** 相框底色透明度，0~1。 */
  opacity: number = 1.0;
  /** 相框视觉效果：none | immersive | transparent | frosted | gaussian。 */
  effect: string = 'none';
  elements: FrameElement[] = buildFrameElements();

  /** 用 src 覆盖自身（保留引用，供 @ObjectLink 观察） */
  copyFrom(src: FrameConfig): void {
    this.id = src.id;
    this.name = src.name;
    this.bg = src.bg;
    this.textColor = src.textColor;
    this.borderRatio = src.borderRatio;
    this.fontSize = src.fontSize;
    this.align = src.align;
    this.infoLayout = src.infoLayout === 'horizontal' ? 'horizontal' : 'vertical';
    this.pos = src.pos;
    this.showAperture = src.showAperture;
    this.showShutter = src.showShutter;
    this.showIso = src.showIso;
    this.showFocal = src.showFocal;
    this.showCamera = src.showCamera;
    this.showTime = src.showTime;
    this.showGps = src.showGps;
    this.showTitle = src.showTitle;
    this.showLogo = src.showLogo === true;
    this.title = src.title;
    this.textAreaRatio = src.textAreaRatio !== undefined ? src.textAreaRatio : 1.0;
    this.borderSideRatio = src.borderSideRatio !== undefined
      ? Math.max(0, Math.min(0.3, src.borderSideRatio))
      : Math.max(0, Math.min(0.3, src.borderRatio));
    this.borderBottomRatio = src.borderBottomRatio !== undefined
      ? Math.max(0, Math.min(0.3, src.borderBottomRatio))
      : Math.max(0, Math.min(0.3, src.borderRatio));
    this.opacity = src.opacity !== undefined ? Math.max(0, Math.min(1, src.opacity)) : 1.0;
    this.effect = src.effect !== undefined && src.effect !== '' ? src.effect : 'none';
    this.elements = [];
    if (src.elements !== undefined && src.elements.length > 0) {
      for (const item of src.elements) {
        const e = new FrameElement();
        e.id = item.id;
        e.label = item.label;
        e.enabled = item.enabled;
        e.x = item.x;
        e.y = item.y;
        e.manual = item.manual === true;
        e.fontSize = item.fontSize > 0 ? item.fontSize : this.fontSize;
        e.color = item.color !== '' ? item.color : this.textColor;
        e.bold = item.bold === true;
        e.allowInsidePhoto = item.allowInsidePhoto === true;
        e.logoKey = item.logoKey !== undefined ? item.logoKey : '';
        e.logoUri = item.logoUri !== undefined ? item.logoUri : '';
        this.elements.push(e);
      }
      let hasLogo = false;
      for (const item of this.elements) {
        if (item.id === 'logo') {
          hasLogo = true;
          break;
        }
      }
      if (!hasLogo) {
        const logo = new FrameElement();
        logo.id = 'logo';
        logo.label = '相机 Logo';
        this.elements.push(logo);
      }
    } else {
      this.elements = buildFrameElements();
    }
    this.syncElements();
  }

  /** 兼容旧配置，同时把总开关同步到独立元素。 */
  syncElements(): void {
    for (const e of this.elements) {
      if (e.id === 'title') {
        e.enabled = this.showTitle;
      } else if (e.id === 'aperture') {
        e.enabled = this.showAperture;
      } else if (e.id === 'shutter') {
        e.enabled = this.showShutter;
      } else if (e.id === 'iso') {
        e.enabled = this.showIso;
      } else if (e.id === 'focal') {
        e.enabled = this.showFocal;
      } else if (e.id === 'camera') {
        e.enabled = this.showCamera;
      } else if (e.id === 'time') {
        e.enabled = this.showTime;
      } else if (e.id === 'gps') {
        e.enabled = this.showGps;
      } else if (e.id === 'logo') {
        e.enabled = this.showLogo;
      }
      if (e.fontSize <= 0) {
        e.fontSize = this.fontSize;
      }
      if (e.color === '') {
        e.color = this.textColor;
      }
    }
  }

  toJSON(): string {
    return JSON.stringify(this);
  }
}

function preset(id: string, name: string, bg: string, textColor: string,
  borderRatio: number, fontSize: number, align: string, pos: string,
  gps: boolean, title: string): FrameConfig {
  const f = new FrameConfig();
  f.id = id;
  f.name = name;
  f.bg = bg;
  f.textColor = textColor;
  f.borderRatio = borderRatio;
  f.fontSize = fontSize;
  f.align = align;
  f.infoLayout = 'vertical';
  f.pos = pos;
  f.borderSideRatio = borderRatio;
  f.borderBottomRatio = borderRatio;
  f.showGps = gps;
  f.showTitle = title.length > 0;
  f.title = title;
  f.syncElements();
  return f;
}

/** 内置相框预设 */
export function buildPresets(): FrameConfig[] {
  const list: FrameConfig[] = [];
  list.push(preset('preset_minimal', '极简白', '#FFFFFF', '#1A1A1A', 0.05, 0.030, 'center', 'bottom', false, ''));
  list.push(preset('preset_black', '经典黑', '#121212', '#F5F5F5', 0.06, 0.032, 'center', 'bottom', false, ''));
  list.push(preset('preset_magazine', '杂志', '#F5F1E8', '#26221B', 0.07, 0.034, 'left', 'bottom', true, 'MOMENT'));
  list.push(preset('preset_film', '胶片', '#EFEBE3', '#8A5A2B', 0.08, 0.033, 'left', 'top', true, ''));
  list.push(preset('preset_night', '暗夜', '#101725', '#A8C6E8', 0.055, 0.030, 'right', 'bottom', false, 'PHOTOGRAPHY'));
  return list;
}

function store(ctx: common.Context): preferences.Preferences {
  return preferences.getPreferencesSync(ctx, { name: STORE_NAME });
}

/** 从 JSON 字符串恢复 FrameConfig（来自用户保存的设计） */
function fromJson(text: string): FrameConfig {
  const f = new FrameConfig();
  const obj = JSON.parse(text) as FrameConfig;
  f.copyFrom(obj);
  return f;
}

export function loadCustomFrames(ctx: common.Context): FrameConfig[] {
  try {
    const raw = store(ctx).getSync(KEY_FRAMES, '[]') as string;
    const arr = JSON.parse(raw) as FrameConfig[];
    const out: FrameConfig[] = [];
    for (const item of arr) {
      const f = new FrameConfig();
      f.copyFrom(item);
      out.push(f);
    }
    return out;
  } catch (err) {
    return [];
  }
}

export function saveCustomFrames(ctx: common.Context, frames: FrameConfig[]): void {
  try {
    const pref = store(ctx);
    pref.putSync(KEY_FRAMES, JSON.stringify(frames));
    pref.flush();
  } catch (err) {
    // 忽略持久化失败
  }
}

export function loadLogin(ctx: common.Context): boolean {
  try {
    return store(ctx).getSync(KEY_LOGIN, false) as boolean;
  } catch (err) {
    return false;
  }
}

export function saveLogin(ctx: common.Context, logged: boolean): void {
  try {
    const pref = store(ctx);
    pref.putSync(KEY_LOGIN, logged);
    pref.flush();
  } catch (err) {
    // 忽略持久化失败
  }
}

/** 颜色选择器可选值 */
export const BG_COLORS: string[] = ['#FFFFFF', '#121212', '#F5F1E8', '#EFEBE3', '#101725', '#2E3A2F', '#A63A3A', '#3B4A5E'];
export const TEXT_COLORS: string[] = ['#1A1A1A', '#F5F5F5', '#8A5A2B', '#A8C6E8', '#F5D76E', '#D9C9A3', '#4E7B4E', '#333333'];

/** 可随应用离线使用的常见相机品牌 Logo；资源已随应用打包，不依赖运行时网络。 */
export class CameraLogoOption {
  key: string = '';
  label: string = '';

  constructor(key: string, label: string) {
    this.key = key;
    this.label = label;
  }
}

export const CAMERA_LOGOS: CameraLogoOption[] = [
  new CameraLogoOption('canon', 'Canon'),
  new CameraLogoOption('nikon', 'Nikon'),
  new CameraLogoOption('sony', 'Sony'),
  new CameraLogoOption('fujifilm', 'Fujifilm'),
  new CameraLogoOption('leica', 'Leica'),
  new CameraLogoOption('panasonic', 'Panasonic'),
  new CameraLogoOption('dji', 'DJI'),
  new CameraLogoOption('kodak', 'Kodak')
];

/** 将 Logo key 映射为打包在应用内的媒体资源。 */
export function logoResource(key: string): Resource | null {
  if (key === 'canon') return $r('app.media.logo_canon');
  if (key === 'nikon') return $r('app.media.logo_nikon');
  if (key === 'sony') return $r('app.media.logo_sony');
  if (key === 'fujifilm') return $r('app.media.logo_fujifilm');
  if (key === 'leica') return $r('app.media.logo_leica');
  if (key === 'panasonic') return $r('app.media.logo_panasonic');
  if (key === 'dji') return $r('app.media.logo_dji');
  if (key === 'kodak') return $r('app.media.logo_kodak');
  return null;
}
