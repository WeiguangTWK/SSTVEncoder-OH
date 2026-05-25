import type common from "@ohos:app.ability.common";
import fs from "@ohos:file.fs";
import image from "@ohos:multimedia.image";
import { RgbaPixelImage } from "@normalized:N&&&sstvencoder/src/main/ets/model/SstvTypes&";
class PixelImageInfo {
    width: number;
    height: number;
    constructor(width: number, height: number) {
        this.width = width;
        this.height = height;
    }
}
class OpenImageFile {
    fd: number;
    constructor(fd: number) {
        this.fd = fd;
    }
}
function toArrayBuffer(rawContent: Uint8Array): ArrayBuffer {
    return rawContent.buffer.slice(rawContent.byteOffset, rawContent.byteOffset + rawContent.byteLength);
}
function decodeBgraToArgb(pixelBuffer: ArrayBuffer, width: number, height: number): Uint32Array {
    const bytes = new Uint8Array(pixelBuffer);
    const pixels = new Uint32Array(width * height);
    let byteOffset = 0;
    for (let i = 0; i < pixels.length; i += 1) {
        const blue = bytes[byteOffset];
        const green = bytes[byteOffset + 1];
        const red = bytes[byteOffset + 2];
        const alpha = bytes[byteOffset + 3];
        pixels[i] = (alpha << 24) | (red << 16) | (green << 8) | blue;
        byteOffset += 4;
    }
    return pixels;
}
async function pixelMapToImage(pixelMap: image.PixelMap): Promise<RgbaPixelImage> {
    const imageInfo = await pixelMap.getImageInfo();
    const info = new PixelImageInfo(imageInfo.size.width, imageInfo.size.height);
    const pixelBuffer = new ArrayBuffer(pixelMap.getPixelBytesNumber());
    await pixelMap.readPixelsToBuffer(pixelBuffer);
    return new RgbaPixelImage(info.width, info.height, decodeBgraToArgb(pixelBuffer, info.width, info.height));
}
export class ImageLoader {
    static async loadSampleImage(context: common.UIAbilityContext): Promise<RgbaPixelImage> {
        try {
            const rawFileContent = await context.resourceManager.getRawFileContent('smpte_color_bars.png');
            const imageSource = image.createImageSource(toArrayBuffer(rawFileContent));
            const pixelMap = await imageSource.createPixelMap();
            return await pixelMapToImage(pixelMap);
        }
        catch (error) {
            const message = (error as Error).message;
            throw new Error(`Failed to load sample image: ${message}`);
        }
    }
    static async loadFromPath(path: string): Promise<RgbaPixelImage> {
        let file: OpenImageFile | null = null;
        try {
            const opened = fs.openSync(path, fs.OpenMode.READ_ONLY);
            file = new OpenImageFile(opened.fd);
            const imageSource = image.createImageSource(file.fd);
            const pixelMap = await imageSource.createPixelMap();
            return await pixelMapToImage(pixelMap);
        }
        catch (error) {
            const message = (error as Error).message;
            throw new Error(`Failed to decode image: ${message}`);
        }
        finally {
            if (file !== null) {
                try {
                    fs.closeSync(file.fd);
                }
                catch (_ignore) {
                }
            }
        }
    }
}
