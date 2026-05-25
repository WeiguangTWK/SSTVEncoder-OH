if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Index_Params {
    imagePath?: string;
    exportFileName?: string;
    useSampleImage?: boolean;
    selectedImageName?: string;
    selectedModeId?: string;
    exportBusy?: boolean;
    playBusy?: boolean;
    preparingPlayback?: boolean;
    status?: string;
    previewTransform?: ImageTransformState;
    previewWidth?: number;
    previewHeight?: number;
    currentScanLine?: number;
    framingExpanded?: boolean;
    playbackGeneration?: number;
}
import type common from "@ohos:app.ability.common";
import window from "@ohos:window";
import photoAccessHelper from "@ohos:file.photoAccessHelper";
import { AudioPlaybackService } from "@normalized:N&&&sstvencoder/src/main/ets/services/media/AudioPlaybackService&";
import type { PlaybackCallbacks } from "@normalized:N&&&sstvencoder/src/main/ets/services/media/AudioPlaybackService&";
import { ExportRequest, ExportService, sanitizeExportFileName } from "@normalized:N&&&sstvencoder/src/main/ets/services/media/ExportService&";
import type { ImageTransformState } from '../model/SstvTypes';
import { createDefaultTransformState, withPanDelta, withRotationDelta, withZoomDelta, } from "@normalized:N&&&sstvencoder/src/main/ets/services/sstv/ImageTransform&";
import { getModeById, SSTV_MODES } from "@normalized:N&&&sstvencoder/src/main/ets/services/sstv/SstvModes&";
import { ImageLoader } from "@normalized:N&&&sstvencoder/src/main/ets/services/media/ImageLoader&";
import { renderImageForMode } from "@normalized:N&&&sstvencoder/src/main/ets/services/sstv/ImageTransform&";
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
class Index extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__imagePath = new ObservedPropertySimplePU('', this, "imagePath");
        this.__exportFileName = new ObservedPropertySimplePU('sstv_robot36.wav', this, "exportFileName");
        this.__useSampleImage = new ObservedPropertySimplePU(true, this, "useSampleImage");
        this.__selectedImageName = new ObservedPropertySimplePU('', this, "selectedImageName");
        this.__selectedModeId = new ObservedPropertySimplePU('robot36', this, "selectedModeId");
        this.__exportBusy = new ObservedPropertySimplePU(false, this, "exportBusy");
        this.__playBusy = new ObservedPropertySimplePU(false, this, "playBusy");
        this.__preparingPlayback = new ObservedPropertySimplePU(false, this, "preparingPlayback");
        this.__status = new ObservedPropertySimplePU('就绪 Ready', this, "status");
        this.__previewTransform = new ObservedPropertyObjectPU(createDefaultTransformState(), this, "previewTransform");
        this.__previewWidth = new ObservedPropertySimplePU(0, this, "previewWidth");
        this.__previewHeight = new ObservedPropertySimplePU(0, this, "previewHeight");
        this.__currentScanLine = new ObservedPropertySimplePU(0, this, "currentScanLine");
        this.__framingExpanded = new ObservedPropertySimplePU(false, this, "framingExpanded");
        this.playbackGeneration = 0;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Index_Params) {
        if (params.imagePath !== undefined) {
            this.imagePath = params.imagePath;
        }
        if (params.exportFileName !== undefined) {
            this.exportFileName = params.exportFileName;
        }
        if (params.useSampleImage !== undefined) {
            this.useSampleImage = params.useSampleImage;
        }
        if (params.selectedImageName !== undefined) {
            this.selectedImageName = params.selectedImageName;
        }
        if (params.selectedModeId !== undefined) {
            this.selectedModeId = params.selectedModeId;
        }
        if (params.exportBusy !== undefined) {
            this.exportBusy = params.exportBusy;
        }
        if (params.playBusy !== undefined) {
            this.playBusy = params.playBusy;
        }
        if (params.preparingPlayback !== undefined) {
            this.preparingPlayback = params.preparingPlayback;
        }
        if (params.status !== undefined) {
            this.status = params.status;
        }
        if (params.previewTransform !== undefined) {
            this.previewTransform = params.previewTransform;
        }
        if (params.previewWidth !== undefined) {
            this.previewWidth = params.previewWidth;
        }
        if (params.previewHeight !== undefined) {
            this.previewHeight = params.previewHeight;
        }
        if (params.currentScanLine !== undefined) {
            this.currentScanLine = params.currentScanLine;
        }
        if (params.framingExpanded !== undefined) {
            this.framingExpanded = params.framingExpanded;
        }
        if (params.playbackGeneration !== undefined) {
            this.playbackGeneration = params.playbackGeneration;
        }
    }
    updateStateVars(params: Index_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__imagePath.purgeDependencyOnElmtId(rmElmtId);
        this.__exportFileName.purgeDependencyOnElmtId(rmElmtId);
        this.__useSampleImage.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedImageName.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedModeId.purgeDependencyOnElmtId(rmElmtId);
        this.__exportBusy.purgeDependencyOnElmtId(rmElmtId);
        this.__playBusy.purgeDependencyOnElmtId(rmElmtId);
        this.__preparingPlayback.purgeDependencyOnElmtId(rmElmtId);
        this.__status.purgeDependencyOnElmtId(rmElmtId);
        this.__previewTransform.purgeDependencyOnElmtId(rmElmtId);
        this.__previewWidth.purgeDependencyOnElmtId(rmElmtId);
        this.__previewHeight.purgeDependencyOnElmtId(rmElmtId);
        this.__currentScanLine.purgeDependencyOnElmtId(rmElmtId);
        this.__framingExpanded.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__imagePath.aboutToBeDeleted();
        this.__exportFileName.aboutToBeDeleted();
        this.__useSampleImage.aboutToBeDeleted();
        this.__selectedImageName.aboutToBeDeleted();
        this.__selectedModeId.aboutToBeDeleted();
        this.__exportBusy.aboutToBeDeleted();
        this.__playBusy.aboutToBeDeleted();
        this.__preparingPlayback.aboutToBeDeleted();
        this.__status.aboutToBeDeleted();
        this.__previewTransform.aboutToBeDeleted();
        this.__previewWidth.aboutToBeDeleted();
        this.__previewHeight.aboutToBeDeleted();
        this.__currentScanLine.aboutToBeDeleted();
        this.__framingExpanded.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __imagePath: ObservedPropertySimplePU<string>;
    get imagePath() {
        return this.__imagePath.get();
    }
    set imagePath(newValue: string) {
        this.__imagePath.set(newValue);
    }
    private __exportFileName: ObservedPropertySimplePU<string>;
    get exportFileName() {
        return this.__exportFileName.get();
    }
    set exportFileName(newValue: string) {
        this.__exportFileName.set(newValue);
    }
    private __useSampleImage: ObservedPropertySimplePU<boolean>;
    get useSampleImage() {
        return this.__useSampleImage.get();
    }
    set useSampleImage(newValue: boolean) {
        this.__useSampleImage.set(newValue);
    }
    private __selectedImageName: ObservedPropertySimplePU<string>;
    get selectedImageName() {
        return this.__selectedImageName.get();
    }
    set selectedImageName(newValue: string) {
        this.__selectedImageName.set(newValue);
    }
    private __selectedModeId: ObservedPropertySimplePU<string>;
    get selectedModeId() {
        return this.__selectedModeId.get();
    }
    set selectedModeId(newValue: string) {
        this.__selectedModeId.set(newValue);
    }
    private __exportBusy: ObservedPropertySimplePU<boolean>;
    get exportBusy() {
        return this.__exportBusy.get();
    }
    set exportBusy(newValue: boolean) {
        this.__exportBusy.set(newValue);
    }
    private __playBusy: ObservedPropertySimplePU<boolean>;
    get playBusy() {
        return this.__playBusy.get();
    }
    set playBusy(newValue: boolean) {
        this.__playBusy.set(newValue);
    }
    private __preparingPlayback: ObservedPropertySimplePU<boolean>;
    get preparingPlayback() {
        return this.__preparingPlayback.get();
    }
    set preparingPlayback(newValue: boolean) {
        this.__preparingPlayback.set(newValue);
    }
    private __status: ObservedPropertySimplePU<string>;
    get status() {
        return this.__status.get();
    }
    set status(newValue: string) {
        this.__status.set(newValue);
    }
    private __previewTransform: ObservedPropertyObjectPU<ImageTransformState>;
    get previewTransform() {
        return this.__previewTransform.get();
    }
    set previewTransform(newValue: ImageTransformState) {
        this.__previewTransform.set(newValue);
    }
    private __previewWidth: ObservedPropertySimplePU<number>;
    get previewWidth() {
        return this.__previewWidth.get();
    }
    set previewWidth(newValue: number) {
        this.__previewWidth.set(newValue);
    }
    private __previewHeight: ObservedPropertySimplePU<number>;
    get previewHeight() {
        return this.__previewHeight.get();
    }
    set previewHeight(newValue: number) {
        this.__previewHeight.set(newValue);
    }
    private __currentScanLine: ObservedPropertySimplePU<number>;
    get currentScanLine() {
        return this.__currentScanLine.get();
    }
    set currentScanLine(newValue: number) {
        this.__currentScanLine.set(newValue);
    }
    private __framingExpanded: ObservedPropertySimplePU<boolean>;
    get framingExpanded() {
        return this.__framingExpanded.get();
    }
    set framingExpanded(newValue: boolean) {
        this.__framingExpanded.set(newValue);
    }
    private playbackGeneration: number;
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
        this.status = '就绪 Ready';
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
                this.status = '已取消选择 Cancelled';
                return;
            }
            await this.stopPlaybackAndResetLine();
            this.imagePath = pickerResult.photoUris[0];
            this.useSampleImage = false;
            this.selectedImageName = this.fileNameFromUri(this.imagePath);
            this.status = '已选择图片 Image selected';
        }
        catch (error) {
            const message = (error as Error).message;
            this.status = `选择图片失败 Choose failed: ${message}`;
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
        this.status = '已停止 Stopped';
        await this.setKeepScreenOn(false);
        await AudioPlaybackService.stop();
    }
    private async setKeepScreenOn(keepOn: boolean): Promise<void> {
        try {
            const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            const appWindow = await window.getLastWindow(context);
            await appWindow.setWindowKeepScreenOn(keepOn);
        }
        catch (_ignore) {
        }
    }
    private applyTransform(nextState: ImageTransformState): void {
        if (this.playBusy) {
            void this.stopPlaybackAndResetLine();
        }
        else {
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
        }
        else {
            void this.setKeepScreenOn(false);
        }
        if (!isPlaying && this.status === '播放中 Playing...') {
            this.status = '播放完成 Completed';
        }
    }
    private async exportWave(): Promise<void> {
        if (this.exportBusy || this.playBusy) {
            return;
        }
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        this.exportFileName = sanitizeExportFileName(this.exportFileName, this.selectedModeId);
        this.exportBusy = true;
        this.status = '导出中 Exporting...';
        try {
            const request = new ExportRequest(this.imagePath, this.exportFileName, this.useSampleImage, this.getCurrentMode(), this.previewTransform);
            const outputPath = await ExportService.exportWave(context, request);
            this.status = `已导出 Exported: ${outputPath}`;
        }
        catch (error) {
            const message = (error as Error).message;
            this.status = `失败 Failed: ${message}`;
        }
        finally {
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
        this.status = '准备中 Preparing...';
        try {
            const preparedImage = await this.loadPreparedImage(context);
            if (generation !== this.playbackGeneration) {
                return;
            }
            this.playBusy = true;
            this.preparingPlayback = false;
            this.status = '播放中 Playing...';
            await this.setKeepScreenOn(true);
            await AudioPlaybackService.playStreamed(preparedImage, this.getCurrentMode(), new PlaybackObserver(this, generation));
        }
        catch (error) {
            if (generation !== this.playbackGeneration) {
                return;
            }
            this.preparingPlayback = false;
            const message = (error as Error).message;
            this.playBusy = false;
            await this.setKeepScreenOn(false);
            this.status = `播放失败 Playback failed: ${message}`;
        }
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("sstvencoder/src/main/ets/pages/Index.ets(263:5)", "sstvencoder");
            Scroll.width('100%');
            Scroll.height('100%');
            Scroll.backgroundColor('#FFF7F1');
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 18 });
            Column.debugLine("sstvencoder/src/main/ets/pages/Index.ets(264:7)", "sstvencoder");
            Column.padding(20);
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 8 });
            Column.debugLine("sstvencoder/src/main/ets/pages/Index.ets(265:9)", "sstvencoder");
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('SSTV Encoder');
            Text.debugLine("sstvencoder/src/main/ets/pages/Index.ets(266:11)", "sstvencoder");
            Text.fontSize(28);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#14213D');
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("sstvencoder/src/main/ets/pages/Index.ets(273:9)", "sstvencoder");
            Column.padding(20);
            Column.backgroundColor('#FFFFFF');
            Column.borderRadius(24);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 12 });
            Row.debugLine("sstvencoder/src/main/ets/pages/Index.ets(274:11)", "sstvencoder");
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 10 });
            Column.debugLine("sstvencoder/src/main/ets/pages/Index.ets(275:13)", "sstvencoder");
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('模式 Mode');
            Text.debugLine("sstvencoder/src/main/ets/pages/Index.ets(276:15)", "sstvencoder");
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor('#14213D');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Select.create(this.getModeOptions());
            Select.debugLine("sstvencoder/src/main/ets/pages/Index.ets(280:15)", "sstvencoder");
            Select.selected(this.getSelectedModeIndex());
            Select.value(this.getCurrentMode().name);
            Select.onSelect(async (index: number) => {
                if (this.playBusy) {
                    await this.stopPlaybackAndResetLine();
                }
                else {
                    this.currentScanLine = 0;
                }
                this.selectedModeId = SSTV_MODES[index].id;
                this.exportFileName = sanitizeExportFileName(`sstv_${this.selectedModeId}.wav`, this.selectedModeId);
            });
        }, Select);
        Select.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.preparingPlayback ? '准备中 Preparing' : (this.playBusy ? '停止 Stop' : '开始 Start'));
            Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(295:13)", "sstvencoder");
            Button.width(92);
            Button.height(42);
            Button.borderRadius(12);
            Button.enabled(!this.exportBusy && !this.preparingPlayback);
            Button.backgroundColor('#E9ECEF');
            Button.fontColor('#14213D');
            Button.opacity(this.exportBusy || this.preparingPlayback ? 0.45 : 1);
            Button.onClick(async () => {
                if (this.exportBusy || this.preparingPlayback) {
                    return;
                }
                if (this.playBusy) {
                    await this.stopPlaybackAndResetLine();
                    return;
                }
                await this.playWave();
            });
        }, Button);
        Button.pop();
        Row.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("sstvencoder/src/main/ets/pages/Index.ets(319:9)", "sstvencoder");
            Column.padding(20);
            Column.backgroundColor('#FFFFFF');
            Column.borderRadius(24);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (!this.useSampleImage && this.selectedImageName.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.selectedImageName);
                        Text.debugLine("sstvencoder/src/main/ets/pages/Index.ets(321:13)", "sstvencoder");
                        Text.fontSize(14);
                        Text.fontColor('#4F5D75');
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("sstvencoder/src/main/ets/pages/Index.ets(326:11)", "sstvencoder");
            Stack.width('100%');
            Stack.aspectRatio(this.getPreviewAspectRatio());
            Stack.backgroundColor('#F4F4F4');
            Stack.borderRadius(22);
            Stack.clip(true);
            Stack.onAreaChange((_oldValue, newValue) => {
                this.previewWidth = Number(newValue.width);
                this.previewHeight = Number(newValue.height);
            });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.useSampleImage) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Image.create({ "id": 0, "type": 30000, params: ['smpte_color_bars.png'], "bundleName": "om.nhsystems.sstvencoder", "moduleName": "sstvencoder" });
                        Image.debugLine("sstvencoder/src/main/ets/pages/Index.ets(328:15)", "sstvencoder");
                        Image.width('100%');
                        Image.height('100%');
                        Image.objectFit(ImageFit.Cover);
                        Image.rotate({ angle: this.previewTransform.rotationQuarterTurns * 90 });
                        Image.scale({ x: this.previewTransform.zoom, y: this.previewTransform.zoom });
                        Image.translate({ x: this.getPreviewTranslateX(), y: this.getPreviewTranslateY() });
                    }, Image);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Image.create(this.imagePath);
                        Image.debugLine("sstvencoder/src/main/ets/pages/Index.ets(336:15)", "sstvencoder");
                        Image.width('100%');
                        Image.height('100%');
                        Image.objectFit(ImageFit.Cover);
                        Image.rotate({ angle: this.previewTransform.rotationQuarterTurns * 90 });
                        Image.scale({ x: this.previewTransform.zoom, y: this.previewTransform.zoom });
                        Image.translate({ x: this.getPreviewTranslateX(), y: this.getPreviewTranslateY() });
                    }, Image);
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.playBusy) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.debugLine("sstvencoder/src/main/ets/pages/Index.ets(346:15)", "sstvencoder");
                        Row.width('100%');
                        Row.height(2);
                        Row.backgroundColor('#E63946');
                        Row.position({ x: 0, y: this.getPreviewLineTop() });
                    }, Row);
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.playBusy) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(`扫描行 Scan Line ${this.currentScanLine + 1}/${this.getCurrentMode().height}`);
                        Text.debugLine("sstvencoder/src/main/ets/pages/Index.ets(364:13)", "sstvencoder");
                        Text.fontSize(13);
                        Text.fontColor('#4F5D75');
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.debugLine("sstvencoder/src/main/ets/pages/Index.ets(369:11)", "sstvencoder");
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('选择图片 Choose');
            Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(370:13)", "sstvencoder");
            Button.layoutWeight(1);
            Button.height(46);
            Button.borderRadius(14);
            Button.backgroundColor('#14213D');
            Button.fontColor('#FFFFFF');
            Button.onClick(async () => {
                await this.chooseImage();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('示例 Sample');
            Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(380:13)", "sstvencoder");
            Button.layoutWeight(1);
            Button.height(46);
            Button.borderRadius(14);
            Button.backgroundColor('#E9ECEF');
            Button.fontColor('#14213D');
            Button.onClick(() => {
                this.resetToSample();
            });
        }, Button);
        Button.pop();
        Row.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("sstvencoder/src/main/ets/pages/Index.ets(395:9)", "sstvencoder");
            Column.padding(20);
            Column.backgroundColor('#FFFFFF');
            Column.borderRadius(24);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("sstvencoder/src/main/ets/pages/Index.ets(396:11)", "sstvencoder");
            Row.onClick(() => {
                this.framingExpanded = !this.framingExpanded;
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('构图 Framing');
            Text.debugLine("sstvencoder/src/main/ets/pages/Index.ets(397:13)", "sstvencoder");
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor('#14213D');
            Text.layoutWeight(1);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.framingExpanded ? '▾' : '▸');
            Text.debugLine("sstvencoder/src/main/ets/pages/Index.ets(402:13)", "sstvencoder");
            Text.fontSize(18);
            Text.fontColor('#4F5D75');
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.framingExpanded) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.debugLine("sstvencoder/src/main/ets/pages/Index.ets(411:13)", "sstvencoder");
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('左转 Rotate L');
                        Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(412:15)", "sstvencoder");
                        Button.layoutWeight(1);
                        Button.height(42);
                        Button.borderRadius(12);
                        Button.backgroundColor('#E9ECEF');
                        Button.fontColor('#14213D');
                        Button.onClick(() => {
                            this.applyTransform(withRotationDelta(this.previewTransform, -1));
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('右转 Rotate R');
                        Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(422:15)", "sstvencoder");
                        Button.layoutWeight(1);
                        Button.height(42);
                        Button.borderRadius(12);
                        Button.backgroundColor('#E9ECEF');
                        Button.fontColor('#14213D');
                        Button.onClick(() => {
                            this.applyTransform(withRotationDelta(this.previewTransform, 1));
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('重置 Reset');
                        Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(432:15)", "sstvencoder");
                        Button.layoutWeight(1);
                        Button.height(42);
                        Button.borderRadius(12);
                        Button.backgroundColor('#E9ECEF');
                        Button.fontColor('#14213D');
                        Button.onClick(() => {
                            this.applyTransform(createDefaultTransformState());
                        });
                    }, Button);
                    Button.pop();
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.debugLine("sstvencoder/src/main/ets/pages/Index.ets(443:13)", "sstvencoder");
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('放大 Zoom +');
                        Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(444:15)", "sstvencoder");
                        Button.layoutWeight(1);
                        Button.height(42);
                        Button.borderRadius(12);
                        Button.backgroundColor('#FFF3E0');
                        Button.fontColor('#9A3412');
                        Button.onClick(() => {
                            this.applyTransform(withZoomDelta(this.previewTransform, 0.1));
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('缩小 Zoom -');
                        Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(454:15)", "sstvencoder");
                        Button.layoutWeight(1);
                        Button.height(42);
                        Button.borderRadius(12);
                        Button.backgroundColor('#FFF3E0');
                        Button.fontColor('#9A3412');
                        Button.onClick(() => {
                            this.applyTransform(withZoomDelta(this.previewTransform, -0.1));
                        });
                    }, Button);
                    Button.pop();
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.debugLine("sstvencoder/src/main/ets/pages/Index.ets(465:13)", "sstvencoder");
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('上移 Up');
                        Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(466:15)", "sstvencoder");
                        Button.layoutWeight(1);
                        Button.height(42);
                        Button.borderRadius(12);
                        Button.backgroundColor('#EEF2FF');
                        Button.fontColor('#1D4ED8');
                        Button.onClick(() => {
                            this.applyTransform(withPanDelta(this.previewTransform, 0, -0.1));
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('下移 Down');
                        Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(476:15)", "sstvencoder");
                        Button.layoutWeight(1);
                        Button.height(42);
                        Button.borderRadius(12);
                        Button.backgroundColor('#EEF2FF');
                        Button.fontColor('#1D4ED8');
                        Button.onClick(() => {
                            this.applyTransform(withPanDelta(this.previewTransform, 0, 0.1));
                        });
                    }, Button);
                    Button.pop();
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.debugLine("sstvencoder/src/main/ets/pages/Index.ets(487:13)", "sstvencoder");
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('左移 Left');
                        Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(488:15)", "sstvencoder");
                        Button.layoutWeight(1);
                        Button.height(42);
                        Button.borderRadius(12);
                        Button.backgroundColor('#EEF2FF');
                        Button.fontColor('#1D4ED8');
                        Button.onClick(() => {
                            this.applyTransform(withPanDelta(this.previewTransform, -0.1, 0));
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('右移 Right');
                        Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(498:15)", "sstvencoder");
                        Button.layoutWeight(1);
                        Button.height(42);
                        Button.borderRadius(12);
                        Button.backgroundColor('#EEF2FF');
                        Button.fontColor('#1D4ED8');
                        Button.onClick(() => {
                            this.applyTransform(withPanDelta(this.previewTransform, 0.1, 0));
                        });
                    }, Button);
                    Button.pop();
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("sstvencoder/src/main/ets/pages/Index.ets(514:9)", "sstvencoder");
            Column.padding(20);
            Column.backgroundColor('#FFFFFF');
            Column.borderRadius(24);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('导出 Export');
            Text.debugLine("sstvencoder/src/main/ets/pages/Index.ets(515:11)", "sstvencoder");
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor('#14213D');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ text: this.exportFileName, placeholder: 'sstv_robot36.wav' });
            TextInput.debugLine("sstvencoder/src/main/ets/pages/Index.ets(519:11)", "sstvencoder");
            TextInput.onChange((value: string) => {
                this.exportFileName = sanitizeExportFileName(value, this.selectedModeId);
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.exportBusy ? '导出中 Exporting...' : '导出 WAV');
            Button.debugLine("sstvencoder/src/main/ets/pages/Index.ets(524:11)", "sstvencoder");
            Button.enabled(!this.exportBusy && !this.playBusy);
            Button.height(48);
            Button.borderRadius(14);
            Button.backgroundColor('#F77F00');
            Button.fontColor('#FFFFFF');
            Button.onClick(async () => {
                await this.exportWave();
            });
        }, Button);
        Button.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 8 });
            Column.debugLine("sstvencoder/src/main/ets/pages/Index.ets(538:9)", "sstvencoder");
            Column.alignItems(HorizontalAlign.Start);
            Column.padding(20);
            Column.backgroundColor('#FFFFFF');
            Column.borderRadius(24);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('状态 Status');
            Text.debugLine("sstvencoder/src/main/ets/pages/Index.ets(539:11)", "sstvencoder");
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor('#14213D');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.status);
            Text.debugLine("sstvencoder/src/main/ets/pages/Index.ets(543:11)", "sstvencoder");
            Text.fontSize(14);
            Text.fontColor('#4F5D75');
            Text.lineHeight(20);
        }, Text);
        Text.pop();
        Column.pop();
        Column.pop();
        Scroll.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Index";
    }
}
registerNamedRoute(() => new Index(undefined, {}), "", { bundleName: "om.nhsystems.sstvencoder", moduleName: "sstvencoder", pagePath: "pages/Index", pageFullPath: "sstvencoder/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });
