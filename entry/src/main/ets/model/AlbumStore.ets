import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'huakuang_store';
const KEY_ALBUMS = 'albums';

/** 相册内一张照片记录 */
export class PhotoRec {
  uri: string = '';
  ts: number = 0;          // 导入时间戳
  processed: boolean = false; // 是否已加框处理过
}

/** 一个相册 */
export class Album {
  id: string = '';
  name: string = '';
  ts: number = 0;          // 创建时间
  photos: PhotoRec[] = [];
}

function store(ctx: common.Context): preferences.Preferences {
  return preferences.getPreferencesSync(ctx, { name: STORE_NAME });
}

export function loadAlbums(ctx: common.Context): Album[] {
  try {
    const raw = store(ctx).getSync(KEY_ALBUMS, '[]') as string;
    const arr = JSON.parse(raw) as Album[];
    const out: Album[] = [];
    for (const a of arr) {
      const album = new Album();
      album.id = a.id;
      album.name = a.name;
      album.ts = a.ts;
      album.photos = [];
      for (const p of a.photos) {
        const rec = new PhotoRec();
        rec.uri = p.uri;
        rec.ts = p.ts;
        rec.processed = p.processed;
        album.photos.push(rec);
      }
      out.push(album);
    }
    out.sort((a: Album, b: Album) => b.ts - a.ts);
    return out;
  } catch (err) {
    return [];
  }
}

function persist(ctx: common.Context, albums: Album[]): void {
  try {
    const pref = store(ctx);
    pref.putSync(KEY_ALBUMS, JSON.stringify(albums));
    pref.flush();
  } catch (err) {
    // 忽略持久化失败
  }
}

function bumpVersion(): void {
  const v = AppStorage.get<number>('albumVersion');
  AppStorage.setOrCreate('albumVersion', v !== undefined ? v + 1 : 1);
}

/** 新建相册并持久化 */
export function createAlbum(ctx: common.Context, name: string): Album {
  const albums = loadAlbums(ctx);
  const a = new Album();
  a.id = `album_${Date.now()}`;
  a.name = name;
  a.ts = Date.now();
  albums.unshift(a);
  persist(ctx, albums);
  bumpVersion();
  return a;
}

/** 向相册导入若干照片（按 uri 去重） */
export function addPhotosToAlbum(ctx: common.Context, albumId: string, uris: string[]): void {
  const albums = loadAlbums(ctx);
  const album = albums.find((a: Album) => a.id === albumId);
  if (album === undefined) {
    return;
  }
  for (const uri of uris) {
    if (album.photos.some(p => p.uri === uri)) {
      continue;
    }
    const rec = new PhotoRec();
    rec.uri = uri;
    rec.ts = Date.now();
    album.photos.push(rec);
  }
  persist(ctx, albums);
  bumpVersion();
}

/** 标记某张已处理 */
export function markProcessed(ctx: common.Context, albumId: string, uri: string): void {
  const albums = loadAlbums(ctx);
  let changed = false;
  for (const a of albums) {
    if (albumId !== '' && a.id !== albumId) {
      continue;
    }
    for (const p of a.photos) {
      if (p.uri === uri && !p.processed) {
        p.processed = true;
        changed = true;
      }
    }
  }
  if (changed) {
    persist(ctx, albums);
    bumpVersion();
  }
}

/** 从相册移除一张 */
export function removePhoto(ctx: common.Context, albumId: string, uri: string): void {
  const albums = loadAlbums(ctx);
  for (const a of albums) {
    if (a.id !== albumId) {
      continue;
    }
    a.photos = a.photos.filter((p: PhotoRec) => p.uri !== uri);
  }
  persist(ctx, albums);
  bumpVersion();
}

/** 删除整个相册 */
export function removeAlbum(ctx: common.Context, albumId: string): void {
  const albums = loadAlbums(ctx).filter((a: Album) => a.id !== albumId);
  persist(ctx, albums);
  bumpVersion();
}
