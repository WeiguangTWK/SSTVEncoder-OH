import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AudioPlaybackService, PlaybackCallbacks } from '../services/media/AudioPlaybackService';
import { ExportRequest, ExportService, sanitizeExportFileName } from '../services/media/ExportService';
import { ImageTransformState } from '../model/SstvTypes';
import {
  createDefaultTransformState,
  withPanDelta,
  withRotationDelta,
  withZoomDelta,
} from '../services/sstv/ImageTransform';
import { getModeById, SSTV_MODES } from '../services/sstv/SstvModes';
import { ImageLoader } from '../services/media/ImageLoader';
import { renderImageForMode } from '../services/sstv/ImageTransform';

class ModeOption {
  value: string;

  constructor(value: string) {
    this.value = value;
  }
}

class PlaybackObserver implements PlaybackCallbacks {
  private owner: Index;
  private generation: number;

  constructor(owner: Index, generation: number) {
    this.owner = owner;
    this.generation = generation;
  }

  onLineChanged(line: number): void {
    this.owner.handlePlaybackLineChanged(this.generation, line);
  }

  onPlaybackStateChanged(isPlaying: boolean): void {
    this.owner.handlePlaybackStateChanged(this.generation, isPlaying);
  }
}

@Entry
@Component
struct Index {
  @State imagePath: string = '';
  @State exportFileName: string = 'sstv_robot36.wav';
  @State useSampleImage: boolean = true;
  @State selectedImageName: string = '';
  @State selectedModeId: string = 'robot36';
  @State exportBusy: boolean = false;
  @State playBusy: boolean = false;
  @State preparingPlayback: boolean = false;
  @State status: string = '就绪';
  @State previewTransform: ImageTransformState = createDefaultTransformState();
  @State previewWidth: number = 0;
  @State previewHeight: number = 0;
  @State currentScanLine: number = 0;
  @State framingExpanded: boolean = false;
  @State showingAbout: boolean = false;
  private playbackGeneration: number = 0;

  private getModeOptions(): Array<ModeOption> {
    const options: Array<ModeOption> = [];
    for (let i = 0; i < SSTV_MODES.length; i += 1) {
      options.push(new ModeOption(`${SSTV_MODES[i].name} (${SSTV_MODES[i].width}x${SSTV_MODES[i].height})`));
    }
    return options;
  }

  private getSelectedModeIndex(): number {
    for (let i = 0; i < SSTV_MODES.length; i += 1) {
      if (SSTV_MODES[i].id === this.selectedModeId) {
        return i;
      }
    }
    return 12;
  }

  private getCurrentMode() {
    return getModeById(this.selectedModeId);
  }

  private getPreviewAspectRatio(): number {
    const mode = this.getCurrentMode();
    return mode.width / mode.height;
  }

  private getPreviewLineTop(): number {
    const mode = this.getCurrentMode();
    if (this.previewHeight <= 0 || mode.height <= 1) {
      return 0;
    }
    const normalized = this.currentScanLine / Math.max(1, mode.height - 1);
    return normalized * Math.max(0, this.previewHeight - 2);
  }

  private getPreviewTranslateX(): number {
    return this.previewWidth * this.previewTransform.panX * 0.18 * this.previewTransform.zoom;
  }

  private getPreviewTranslateY(): number {
    return this.previewHeight * this.previewTransform.panY * 0.18 * this.previewTransform.zoom;
  }

  private resetToSample(): void {
    void this.stopPlaybackAndResetLine();
    this.useSampleImage = true;
    this.imagePath = '';
    this.selectedImageName = '';
    this.status = '就绪';
  }

  private fileNameFromUri(uri: string): string {
    const slashIndex = uri.lastIndexOf('/');
    if (slashIndex >= 0 && slashIndex < uri.length - 1) {
      return uri.substring(slashIndex + 1);
    }
    return uri;
  }

  private async chooseImage(): Promise<void> {
    try {
      const pickerOptions = new photoAccessHelper.PhotoSelectOptions();
      pickerOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      pickerOptions.maxSelectNumber = 1;
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const pickerResult = await photoPicker.select(pickerOptions);
      if (pickerResult.photoUris.length < 1) {
        this.status = '已取消选择';
        return;
      }

      await this.stopPlaybackAndResetLine();
      this.imagePath = pickerResult.photoUris[0];
      this.useSampleImage = false;
      this.selectedImageName = this.fileNameFromUri(this.imagePath);
      this.status = '已选择图片';
    } catch (error) {
      const message = (error as Error).message;
      this.status = `选择图片失败: ${message}`;
    }
  }

