let storageUpdateCall = new LocalStorage();

@Entry(storageUpdateCall)
@Component
struct MusicCard {
  @LocalStorageProp('title') title: string = '暂无播放';
  @LocalStorageProp('singer') singer: string = '';
  @LocalStorageProp('imgName') imgName: string = '';
  @LocalStorageProp('playing') playing: boolean = false;
  @LocalStorageProp('lyric') lyric: string = '';
  @LocalStorageProp('dimension') dimension: number = 3;
  @LocalStorageProp('formId') formId: string = '';

  /** Square (2*2) cards stack the artwork above the title and controls. */
  private isSquareCard(): boolean {
    return this.dimension <= 2;
  }

  private postAction(action: string): void {
    postCardAction(this, {
      action: 'call',
      abilityName: 'MusichomeAbility',
      params: {
        method: 'cardAction',
        actionType: action,
        formId: this.formId
      }
    });
  }

  @Builder
  private ControlButton(symbol: Resource, action: string, size: number) {
    SymbolGlyph(symbol)
      .fontSize(size)
      .fontColor([Color.White])
      .margin({ left: 6, right: 6 })
      .onClick(() => {
        this.postAction(action);
      })
  }

  @Builder
  private AlbumStack() {
    Stack({ alignContent: Alignment.Center }) {
      Image($rawfile('music/album_background.png'))
        .height('100%')
        .width('100%')

      Image($rawfile('music/album.png'))
        .height('60%')
        .width('60%')
        .offset({ y: '1.5%', x: '-0.5' })

      if (this.imgName.length > 0) {
        Column()
          .height('56%')
          .width('56%')
          .borderRadius('100%')
          .clip(true)
          .backgroundImage('memory://' + this.imgName)
          .backgroundImageSize(ImageSize.Cover)
      }

      Image($rawfile('music/album_btn.png'))
        .height('25%')
        .objectFit(ImageFit.Contain)
        .offset({ y: '-10%', x: '28%' })
    }
    .borderRadius(16)
    .aspectRatio(1)
  }

  @Builder
  private TitleText() {
    Text(this.title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .textAlign(TextAlign.Center)
  }

  @Builder
  private SubTitleText() {
    Text(this.lyric.length > 0 ? this.lyric : (this.singer.length > 0 ? this.singer : ' '))
      .fontSize(11)
      .fontColor('#CCFFFFFF')
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .textAlign(TextAlign.Center)
      .margin({ top: 4 })
  }

  @Builder
  private ControlButtons(size: number) {
    Row() {
      this.ControlButton($r('sys.symbol.backward_fill'), 'previous', size)

      Row() {
        SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
          .fontSize(size + 6)
          .fontColor([Color.White])
      }
      .width(size + 22)
      .height(size + 22)
      .borderRadius((size + 22) / 2)
      .backgroundColor('#33FFFFFF')
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.postAction('playPause');
      })

      this.ControlButton($r('sys.symbol.fast_forward'), 'next', size)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($rawfile('music/background.png'))
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height('100%')

      Image($rawfile('music/music_hanhan.png'))
        .objectFit(ImageFit.Contain)
        .height('90%')
        .width('60%')
        .position({ right: 0, bottom: 0 })
        .offset({ x: '10%', y: '10%' })

      if (this.isSquareCard()) {
        Column() {
          Column() {
            this.AlbumStack()
          }
          .height('46%')

          this.TitleText()

          Row() {
            this.ControlButtons(16)
          }
          .margin({ top: 4 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      } else {
        Row() {
          Column() {
            this.AlbumStack()
          }
          .width('40%')
          .aspectRatio(1)

          Column() {
            this.TitleText()
            this.SubTitleText()

            Row() {
              this.ControlButtons(22)
            }
            .margin({ top: 6 })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ left: 8, right: 8 })
        }
        .height('100%')
        .width('100%')
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
