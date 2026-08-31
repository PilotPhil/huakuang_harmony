import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameConfig } from '../model/FrameConfig';
import { LogEntry, DateGroup, loadLog, addLog, removeLog, buildGroups } from '../model/ProcessLog';
import { EditParam } from './PhotoEditPage';

/**
 * 图库页（设计稿 pic/5）：按日期分组展示处理记录，白色圆角卡片网格，
 * 双指捏合调整列数（1~5），点击卡片进入相框编辑页。
 */
@Component
export struct GalleryTab {
  pathStack: NavPathStack | null = null;
  @Link customFrames: FrameConfig[];
  @State groups: DateGroup[] = [];
  @State cols: number = 3;
  @State startCols: number = 3;
  @State pageW: number = 360;
  @StorageLink('logVersion') @Watch('onLogChanged') logVersion: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  onLogChanged(): void {
    this.reload();
  }

  private reload(): void {
    this.groups = buildGroups(loadLog(getContext(this) as common.Context));
  }

  private gap(): number {
    return 10;
  }

  /** 卡片边长（正方形） */
  private cellW(): number {
    const pad = 18;
    return (this.pageW - pad * 2 - (this.cols - 1) * this.gap()) / this.cols;
  }

  private groupH(n: number): number {
    const rows = Math.ceil(n / this.cols);
    return rows * this.cellW() + (rows - 1) * this.gap();
  }

  private tmpl(): string {
    let s = '';
    for (let i = 0; i < this.cols; i++) {
      s += '1fr ';
    }
    return s.trim();
  }

  async pickPhotos() {
    try {
      const opt = new photoAccessHelper.PhotoSelectOptions();
      opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 100;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(opt);
      const ctx = getContext(this) as common.Context;
      for (const uri of result.photoUris) {
        addLog(ctx, uri);
      }
    } catch (err) {
      const e = err as BusinessError;
      if (e.code !== 13900042 && e.code !== 13900051) { // 用户取消
        promptAction.showToast({ message: `选择失败：${e.message}` });
      }
    }
  }

  openPhoto(item: LogEntry) {
    // 读取图片尺寸与 EXIF 需要 PhotoItem，这里从记录进入时异步构建
    if (this.pathStack !== null) {
      // PhotoEditPage 需要 PhotoItem，构造一个仅含 uri 的占位，页面内再加载信息
      this.pushEdit(item.uri);
    }
  }

  private pushEdit(uri: string) {
    if (this.pathStack !== null) {
      this.pathStack.pushPathByName('PhotoEdit', new EditParam(uri, this.customFrames), true);
    }
  }

  confirmRemove(item: LogEntry) {
    AlertDialog.show({
      title: '移除照片',
      message: '从图库记录中移除这张照片？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: '#D94838',
        action: () => {
          removeLog(getContext(this) as common.Context, item.uri);
        }
      }
    });
  }

  @Builder
  Card(item: LogEntry) {
    GridItem() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Image(item.uri)
          .width(this.cellW())
          .height(this.cellW())
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
        if (!item.processed) {
          Text('未处理')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#80000000')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(8)
            .margin(6)
        }
      }
      .onClick(() => this.pushEdit(item.uri))
      .gesture(
        LongPressGesture()
          .onAction(() => this.confirmRemove(item))
      )
    }
  }

  @Builder
  GroupSection(g: DateGroup) {
    Column() {
      Row() {
        Text(g.label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        Blank()
        Text(`${g.count}张`)
          .fontSize(14)
          .fontColor('#888888')
      }
      .width('100%')
      .padding({ top: 22, bottom: 12 })

      Grid() {
        ForEach(g.items, (item: LogEntry) => {
          this.Card(item)
        }, (item: LogEntry) => item.uri)
      }
      .columnsTemplate(this.tmpl())
      .columnsGap(this.gap())
      .rowsGap(this.gap())
      .height(this.groupH(g.items.length))
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        // 顶栏：标题 + 圆形添加按钮
        Row() {
          Text('图库')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111111')
          Blank()
          Column() {
            SymbolGlyph($r('sys.symbol.circle_dashed'))
              .fontSize(22)
              .fontColor(['#555555'])
          }
          .width(46)
          .height(46)
          .borderRadius(23)
          .backgroundColor(Color.White)
          .justifyContent(FlexAlign.Center)
          .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
          .onClick(() => this.pickPhotos())
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 10 })

        // 日期分组网格
        if (this.groups.length > 0) {
          Scroll() {
            Column() {
              ForEach(this.groups, (g: DateGroup) => {
                this.GroupSection(g)
              }, (g: DateGroup) => g.label)
            }
            .padding({ left: 18, right: 18, bottom: 104 })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .gesture(
            PinchGesture({ fingers: 2 })
              .onActionStart(() => {
                this.startCols = this.cols;
              })
              .onActionUpdate((e: GestureEvent) => {
                const c = Math.max(1, Math.min(5, Math.round(this.startCols / e.scale)));
                if (c !== this.cols) {
                  this.cols = c;
                }
              })
          )
        } else {
          Column({ space: 14 }) {
            Column() {
              Text('＋')
                .fontSize(34)
                .fontColor('#0A59F7')
            }
            .width(64)
            .height(64)
            .borderRadius(32)
            .border({ width: 1, color: '#CCCCCC', style: BorderStyle.Dashed })
            .justifyContent(FlexAlign.Center)
            .onClick(() => this.pickPhotos())
            Text('还没有处理的照片')
              .fontSize(15)
              .fontColor('#666666')
            Text('点右上角或上方按钮，从相册选择照片开始')
              .fontSize(12)
              .fontColor('#AAAAAA')
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((oldV: Area, newV: Area) => {
        this.pageW = newV.width as number;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F2')
  }
}
