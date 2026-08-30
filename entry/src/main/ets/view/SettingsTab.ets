import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { loadLogin, saveLogin } from '../model/FrameConfig';

@Component
export struct SettingsTab {
  @State loggedIn: boolean = false;
  @State account: string = '';

  aboutToAppear(): void {
    const ctx = getContext(this) as common.Context;
    this.loggedIn = loadLogin(ctx);
    if (this.loggedIn) {
      this.account = 'huawei用户_8f2c';
    }
  }

  login() {
    this.loggedIn = true;
    this.account = 'huawei用户_8f2c';
    saveLogin(getContext(this) as common.Context, true);
    promptAction.showToast({ message: '登录成功（演示）' });
  }

  logout() {
    AlertDialog.show({
      title: '退出登录',
      message: '确定退出当前账号吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '退出',
        fontColor: '#D94838',
        action: () => {
          this.loggedIn = false;
          this.account = '';
          saveLogin(getContext(this) as common.Context, false);
          promptAction.showToast({ message: '已退出登录' });
        }
      }
    });
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
  RowItem(label: string, value: string, action?: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor('#333333')
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor(this.loggedIn ? '#0A59F7' : '#999999')
      if (action !== undefined) {
        Text('›')
          .fontSize(18)
          .fontColor('#CCCCCC')
          .margin({ left: 6 })
      }
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .onClick(() => {
      if (action !== undefined) {
        action();
      }
    })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        // 账号
        Row({ space: 12 }) {
          Column() {
            Text(this.loggedIn ? this.account.substring(0, 1) : '未')
              .fontSize(22)
              .fontColor(Color.White)
          }
          .width(52)
          .height(52)
          .borderRadius(26)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.loggedIn ? '#0A59F7' : '#BBBBBB')

          Column({ space: 2 }) {
            Text(this.loggedIn ? this.account : '未登录')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text(this.loggedIn ? '已登录（演示账号）' : '登录后可在多设备同步你的相框设计')
              .fontSize(12)
              .fontColor('#999999')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Button(this.loggedIn ? '退出' : '登录', { type: ButtonType.Capsule })
            .fontSize(13)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .backgroundColor(this.loggedIn ? '#EEEEEE' : '#0A59F7')
            .fontColor(this.loggedIn ? '#D94838' : Color.White)
            .onClick(() => {
              if (this.loggedIn) {
                this.logout();
              } else {
                this.login();
              }
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#F7F7F7')
        .borderRadius(12)

        // 购买相关
        this.SectionTitle('会员与购买')
        this.RowItem('恢复购买', '', () => {
          promptAction.showToast({ message: '当前没有可恢复的购买记录（演示）' });
        })
        this.RowItem('会员权益', '', () => {
          promptAction.showToast({ message: '付费功能开发中（演示）' });
        })

        // 关于
        this.SectionTitle('关于')
        this.RowItem('应用版本', '1.0.0')
        this.RowItem('用户协议', '')
        this.RowItem('隐私政策', '')
        Text('相框 · FrameStudio 是一个给照片添加拍摄参数边框的小工具。\n当前为演示版本。')
          .fontSize(12)
          .fontColor('#BBBBBB')
          .width('100%')
      }
      .padding({ left: 16, right: 16, top: 16, bottom: 132 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
  }
}
