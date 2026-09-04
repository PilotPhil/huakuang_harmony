import { common } from '@kit.AbilityKit';
import { FrameConfig, buildPresets, saveCustomFrames } from '../model/FrameConfig';
import { FramePreview } from './FramePreview';
import { FrameDesignParam } from './FrameDesignPage';

/** 相框管理页：分开展示内置模板与用户设计。 */
@Component
export struct DesignTab {
  @ObjectLink frame: FrameConfig;
  @Link customFrames: FrameConfig[];
  @State section: number = 0;
  @State pageW: number = 360;
  pathStack: NavPathStack | null = null;
  presets: FrameConfig[] = buildPresets();

  private cardW(): number {
    return (this.pageW - 44) / 2;
  }

  private openDesigner(frameId: string = ''): void {
    if (this.pathStack !== null) {
      this.pathStack.pushPathByName('FrameDesign', new FrameDesignParam(frameId), true);
    }
  }

  private confirmDelete(f: FrameConfig): void {
    AlertDialog.show({
      title: '删除相框',
      message: `确定删除「${f.name}」吗？`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#D94838',
        action: () => {
          const index = this.customFrames.indexOf(f);
          if (index >= 0) {
            this.customFrames.splice(index, 1);
            saveCustomFrames(getContext(this) as common.Context, this.customFrames);
          }
        }
      }
    });
  }

  build() {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text('相框设计')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_strong'))
          Text('管理模板，创建自己的照片边框')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.section === 1) {
          Button('新增设计', { type: ButtonType.Capsule })
            .height(40)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#0A59F7')
            .onClick(() => this.openDesigner())
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 14 })

      Row() {
        this.SectionTab(0, '内置模板', this.presets.length)
        this.SectionTab(1, '我的相框', this.customFrames.length)
      }
      .width('100%')
      .height(52)
      .padding({ left: 18, right: 18 })
      .backgroundColor($r('app.color.surface_secondary'))

      if (this.section === 1 && this.customFrames.length === 0) {
        Column({ space: 14 }) {
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.square_and_pencil'))
              .fontSize(34)
              .fontColor(['#0A59F7'])
          }
          .width(66)
          .height(66)
          .borderRadius(33)
          .backgroundColor($r('app.color.blue_tint'))
          Text('还没有自定义相框')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text('从颜色、边距、排版和照片信息开始设计')
            .fontSize(13)
            .fontColor($r('app.color.text_tertiary'))
          Button('新增设计', { type: ButtonType.Capsule })
            .margin({ top: 4 })
            .backgroundColor('#0A59F7')
            .onClick(() => this.openDesigner())
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 100 })
      } else {
        Grid() {
          if (this.section === 0) {
            ForEach(this.presets, (f: FrameConfig) => {
              this.FrameCard(f, false)
            }, (f: FrameConfig) => f.id)
          } else {
            ForEach(this.customFrames, (f: FrameConfig) => {
              this.FrameCard(f, true)
            }, (f: FrameConfig) => f.id)
          }
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 118 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.pageW = newValue.width as number;
    })
  }

  @Builder
  SectionTab(index: number, label: string, count: number) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(label)
          .fontSize(15)
          .fontWeight(this.section === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.section === index ? '#0A59F7' : $r('app.color.text_secondary'))
        Text(`${count}`)
          .fontSize(10)
          .fontColor(this.section === index ? '#0A59F7' : $r('app.color.text_tertiary'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor(this.section === index ? $r('app.color.blue_tint_strong') :
            $r('app.color.surface_tertiary'))
      }
      Column() {
      }
      .width('72%')
      .height(3)
      .borderRadius(2)
      .backgroundColor(this.section === index ? '#0A59F7' : '#00FFFFFF')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.End)
    .onClick(() => this.section = index)
  }

  @Builder
  FrameCard(f: FrameConfig, editable: boolean) {
    GridItem() {
      Column({ space: 10 }) {
        Row() {
          Text(f.name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (editable) {
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(16)
                .fontColor(['#D94838'])
            }
            .width(30)
            .height(30)
            .borderRadius(15)
            .backgroundColor($r('app.color.red_tint'))
            .onClick(() => this.confirmDelete(f))
          } else {
            Text('内置')
              .fontSize(10)
              .fontColor($r('app.color.text_secondary'))
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .borderRadius(8)
              .backgroundColor($r('app.color.surface_tertiary'))
          }
        }
        .width('100%')

        Stack({ alignContent: Alignment.Center }) {
          FramePreview({
            frame: f,
            photo: null,
            previewWidth: Math.max(110, this.cardW() - 28),
            radius: 5
          })
        }
        .width('100%')
        .height(142)
        .borderRadius(12)
        .backgroundColor($r('app.color.surface_muted'))
        .clip(true)
        .onClick(() => {
          if (editable) {
            this.openDesigner(f.id);
          }
        })

        if (editable) {
          Text('点击预览区域继续编辑')
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        } else {
          Text('系统模板')
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
      .width('100%')
      .height(220)
      .padding(12)
      .borderRadius(18)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border_light') })
      .shadow({ radius: 8, color: '#10000000', offsetX: 0, offsetY: 3 })
    }
  }
}
