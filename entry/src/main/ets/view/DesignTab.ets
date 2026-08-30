import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { FrameConfig, buildPresets, BG_COLORS, TEXT_COLORS, saveCustomFrames } from '../model/FrameConfig';
import { FramePreview } from './FramePreview';

@Component
export struct DesignTab {
  @ObjectLink frame: FrameConfig;
  @Link customFrames: FrameConfig[];
  presets: FrameConfig[] = buildPresets();

  saveAsPreset() {
    const c = new FrameConfig();
    c.copyFrom(this.frame);
    c.id = `custom_${Date.now()}`;
    c.name = `我的相框 ${this.customFrames.length + 1}`;
    this.customFrames.push(c);
    saveCustomFrames(getContext(this) as common.Context, this.customFrames);
    promptAction.showToast({ message: `已保存「${c.name}」` });
  }

  confirmDelete(f: FrameConfig) {
    AlertDialog.show({
      title: '删除设计',
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
          const idx = this.customFrames.indexOf(f);
          if (idx >= 0) {
            this.customFrames.splice(idx, 1);
            saveCustomFrames(getContext(this) as common.Context, this.customFrames);
            if (this.frame.id === f.id) {
              this.frame.copyFrom(this.presets[0]);
            }
          }
        }
      }
    });
  }

  @Builder
  Swatches(colors: string[], current: string, onPick: (c: string) => void) {
    Row({ space: 10 }) {
      ForEach(colors, (c: string) => {
        Column() {
        }
        .width(34)
        .height(34)
        .borderRadius(17)
        .backgroundColor(c)
        .border({
          width: current === c ? 3 : 1,
          color: current === c ? '#0A59F7' : '#DDDDDD'
        })
        .onClick(() => onPick(c))
      }, (c: string) => c)
    }
  }

  @Builder
  SectionTitle(text: string) {
    Text(text)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor('#333333')
      .width('100%')
  }

  @Builder
  SwitchRow(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#333333')
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#0A59F7')
        .onChange((v: boolean) => onChange(v))
    }
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        // 实时预览
        Row() {
          FramePreview({ frame: this.frame, photo: null, previewWidth: 240, radius: 6 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        // 预设
        this.SectionTitle('预设相框')
        Scroll() {
          Column({ space: 8 }) {
            Row({ space: 10 }) {
              ForEach(this.presets, (f: FrameConfig) => {
                this.Chip(f, false)
              }, (f: FrameConfig) => f.id)
            }
            if (this.customFrames.length > 0) {
              Row({ space: 10 }) {
                ForEach(this.customFrames, (f: FrameConfig) => {
                  this.Chip(f, true)
                }, (f: FrameConfig) => f.id)
              }
            }
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        // 外观
        this.SectionTitle('背景色')
        this.Swatches(BG_COLORS, this.frame.bg, (c: string) => this.frame.bg = c)
        this.SectionTitle('文字颜色')
        this.Swatches(TEXT_COLORS, this.frame.textColor, (c: string) => this.frame.textColor = c)

        Row() {
          Text('边框厚度')
            .fontSize(14)
          Slider({
            value: this.frame.borderRatio * 100,
            min: 2,
            max: 14,
            step: 0.5,
            style: SliderStyle.OutSet
          })
            .layoutWeight(1)
            .onChange((v: number) => this.frame.borderRatio = v / 100)
          Text(`${Math.round(this.frame.borderRatio * 100)}%`)
            .fontSize(12)
            .fontColor('#999999')
            .width(36)
        }
        .width('100%')

        Row() {
          Text('文字大小')
            .fontSize(14)
          Slider({
            value: this.frame.fontSize * 1000,
            min: 20,
            max: 60,
            step: 1,
            style: SliderStyle.OutSet
          })
            .layoutWeight(1)
            .onChange((v: number) => this.frame.fontSize = v / 1000)
          Text(`${Math.round(this.frame.fontSize * 1000)}`)
            .fontSize(12)
            .fontColor('#999999')
            .width(36)
        }
        .width('100%')

        // 布局
        this.SectionTitle('文字位置与对齐')
        Row({ space: 12 }) {
          Button(this.frame.pos === 'top' ? '✓ 上方' : '上方', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .fontSize(13)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .backgroundColor(this.frame.pos === 'top' ? '#0A59F7' : '#EEEEEE')
            .fontColor(this.frame.pos === 'top' ? Color.White : '#333333')
            .onClick(() => this.frame.pos = 'top')
          Button(this.frame.pos === 'bottom' ? '✓ 下方' : '下方', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .fontSize(13)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .backgroundColor(this.frame.pos === 'bottom' ? '#0A59F7' : '#EEEEEE')
            .fontColor(this.frame.pos === 'bottom' ? Color.White : '#333333')
            .onClick(() => this.frame.pos = 'bottom')
        }
        .width('100%')

        Row({ space: 12 }) {
          Button(this.frame.align === 'left' ? '✓ 左' : '左', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .fontSize(13)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .backgroundColor(this.frame.align === 'left' ? '#0A59F7' : '#EEEEEE')
            .fontColor(this.frame.align === 'left' ? Color.White : '#333333')
            .onClick(() => this.frame.align = 'left')
          Button(this.frame.align === 'center' ? '✓ 中' : '中', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .fontSize(13)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .backgroundColor(this.frame.align === 'center' ? '#0A59F7' : '#EEEEEE')
            .fontColor(this.frame.align === 'center' ? Color.White : '#333333')
            .onClick(() => this.frame.align = 'center')
          Button(this.frame.align === 'right' ? '✓ 右' : '右', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .fontSize(13)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .backgroundColor(this.frame.align === 'right' ? '#0A59F7' : '#EEEEEE')
            .fontColor(this.frame.align === 'right' ? Color.White : '#333333')
            .onClick(() => this.frame.align = 'right')
        }
        .width('100%')

        // 显示要素
        this.SectionTitle('显示要素（来自照片 EXIF）')
        this.SwitchRow('光圈', this.frame.showAperture, (v: boolean) => this.frame.showAperture = v)
        this.SwitchRow('快门', this.frame.showShutter, (v: boolean) => this.frame.showShutter = v)
        this.SwitchRow('ISO', this.frame.showIso, (v: boolean) => this.frame.showIso = v)
        this.SwitchRow('焦距', this.frame.showFocal, (v: boolean) => this.frame.showFocal = v)
        this.SwitchRow('相机型号', this.frame.showCamera, (v: boolean) => this.frame.showCamera = v)
        this.SwitchRow('拍摄时间', this.frame.showTime, (v: boolean) => this.frame.showTime = v)
        this.SwitchRow('经纬度', this.frame.showGps, (v: boolean) => this.frame.showGps = v)

        this.SectionTitle('自定义文字')
        TextInput({ text: this.frame.title, placeholder: '例如：我的旅行日记 / MOMENT' })
          .width('100%')
          .onChange((v: string) => this.frame.title = v)
        this.SwitchRow('显示自定义文字', this.frame.showTitle, (v: boolean) => this.frame.showTitle = v)

        Button('保存为我的相框', { type: ButtonType.Capsule })
          .width('100%')
          .backgroundColor('#0A59F7')
          .onClick(() => this.saveAsPreset())
      }
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
  }

  @Builder
  Chip(f: FrameConfig, deletable: boolean) {
    Column({ space: 4 }) {
      Row() {
        Text(f.name)
          .fontSize(11)
          .fontColor(this.frame.id === f.id ? '#0A59F7' : '#333333')
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .borderRadius(8)
      .backgroundColor(f.bg)
      .border({
        width: this.frame.id === f.id ? 2 : 1,
        color: this.frame.id === f.id ? '#0A59F7' : '#CCCCCC'
      })
    }
    .onClick(() => this.frame.copyFrom(f))
    .gesture(LongPressGesture()
      .onAction((event: GestureEvent) => {
        if (deletable) {
          this.confirmDelete(f);
        }
      })
    )
  }
}