  private async loadPreparedImage(context: common.UIAbilityContext) {
    const sourceImage = this.useSampleImage
      ? await ImageLoader.loadSampleImage(context)
      : await ImageLoader.loadFromPath(this.imagePath);
    return renderImageForMode(sourceImage, this.getCurrentMode(), this.previewTransform);
  }

  private async stopPlaybackAndResetLine(): Promise<void> {
    this.playbackGeneration += 1;
    this.currentScanLine = 0;
    this.playBusy = false;
    this.preparingPlayback = false;
    this.status = '已停止';
    await this.setKeepScreenOn(false);
    await AudioPlaybackService.stop();
  }

  private async setKeepScreenOn(keepOn: boolean): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const appWindow = await window.getLastWindow(context);
      await appWindow.setWindowKeepScreenOn(keepOn);
    } catch (_ignore) {
    }
  }

  private async openRepoLink(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility({
        uri: 'https://github.com/WeiguangTWK/SSTVEncoder-OH',
      });
    } catch (_ignore) {
    }
  }

  private applyTransform(nextState: ImageTransformState): void {
    if (this.playBusy) {
      void this.stopPlaybackAndResetLine();
    } else {
      this.currentScanLine = 0;
    }
    this.previewTransform = nextState;
  }

  handlePlaybackLineChanged(generation: number, line: number): void {
    if (generation !== this.playbackGeneration) {
      return;
    }
    this.currentScanLine = line;
  }

  handlePlaybackStateChanged(generation: number, isPlaying: boolean): void {
    if (generation !== this.playbackGeneration) {
      return;
    }
    this.playBusy = isPlaying;
    if (isPlaying) {
      this.preparingPlayback = false;
      void this.setKeepScreenOn(true);
    } else {
      void this.setKeepScreenOn(false);
    }
    if (!isPlaying && this.status === '播放中') {
      this.status = '播放完成';
    }
  }

  private async exportWave(): Promise<void> {
    if (this.exportBusy || this.playBusy) {
      return;
    }

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.exportFileName = sanitizeExportFileName(this.exportFileName, this.selectedModeId);
    this.exportBusy = true;
    this.status = '导出中';
    try {
      const request = new ExportRequest(
        this.imagePath,
        this.exportFileName,
        this.useSampleImage,
        this.getCurrentMode(),
        this.previewTransform
      );
      const outputPath = await ExportService.exportWave(context, request);
      this.status = `已导出: ${outputPath}`;
    } catch (error) {
      const message = (error as Error).message;
      this.status = `失败: ${message}`;
    } finally {
      this.exportBusy = false;
    }
  }

  private async playWave(): Promise<void> {
    if (this.exportBusy || this.playBusy) {
      return;
    }

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.playbackGeneration += 1;
    const generation = this.playbackGeneration;
    this.currentScanLine = 0;
    this.preparingPlayback = true;
    this.status = '准备中';
    try {
      const preparedImage = await this.loadPreparedImage(context);
      if (generation !== this.playbackGeneration) {
        return;
      }
      this.playBusy = true;
      this.preparingPlayback = false;
      this.status = '播放中';
      await this.setKeepScreenOn(true);
      await AudioPlaybackService.playStreamed(context, preparedImage, this.getCurrentMode(), new PlaybackObserver(this, generation));
    } catch (error) {
      if (generation !== this.playbackGeneration) {
        return;
      }
      this.preparingPlayback = false;
      const message = (error as Error).message;
      this.playBusy = false;
      await this.setKeepScreenOn(false);
      this.status = `播放失败: ${message}`;
    }
  }

  @Builder
  private buildAboutPage(): void {
    Column({ space: 18 }) {
      Row({ space: 12 }) {
        Button($r('app.string.about_back'))
          .height(38)
          .padding({ left: 14, right: 14 })
          .borderRadius(12)
          .backgroundColor('#E9ECEF')
          .fontColor('#14213D')
          .onClick(() => {
            this.showingAbout = false;
          })

        Text($r('app.string.about_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#14213D')
          .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Center)

      Column({ space: 10 }) {
        Text($r('app.string.EntryAbility_label'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#14213D')

        Text($r('app.string.about_summary'))
          .fontSize(15)
          .fontColor('#4F5D75')
          .lineHeight(22)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)

      Column({ space: 10 }) {
        Text($r('app.string.about_origin_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#14213D')

        Text($r('app.string.about_origin_body'))
          .fontSize(14)
          .fontColor('#4F5D75')
          .lineHeight(22)

        Text($r('app.string.about_repo_label'))
          .fontSize(14)
          .fontColor('#1D4ED8')
          .decoration({ type: TextDecorationType.Underline })
          .onClick(async () => {
            await this.openRepoLink();
          })
      }
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFF7F1')
  }

  @Builder
  private buildHomePage(): void {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 12 }) {
          Text('SSTV Encoder')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#14213D')
            .layoutWeight(1)

          Button($r('app.string.about_icon'))
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor(Color.Transparent)
            .border({
              width: 1,
              color: '#14213D',
            })
            .fontColor('#14213D')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .padding(0)
            .onClick(() => {
              this.showingAbout = true;
            })
        }
        .alignItems(VerticalAlign.Center)

        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Column({ space: 10 }) {
              Text($r('app.string.mode_label'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#14213D')
              Select(this.getModeOptions())
                .selected(this.getSelectedModeIndex())
                .value(this.getCurrentMode().name)
                .onSelect(async (index: number) => {
                  if (this.playBusy) {
                    await this.stopPlaybackAndResetLine();
                  } else {
                    this.currentScanLine = 0;
                  }
                  this.selectedModeId = SSTV_MODES[index].id;
                  this.exportFileName = sanitizeExportFileName(`sstv_${this.selectedModeId}.wav`, this.selectedModeId);
                })
            }
            .layoutWeight(1)

            Button(this.preparingPlayback ? $r('app.string.play_prepare') :
              (this.playBusy ? $r('app.string.play_stop') : $r('app.string.play_start')))
              .width(92)
              .height(42)
              .borderRadius(12)
              .enabled(!this.exportBusy && !this.preparingPlayback)
              .backgroundColor('#E9ECEF')
              .fontColor('#14213D')
              .opacity(this.exportBusy || this.preparingPlayback ? 0.45 : 1)
              .onClick(async () => {
                if (this.exportBusy || this.preparingPlayback) {
                  return;
                }
                if (this.playBusy) {
                  await this.stopPlaybackAndResetLine();
                  return;
                }
                await this.playWave();
              })
          }
        }
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)

        Column({ space: 12 }) {
          if (!this.useSampleImage && this.selectedImageName.length > 0) {
            Text(this.selectedImageName)
              .fontSize(14)
              .fontColor('#4F5D75')
          }

          Stack() {
            if (this.useSampleImage) {
              Image($rawfile('smpte_color_bars.png'))
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .rotate({ angle: this.previewTransform.rotationQuarterTurns * 90 })
                .scale({ x: this.previewTransform.zoom, y: this.previewTransform.zoom })
                .translate({ x: this.getPreviewTranslateX(), y: this.getPreviewTranslateY() })
            } else {
              Image(this.imagePath)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .rotate({ angle: this.previewTransform.rotationQuarterTurns * 90 })
                .scale({ x: this.previewTransform.zoom, y: this.previewTransform.zoom })
                .translate({ x: this.getPreviewTranslateX(), y: this.getPreviewTranslateY() })
            }

            if (this.playBusy) {
              Row()
                .width('100%')
                .height(2)
                .backgroundColor('#E63946')
                .position({ x: 0, y: this.getPreviewLineTop() })
            }
          }
          .width('100%')
          .aspectRatio(this.getPreviewAspectRatio())
          .backgroundColor('#F4F4F4')
          .borderRadius(22)
          .clip(true)
          .onAreaChange((_oldValue, newValue) => {
            this.previewWidth = Number(newValue.width);
            this.previewHeight = Number(newValue.height);
          })

          if (this.playBusy) {
            Text(`${$r('app.string.scan_line_prefix')} ${this.currentScanLine + 1}/${this.getCurrentMode().height}`)
              .fontSize(13)
              .fontColor('#4F5D75')
          }

          Row({ space: 10 }) {
            Button($r('app.string.choose_image'))
              .layoutWeight(1)
              .height(46)
              .borderRadius(14)
              .backgroundColor('#14213D')
              .fontColor('#FFFFFF')
              .onClick(async () => {
                await this.chooseImage();
              })

            Button($r('app.string.sample_image'))
              .layoutWeight(1)
              .height(46)
              .borderRadius(14)
              .backgroundColor('#E9ECEF')
              .fontColor('#14213D')
              .onClick(() => {
                this.resetToSample();
              })
          }
        }
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)

        Column({ space: 12 }) {
          Row() {
            Text($r('app.string.framing_label'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#14213D')
              .layoutWeight(1)
            Text(this.framingExpanded ? '▾' : '▸')
              .fontSize(18)
              .fontColor('#4F5D75')
          }
          .onClick(() => {
            this.framingExpanded = !this.framingExpanded;
          })

          if (this.framingExpanded) {
            Row({ space: 10 }) {
              Button($r('app.string.rotate_left'))
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor('#E9ECEF')
                .fontColor('#14213D')
                .onClick(() => {
                  this.applyTransform(withRotationDelta(this.previewTransform, -1));
                })

              Button($r('app.string.rotate_right'))
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor('#E9ECEF')
                .fontColor('#14213D')
                .onClick(() => {
                  this.applyTransform(withRotationDelta(this.previewTransform, 1));
                })

              Button($r('app.string.reset_transform'))
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor('#E9ECEF')
                .fontColor('#14213D')
                .onClick(() => {
                  this.applyTransform(createDefaultTransformState());
                })
            }

            Row({ space: 10 }) {
              Button($r('app.string.zoom_in'))
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor('#FFF3E0')
                .fontColor('#9A3412')
                .onClick(() => {
                  this.applyTransform(withZoomDelta(this.previewTransform, 0.1));
                })

              Button($r('app.string.zoom_out'))
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor('#FFF3E0')
                .fontColor('#9A3412')
                .onClick(() => {
                  this.applyTransform(withZoomDelta(this.previewTransform, -0.1));
                })
            }

            Row({ space: 10 }) {
              Button($r('app.string.pan_up'))
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor('#EEF2FF')
                .fontColor('#1D4ED8')
                .onClick(() => {
                  this.applyTransform(withPanDelta(this.previewTransform, 0, -0.1));
                })

              Button($r('app.string.pan_down'))
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor('#EEF2FF')
                .fontColor('#1D4ED8')
                .onClick(() => {
                  this.applyTransform(withPanDelta(this.previewTransform, 0, 0.1));
                })
            }

            Row({ space: 10 }) {
              Button($r('app.string.pan_left'))
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor('#EEF2FF')
                .fontColor('#1D4ED8')
                .onClick(() => {
                  this.applyTransform(withPanDelta(this.previewTransform, -0.1, 0));
                })

              Button($r('app.string.pan_right'))
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor('#EEF2FF')
                .fontColor('#1D4ED8')
                .onClick(() => {
                  this.applyTransform(withPanDelta(this.previewTransform, 0.1, 0));
                })
            }
          }
        }
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)

        Column({ space: 12 }) {
          Text($r('app.string.export_label'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#14213D')
          TextInput({ text: this.exportFileName, placeholder: 'sstv_robot36.wav' })
            .onChange((value: string) => {
              this.exportFileName = sanitizeExportFileName(value, this.selectedModeId);
            })

          Button(this.exportBusy ? $r('app.string.export_busy') : $r('app.string.export_wave'))
            .enabled(!this.exportBusy && !this.playBusy)
            .height(48)
            .borderRadius(14)
            .backgroundColor('#F77F00')
            .fontColor('#FFFFFF')
            .onClick(async () => {
              await this.exportWave();
            })
        }
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)

        Column({ space: 8 }) {
          Text($r('app.string.status_label'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#14213D')
          Text(this.status)
            .fontSize(14)
            .fontColor('#4F5D75')
            .lineHeight(20)
        }
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)
      }
      .padding(20)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF7F1')
  }

  build() {
    if (this.showingAbout) {
      this.buildAboutPage();
    } else {
      this.buildHomePage();
    }
  }
}
