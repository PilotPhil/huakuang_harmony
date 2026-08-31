import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'huakuang_store';
const KEY_LOG = 'process_log';

/** 一条处理记录：照片 + 处理日期 */
export class LogEntry {
  uri: string = '';
  date: string = '';      // 例：2026年8月30日
  ts: number = 0;         // 处理时间戳，用于排序
  processed: boolean = false; // 是否已导出过（已加框保存）
}

/** 图库中的日期分组 */
export class DateGroup {
  label: string = '';
  count: number = 0;
  items: LogEntry[] = [];
}

function store(ctx: common.Context): preferences.Preferences {
  return preferences.getPreferencesSync(ctx, { name: STORE_NAME });
}

export function dateLabelOf(ts: number): string {
  const d = new Date(ts);
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
}

export function loadLog(ctx: common.Context): LogEntry[] {
  try {
    const raw = store(ctx).getSync(KEY_LOG, '[]') as string;
    const arr = JSON.parse(raw) as LogEntry[];
    const out: LogEntry[] = [];
    for (const item of arr) {
      const e = new LogEntry();
      e.uri = item.uri;
      e.date = item.date;
      e.ts = item.ts;
      e.processed = item.processed;
      out.push(e);
    }
    out.sort((a: LogEntry, b: LogEntry) => b.ts - a.ts);
    return out;
  } catch (err) {
    return [];
  }
}

function persist(ctx: common.Context, entries: LogEntry[]): void {
  try {
    const pref = store(ctx);
    pref.putSync(KEY_LOG, JSON.stringify(entries));
    pref.flush();
  } catch (err) {
    // 忽略持久化失败
  }
}

/** 新增一条（去重），并刷新 AppStorage 版本号驱动图库刷新 */
export function addLog(ctx: common.Context, uri: string): void {
  const entries = loadLog(ctx);
  if (entries.some(e => e.uri === uri)) {
    return;
  }
  const ts = Date.now();
  const e = new LogEntry();
  e.uri = uri;
  e.date = dateLabelOf(ts);
  e.ts = ts;
  entries.unshift(e);
  persist(ctx, entries);
  bumpVersion();
}

/** 标记某张已处理（加框保存成功） */
export function markProcessed(ctx: common.Context, uri: string): void {
  const entries = loadLog(ctx);
  let changed = false;
  for (const e of entries) {
    if (e.uri === uri && !e.processed) {
      e.processed = true;
      changed = true;
    }
  }
  if (changed) {
    persist(ctx, entries);
    bumpVersion();
  }
}

export function removeLog(ctx: common.Context, uri: string): void {
  const entries = loadLog(ctx).filter(e => e.uri !== uri);
  persist(ctx, entries);
  bumpVersion();
}

function bumpVersion(): void {
  const v = AppStorage.get<number>('logVersion');
  AppStorage.setOrCreate('logVersion', v !== undefined ? v + 1 : 1);
}

/** 按日期分组（输入已按时间倒序） */
export function buildGroups(entries: LogEntry[]): DateGroup[] {
  const map = new Map<string, LogEntry[]>();
  for (const e of entries) {
    let list = map.get(e.date);
    if (list === undefined) {
      list = [];
      map.set(e.date, list);
    }
    list.push(e);
  }
  const groups: DateGroup[] = [];
  for (const e of entries) {
    if (groups.length > 0 && groups[groups.length - 1].label === e.date) {
      continue;
    }
    const g = new DateGroup();
    g.label = e.date;
    g.items = map.get(e.date) as LogEntry[];
    g.count = g.items.length;
    groups.push(g);
  }
  return groups;
}
