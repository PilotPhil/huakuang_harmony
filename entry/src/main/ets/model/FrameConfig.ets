import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const STORE_NAME = 'huakuang_store';
const KEY_FRAMES = 'custom_frames';
const KEY_LOGIN = 'logged_in';

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
  borderRatio: number = 0.05;   // 边距 = ratio * min(照片宽,高)
  fontSize: number = 0.030;     // 字号 = fontSize * min(照片宽,高)
  align: string = 'center';     // left | center | right
  pos: string = 'bottom';       // top | bottom
  showAperture: boolean = true;
  showShutter: boolean = true;
  showIso: boolean = true;
  showFocal: boolean = true;
  showCamera: boolean = false;
  showTime: boolean = true;
  showGps: boolean = false;
  showTitle: boolean = false;
  title: string = '';

  /** 用 src 覆盖自身（保留引用，供 @ObjectLink 观察） */
  copyFrom(src: FrameConfig): void {
    this.id = src.id;
    this.name = src.name;
    this.bg = src.bg;
    this.textColor = src.textColor;
    this.borderRatio = src.borderRatio;
    this.fontSize = src.fontSize;
    this.align = src.align;
    this.pos = src.pos;
    this.showAperture = src.showAperture;
    this.showShutter = src.showShutter;
    this.showIso = src.showIso;
    this.showFocal = src.showFocal;
    this.showCamera = src.showCamera;
    this.showTime = src.showTime;
    this.showGps = src.showGps;
    this.showTitle = src.showTitle;
    this.title = src.title;
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
  f.pos = pos;
  f.showGps = gps;
  f.showTitle = title.length > 0;
  f.title = title;
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
