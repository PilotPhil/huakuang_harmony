import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BG_COLORS, CAMERA_LOGOS, CameraLogoOption, FrameConfig, FrameElement, TEXT_COLORS, buildPresets, logoResource, saveCustomFrames } from '../model/FrameConfig';
import { PhotoItem, makePhotoItem } from '../model/ExifHelper';
import { FramePreview } from './FramePreview';
import { setStatusBarStyle } from '../util/WindowUtils';

export class FrameDesignParam {
  frameId: string = '';

  constructor(frameId: string = '') {
    this.frameId = frameId;
  }
}

/** 相框设计器：信息开关、元素排版和相框属性共用一个实时预览。 */
@Component
export struct FrameDesignPage {
  @Link customFrames: FrameConfig[];
  @State draft: FrameConfig = new FrameConfig();
  @State panel: number = 0;
  @State selectedElementId: string = 'frame';
  @State previewW: number = 300;
  @State zoom: number = 1;
  @State pinchBaseZoom: number = 1;
  @State canvasOffsetX: number = 0;
  @State canvasOffsetY: number = 0;
  @State canvasBaseX: number = 0;
  @State canvasBaseY: number = 0;
  @State editing: boolean = false;
  @State snapX: boolean = false;
  @State snapY: boolean = false;
  @State dragBaseX: number = 0.5;
  @State dragBaseY: number = 0.5;
  @State infoDragIndex: number = -1;
  @State previewVersion: number = 0;
  @State samplePhoto: PhotoItem | null = null;
  @StorageLink('statusBarH') statusH: number = 0;
  @StorageLink('navBarH') navH: number = 0;
  param: FrameDesignParam = new FrameDesignParam();
  pathStack: NavPathStack | null = null;

  aboutToAppear(): void {
    setStatusBarStyle(getContext(this) as common.Context, false);
    for (const frame of this.customFrames) {
      if (frame.id === this.param.frameId) {
        this.draft.copyFrom(frame);
        this.editing = true;
        return;
      }
    }
    this.draft.copyFrom(buildPresets()[0]);
    this.draft.id = '';
    this.draft.name = `我的相框 ${this.customFrames.length + 1}`;
  }

  private element(id: string): FrameElement | null {
    for (const item of this.draft.elements) {
      if (item.id === id) return item;
    }
    return null;
  }

  private selectElement(id: string): void {
    this.selectedElementId = id;
    this.panel = 1;
    const item = this.element(id);
    if (item !== null) {
      this.dragBaseX = item.x >= 0 ? item.x : 0.5;
      this.dragBaseY = item.y >= 0 ? item.y : 0.5;
    }
    this.snapX = false;
    this.snapY = false;
  }

  private snap(value: number): number {
    const guides: number[] = [0.08, 0.25, 0.5, 0.75, 0.92];
    for (const guide of guides) {
      if (Math.abs(value - guide) <= 0.035) return guide;
    }
    return Math.max(0.04, Math.min(0.96, value));
  }

  private moveElement(id: string, dx: number, dy: number): void {
    const item = this.element(id);
    if (item === null) return;
    const rawX = this.dragBaseX + dx;
    const rawY = this.dragBaseY + dy;
    const x = this.snap(rawX);
    const y = this.snap(rawY);
    this.snapX = Math.abs(rawX - x) <= 0.001;
    this.snapY = Math.abs(rawY - y) <= 0.001;
    item.x = x;
    item.y = y;
    item.manual = true;
  }

  private reorderInfo(from: number, to: number): void {
    if (from === to || from < 0 || to < 0 || from >= this.draft.elements.length || to >= this.draft.elements.length) {
      return;
    }
    const moved = this.draft.elements[from];
    if (moved === undefined) return;
    const next: FrameElement[] = [];
    for (let i = 0; i < this.draft.elements.length; i++) {
      if (i !== from) next.push(this.draft.elements[i]);
    }
    next.splice(to, 0, moved);
    this.draft.elements = next;
    // 元素数组是 FrameConfig 的嵌套字段，显式通知预览立即按新顺序重建。
    this.previewVersion += 1;
  }

  /** FrameConfig 的嵌套字段不会稳定触发子组件重建，统一用版本号刷新预览。 */
  private refreshPreview(): void {
    this.previewVersion += 1;
  }

  /** 新增设计页的空白预览点击后，使用系统图库选择一张示例照片。 */
  private async chooseSamplePhoto(): Promise<void> {
    try {
      const opt = new photoAccessHelper.PhotoSelectOptions();
      opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(opt);
      const uri = result.photoUris[0];
      if (uri !== undefined && uri !== '') {
        this.samplePhoto = await makePhotoItem(uri);
        this.refreshPreview();
      }
    } catch (err) {
      const e = err as BusinessError;
      if (e.code !== 13900042 && e.code !== 13900051) {
        promptAction.showToast({ message: `示例图片选择失败：${e.message}` });
      }
    }
  }

  private moveInfoByDrag(start: number, offsetY: number): void {
    if (this.infoDragIndex < 0) this.infoDragIndex = start;
    const target = Math.max(0, Math.min(this.draft.elements.length - 1, start + Math.round(offsetY / 50)));
    if (target !== this.infoDragIndex) {
      this.reorderInfo(this.infoDragIndex, target);
      this.infoDragIndex = target;
    }
  }

  private setVisible(id: string, value: boolean): void {
    const item = this.element(id);
    if (item !== null) item.enabled = value;
    if (id === 'title') this.draft.showTitle = value;
    if (id === 'aperture') this.draft.showAperture = value;
    if (id === 'shutter') this.draft.showShutter = value;
    if (id === 'iso') this.draft.showIso = value;
    if (id === 'focal') this.draft.showFocal = value;
    if (id === 'camera') this.draft.showCamera = value;
    if (id === 'time') this.draft.showTime = value;
    if (id === 'gps') this.draft.showGps = value;
    if (id === 'logo') {
      this.draft.showLogo = value;
      if (value && item !== null && item.logoKey === '' && item.logoUri === '') {
        item.logoKey = 'canon';
      }
      this.refreshPreview();
    }
  }

  private chooseLogo(key: string): void {
    const item = this.element('logo');
    if (item === null) return;
    item.logoKey = key;
    item.logoUri = '';
    item.enabled = true;
    this.draft.showLogo = true;
    this.refreshPreview();
  }

  private clearLogo(): void {
    const item = this.element('logo');
    if (item === null) return;
    item.logoKey = '';
    item.logoUri = '';
    item.enabled = false;
    this.draft.showLogo = false;
    this.refreshPreview();
  }

  private async chooseCustomLogo(): Promise<void> {
    try {
      const opt = new photoAccessHelper.PhotoSelectOptions();
      opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(opt);
      const uri = result.photoUris[0];
      const item = this.element('logo');
      if (uri !== undefined && uri !== '' && item !== null) {
        item.logoKey = 'custom';
        item.logoUri = uri;
        item.enabled = true;
        this.draft.showLogo = true;
        this.refreshPreview();
      }
    } catch (err) {
      const e = err as BusinessError;
      if (e.code !== 13900042 && e.code !== 13900051) {
        promptAction.showToast({ message: `Logo 选择失败：${e.message}` });
      }
    }
  }

  private save(): void {
    const name = this.draft.name.trim();
    if (name === '') {
      promptAction.showToast({ message: '请输入相框名称' });
      return;
    }
    this.draft.name = name;
    if (this.editing) {
      const target = this.customFrames.find((item: FrameConfig) => item.id === this.param.frameId);
      if (target !== undefined) target.copyFrom(this.draft);
    } else {
      const frame = new FrameConfig();
      frame.copyFrom(this.draft);
      frame.id = `custom_${Date.now()}`;
      this.customFrames.push(frame);
    }
    saveCustomFrames(getContext(this) as common.Context, this.customFrames);
    promptAction.showToast({ message: this.editing ? '相框已更新' : '相框已保存' });
    if (this.pathStack !== null) this.pathStack.pop(true);
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(20)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(42)
        .height(42)
        .borderRadius(21)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border_light') })
        .onClick(() => {
          if (this.pathStack !== null) this.pathStack.pop(true);
        })

        Column({ space: 2 }) {
          Text(this.editing ? '编辑相框' : '新增设计')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('点击信息可选中，拖动进行排版')
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        Button('保存', { type: ButtonType.Capsule })
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#0A59F7')
          .padding({ left: 18, right: 18 })
          .onClick(() => this.save())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: px2vp(this.statusH) + 8, bottom: 8 })

      Stack({ alignContent: Alignment.Center }) {
        // 版本号作为 ForEach key，排序时销毁并重建预览，避开嵌套数组不触发 @ObjectLink 的情况。
        ForEach([this.previewVersion], () => {
          FramePreview({
            frame: this.draft,
            photo: this.samplePhoto,
            previewWidth: this.previewW,
            radius: 6,
            zoom: this.zoom,
            offsetX: this.canvasOffsetX,
            offsetY: this.canvasOffsetY,
            interactive: true,
            selectedElementId: this.selectedElementId,
            onElementSelect: (id: string) => this.selectElement(id),
            onElementMove: (id: string, dx: number, dy: number) => this.moveElement(id, dx, dy),
            onCanvasSelect: () => {
              if (this.samplePhoto === null) {
                this.chooseSamplePhoto();
              } else {
                this.selectElement('frame');
              }
            }
          })
        }, (version: number) => `${version}`)
        if (this.snapX) {
          Column() {
          }
          .width(1)
          .height('86%')
          .backgroundColor('#0A59F7')
          .opacity(0.55)
        }
        if (this.snapY) {
          Row() {
          }
          .width('86%')
          .height(1)
          .backgroundColor('#0A59F7')
          .opacity(0.55)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('app.color.preview_background'))
      .clip(true)
      .gesture(
        GestureGroup(GestureMode.Parallel,
          PinchGesture({ fingers: 2 })
            .onActionStart(() => {
              this.pinchBaseZoom = this.zoom;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.zoom = Math.max(0.75, Math.min(1.6, this.pinchBaseZoom * event.scale));
            }),
          PanGesture({ fingers: 2 })
            .onActionStart(() => {
              this.canvasBaseX = this.canvasOffsetX;
              this.canvasBaseY = this.canvasOffsetY;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.canvasOffsetX = this.canvasBaseX + event.offsetX;
              this.canvasOffsetY = this.canvasBaseY + event.offsetY;
            })
        )
      )
      .parallelGesture(
        PanGesture({ fingers: 1 })
          .onActionStart(() => {
            this.canvasBaseX = this.canvasOffsetX;
            this.canvasBaseY = this.canvasOffsetY;
          })
          .onActionUpdate((event: GestureEvent) => {
            // 文字元素拥有自己的拖动手势；只有空白画布区域移动画布。
            if (this.selectedElementId === 'frame') {
              this.canvasOffsetX = this.canvasBaseX + event.offsetX;
              this.canvasOffsetY = this.canvasBaseY + event.offsetY;
            }
          })
      )
      .onAreaChange((oldValue: Area, newValue: Area) => {
        this.previewW = Math.min(320, Math.max(220, (newValue.width as number) - 42));
      })

      Row() {
        this.ToolTab(0, '信息', $r('sys.symbol.camera_aperture'))
        this.ToolTab(1, '元素', $r('sys.symbol.square_and_pencil'))
        this.ToolTab(2, '相框', $r('sys.symbol.crop_rotate'))
      }
      .width('100%')
      .height(68)
      .padding({ left: 6, right: 6 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border_light') })

      Scroll() {
        Column({ space: 13 }) {
          if (this.panel === 0) {
            this.InfoPanel()
          } else if (this.panel === 1) {
            // 同步重建控制项，让嵌套 FrameConfig 字段的选中态和滑块值立即更新。
            ForEach([this.previewVersion], () => {
              this.ElementPanel()
            }, (version: number) => `${version}`)
          } else {
            this.CanvasPanel()
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 16, bottom: Math.max(18, px2vp(this.navH) + 10) })
      }
      .width('100%')
      .height(278)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
      .backgroundColor($r('app.color.surface'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  ToolTab(index: number, label: string, icon: Resource) {
    Column({ space: 5 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.panel === index ? '#0A59F7' : $r('app.color.text_secondary')])
      Text(label)
        .fontSize(11)
        .fontWeight(this.panel === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.panel === index ? '#0A59F7' : $r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.panel === index ? $r('app.color.blue_tint') : '#00FFFFFF')
    .borderRadius(12)
    .onClick(() => this.panel = index)
  }

  @Builder
  InfoPanel() {
    this.SectionTitle('显示在相框上的信息')
    ForEach(this.draft.elements, (item: FrameElement, index: number) => {
      this.InfoSwitch(item, index)
    }, (item: FrameElement) => item.id)
  }

  @Builder
  InfoSwitch(item: FrameElement, index: number) {
    Row() {
      Text('≡')
        .fontSize(20)
        .fontColor($r('app.color.text_secondary'))
        .width(34)
        .textAlign(TextAlign.Center)
        .gesture(
          PanGesture()
            .onActionStart(() => {
              this.infoDragIndex = index;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.moveInfoByDrag(index, event.offsetY);
            })
            .onActionEnd(() => {
              this.infoDragIndex = -1;
            })
        )
      Column({ space: 2 }) {
        Text(item.label)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
        Text(this.selectedElementId === item.id ? '点击预览可拖动排版' : '在预览中点击此信息进行编辑')
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: item.enabled })
        .selectedColor('#0A59F7')
        .onChange((value: boolean) => this.setVisible(item.id, value))
    }
    .width('100%')
    .height(46)
    .onClick(() => this.selectElement(item.id))
  }

  @Builder
  ElementPanel() {
    this.SectionTitle('信息排列')
    Row({ space: 10 }) {
      this.ChoiceButton('竖向', this.draft.infoLayout === 'vertical',
        () => {
          this.draft.infoLayout = 'vertical';
          this.refreshPreview();
        })
      this.ChoiceButton('横向', this.draft.infoLayout === 'horizontal',
        () => {
          this.draft.infoLayout = 'horizontal';
          this.refreshPreview();
        })
    }
    .width('100%')
    this.SectionTitle('信息对齐')
    Row({ space: 10 }) {
      this.ChoiceButton('左对齐', this.draft.align === 'left', () => {
        this.draft.align = 'left';
        this.refreshPreview();
      })
      this.ChoiceButton('居中', this.draft.align === 'center', () => {
        this.draft.align = 'center';
        this.refreshPreview();
      })
      this.ChoiceButton('右对齐', this.draft.align === 'right', () => {
        this.draft.align = 'right';
        this.refreshPreview();
      })
    }
    .width('100%')
    this.SectionTitle('白边宽度')
    this.SliderRow('上/左/右白边', this.draft.borderSideRatio * 100, 0, 20, '%',
      (value: number) => {
        this.draft.borderSideRatio = value / 100;
        // 兼容旧配置和仍读取 borderRatio 的外部调用。
        this.draft.borderRatio = this.draft.borderSideRatio;
        this.refreshPreview();
      })
    this.SliderRow('下方白边', this.draft.borderBottomRatio * 100, 0, 30, '%',
      (value: number) => {
        this.draft.borderBottomRatio = value / 100;
        this.refreshPreview();
      })

    if (this.selectedElementId === 'frame') {
      this.SectionTitle('相框属性')
      this.SliderRow('文字区域', this.draft.textAreaRatio * 100, 55, 100, '%',
        (value: number) => this.draft.textAreaRatio = value / 100)
      this.SectionTitle('相框名称')
      TextInput({ text: this.draft.name, placeholder: '给这个相框起个名字' })
        .width('100%')
        .height(42)
        .backgroundColor($r('app.color.surface_tertiary'))
        .onChange((value: string) => this.draft.name = value)
    } else {
      if (this.element(this.selectedElementId) !== null) {
        this.SectionTitle(`${this.element(this.selectedElementId)!.label} · 元素样式`)
        if (this.selectedElementId === 'logo') {
          this.SectionTitle('内置品牌 Logo')
          this.LogoChoices(this.element('logo')!.logoKey, this.element('logo')!.logoUri)
          Button('上传自定义 Logo', { type: ButtonType.Capsule })
            .width('100%')
            .height(38)
            .fontSize(12)
            .backgroundColor($r('app.color.blue_tint'))
            .fontColor('#0A59F7')
            .onClick(() => this.chooseCustomLogo())
          Button('不显示 Logo', { type: ButtonType.Capsule })
            .width('100%')
            .height(36)
            .fontSize(12)
            .backgroundColor($r('app.color.surface_tertiary'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => this.clearLogo())
        } else {
          this.SliderRow('字号', this.element(this.selectedElementId)!.fontSize * 1000, 20, 60, '',
            (value: number) => this.element(this.selectedElementId)!.fontSize = value / 1000)
          this.SectionTitle('文字颜色')
          this.ColorSwatches(TEXT_COLORS, this.element(this.selectedElementId)!.color,
            (color: string) => this.element(this.selectedElementId)!.color = color)
          this.SectionTitle('字体样式')
          Row({ space: 10 }) {
            this.ChoiceButton('常规', !this.element(this.selectedElementId)!.bold,
              () => this.element(this.selectedElementId)!.bold = false)
            this.ChoiceButton('加粗', this.element(this.selectedElementId)!.bold,
              () => this.element(this.selectedElementId)!.bold = true)
          }
          .width('100%')
        }
        this.SliderRow('左右位置', (this.element(this.selectedElementId)!.x >= 0 ?
          this.element(this.selectedElementId)!.x : 0.5) * 100, 4, 96, '%',
          (value: number) => {
            this.element(this.selectedElementId)!.x = value / 100;
            this.element(this.selectedElementId)!.manual = true;
          })
        this.SliderRow('上下位置', (this.element(this.selectedElementId)!.y >= 0 ?
          this.element(this.selectedElementId)!.y : (this.draft.pos === 'top' ? 0.12 : 0.88)) * 100,
          4, 96, '%', (value: number) => {
            this.element(this.selectedElementId)!.y = value / 100;
            this.element(this.selectedElementId)!.manual = true;
          })
        Row() {
          Text('允许放入照片区域')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.element(this.selectedElementId)!.allowInsidePhoto })
            .selectedColor('#0A59F7')
            .onChange((value: boolean) => this.element(this.selectedElementId)!.allowInsidePhoto = value)
        }
        .width('100%')
        .height(42)
        Button('恢复默认位置', { type: ButtonType.Capsule })
          .width('100%')
          .height(36)
          .fontSize(12)
          .backgroundColor($r('app.color.surface_tertiary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.element(this.selectedElementId)!.manual = false;
            this.element(this.selectedElementId)!.x = 0.5;
            this.element(this.selectedElementId)!.y = -1;
          })
      }
    }
  }

  @Builder
  LogoChoices(currentKey: string, currentUri: string) {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(CAMERA_LOGOS, (option: CameraLogoOption) => {
          Column({ space: 3 }) {
            if (logoResource(option.key) !== null) {
              Image(logoResource(option.key) as Resource)
                .width(54)
                .height(30)
                .objectFit(ImageFit.Contain)
            }
            Text(option.label)
              .fontSize(10)
              .fontColor($r('app.color.text_secondary'))
          }
          .width(74)
          .height(58)
          .justifyContent(FlexAlign.Center)
          .borderRadius(10)
          .backgroundColor(currentKey === option.key ? $r('app.color.blue_tint') : $r('app.color.surface_tertiary'))
          .border({ width: currentKey === option.key ? 2 : 1, color: currentKey === option.key ? '#0A59F7' : $r('app.color.border_light') })
          .onClick(() => this.chooseLogo(option.key))
        }, (option: CameraLogoOption) => option.key)
        Column({ space: 3 }) {
          if (currentUri !== '') {
            Image(currentUri)
              .width(54)
              .height(30)
              .objectFit(ImageFit.Contain)
          } else {
            SymbolGlyph($r('sys.symbol.arrow_up_circle'))
              .fontSize(24)
              .fontColor([$r('app.color.text_secondary')])
          }
          Text('自定义')
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(74)
        .height(58)
        .justifyContent(FlexAlign.Center)
        .borderRadius(10)
        .backgroundColor(currentKey === 'custom' ? $r('app.color.blue_tint') : $r('app.color.surface_tertiary'))
        .border({ width: currentKey === 'custom' ? 2 : 1, color: currentKey === 'custom' ? '#0A59F7' : $r('app.color.border_light') })
        .onClick(() => this.chooseCustomLogo())
      }
      .padding({ top: 2, bottom: 2 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  CanvasPanel() {
    this.SectionTitle('相框外观')
    this.SectionTitle('相框颜色')
    this.ColorSwatches(BG_COLORS, this.draft.bg, (color: string) => this.draft.bg = color)
    this.SliderRow('颜色透明度', this.draft.opacity * 100, 10, 100, '%',
      (value: number) => this.draft.opacity = value / 100)
    this.SectionTitle('特殊效果')
    Scroll() {
      Row({ space: 8 }) {
        this.EffectButton('无', 'none')
        this.EffectButton('沉浸光感', 'immersive')
        this.EffectButton('透明效果', 'transparent')
        this.EffectButton('磨砂', 'frosted')
        this.EffectButton('高斯模糊', 'gaussian')
      }
      .padding({ top: 2, bottom: 2 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    this.SectionTitle('预览缩放')
    Text('缩放和位置')
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
    Row({ space: 10 }) {
      Button('缩小', { type: ButtonType.Capsule })
        .layoutWeight(1)
        .backgroundColor($r('app.color.surface_tertiary'))
        .fontColor($r('app.color.text_primary'))
        .onClick(() => this.zoom = Math.max(0.75, this.zoom - 0.1))
      Text(`${Math.round(this.zoom * 100)}%`)
        .width(54)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
      Button('放大', { type: ButtonType.Capsule })
        .layoutWeight(1)
        .backgroundColor($r('app.color.surface_tertiary'))
        .fontColor($r('app.color.text_primary'))
        .onClick(() => this.zoom = Math.min(1.6, this.zoom + 0.1))
    }
    .width('100%')
    Button('重置预览', { type: ButtonType.Capsule })
      .width('100%')
      .height(36)
      .fontSize(12)
      .backgroundColor($r('app.color.blue_tint'))
      .fontColor('#0A59F7')
      .onClick(() => {
        this.zoom = 1;
        this.canvasOffsetX = 0;
        this.canvasOffsetY = 0;
      })
  }

  @Builder
  EffectButton(label: string, value: string) {
    Button(this.draft.effect === value ? `✓ ${label}` : label, { type: ButtonType.Capsule })
      .width(88)
      .height(36)
      .fontSize(11)
      .fontColor(this.draft.effect === value ? Color.White : $r('app.color.text_primary'))
      .backgroundColor(this.draft.effect === value ? '#0A59F7' : $r('app.color.surface_tertiary'))
      .onClick(() => this.draft.effect = value)
  }

  @Builder
  SectionTitle(text: string) {
    Text(text)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
  }

  @Builder
  SliderRow(label: string, value: number, min: number, max: number, suffix: string,
    onChange: (value: number) => void) {
    Row({ space: 10 }) {
      Text(label)
        .width(74)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
      Slider({ value: value, min: min, max: max, step: 1, style: SliderStyle.OutSet })
        .layoutWeight(1)
        .selectedColor('#0A59F7')
        .onChange(onChange)
      Text(`${Math.round(value)}${suffix}`)
        .width(42)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  @Builder
  ColorSwatches(colors: string[], current: string, onPick: (color: string) => void) {
    Scroll() {
      Row({ space: 12 }) {
        ForEach(colors, (color: string) => {
          Column() {
          }
          .width(38)
          .height(38)
          .borderRadius(11)
          .backgroundColor(color)
          .border({
            width: current === color ? 3 : 1,
            color: current === color ? '#0A59F7' : $r('app.color.border')
          })
          .onClick(() => onPick(color))
        }, (color: string) => color)
      }
      .padding({ top: 2, bottom: 2 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  ChoiceButton(label: string, selected: boolean, action: () => void) {
    Button(selected ? `✓ ${label}` : label, { type: ButtonType.Capsule })
      .layoutWeight(1)
      .height(36)
      .fontSize(12)
      .fontColor(selected ? Color.White : $r('app.color.text_primary'))
      .backgroundColor(selected ? '#0A59F7' : $r('app.color.surface_tertiary'))
      .onClick(action)
  }
}
