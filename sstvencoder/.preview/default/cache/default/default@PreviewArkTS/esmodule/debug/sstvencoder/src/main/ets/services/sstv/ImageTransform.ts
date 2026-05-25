import { ImageTransformState, RgbaPixelImage } from "@normalized:N&&&sstvencoder/src/main/ets/model/SstvTypes&";
import type { PixelImage, SstvModeDefinition } from "@normalized:N&&&sstvencoder/src/main/ets/model/SstvTypes&";
function clamp(value: number, minValue: number, maxValue: number): number {
    if (value < minValue) {
        return minValue;
    }
    if (value > maxValue) {
        return maxValue;
    }
    return value;
}
function normalizeQuarterTurns(turns: number): number {
    const normalized = turns % 4;
    return normalized < 0 ? normalized + 4 : normalized;
}
function getRotatedWidth(source: PixelImage, transform: ImageTransformState): number {
    return normalizeQuarterTurns(transform.rotationQuarterTurns) % 2 === 0 ? source.width : source.height;
}
function getRotatedHeight(source: PixelImage, transform: ImageTransformState): number {
    return normalizeQuarterTurns(transform.rotationQuarterTurns) % 2 === 0 ? source.height : source.width;
}
function readRotatedPixel(source: PixelImage, rotatedX: number, rotatedY: number, transform: ImageTransformState): number {
    const rotation = normalizeQuarterTurns(transform.rotationQuarterTurns);
    const x = Math.floor(rotatedX);
    const y = Math.floor(rotatedY);
    switch (rotation) {
        case 1:
            return source.getPixel(clamp(y, 0, source.width - 1), clamp(source.height - 1 - x, 0, source.height - 1));
        case 2:
            return source.getPixel(clamp(source.width - 1 - x, 0, source.width - 1), clamp(source.height - 1 - y, 0, source.height - 1));
        case 3:
            return source.getPixel(clamp(source.width - 1 - y, 0, source.width - 1), clamp(x, 0, source.height - 1));
        default:
            return source.getPixel(clamp(x, 0, source.width - 1), clamp(y, 0, source.height - 1));
    }
}
export function createDefaultTransformState(): ImageTransformState {
    return new ImageTransformState();
}
export function withRotationDelta(state: ImageTransformState, delta: number): ImageTransformState {
    return new ImageTransformState(state.rotationQuarterTurns + delta, state.zoom, state.panX, state.panY);
}
export function withZoomDelta(state: ImageTransformState, delta: number): ImageTransformState {
    return new ImageTransformState(state.rotationQuarterTurns, clamp(state.zoom + delta, 1, 3), state.panX, state.panY);
}
export function withPanDelta(state: ImageTransformState, deltaX: number, deltaY: number): ImageTransformState {
    return new ImageTransformState(state.rotationQuarterTurns, state.zoom, clamp(state.panX + deltaX, -1, 1), clamp(state.panY + deltaY, -1, 1));
}
export function renderImageForMode(source: PixelImage, mode: SstvModeDefinition, transform: ImageTransformState): RgbaPixelImage {
    const rotatedWidth = getRotatedWidth(source, transform);
    const rotatedHeight = getRotatedHeight(source, transform);
    const targetAspect = mode.width / mode.height;
    const rotatedAspect = rotatedWidth / rotatedHeight;
    let cropWidth = rotatedWidth;
    let cropHeight = rotatedHeight;
    if (rotatedAspect > targetAspect) {
        cropWidth = rotatedHeight * targetAspect;
    }
    else {
        cropHeight = rotatedWidth / targetAspect;
    }
    const zoom = clamp(transform.zoom, 1, 3);
    cropWidth /= zoom;
    cropHeight /= zoom;
    const maxOffsetX = Math.max(0, (rotatedWidth - cropWidth) / 2);
    const maxOffsetY = Math.max(0, (rotatedHeight - cropHeight) / 2);
    const centerX = (rotatedWidth / 2) + (clamp(transform.panX, -1, 1) * maxOffsetX);
    const centerY = (rotatedHeight / 2) + (clamp(transform.panY, -1, 1) * maxOffsetY);
    const left = clamp(centerX - (cropWidth / 2), 0, rotatedWidth - cropWidth);
    const top = clamp(centerY - (cropHeight / 2), 0, rotatedHeight - cropHeight);
    const pixels = new Uint32Array(mode.width * mode.height);
    for (let y = 0; y < mode.height; y += 1) {
        const rotatedY = top + ((y + 0.5) * cropHeight / mode.height);
        for (let x = 0; x < mode.width; x += 1) {
            const rotatedX = left + ((x + 0.5) * cropWidth / mode.width);
            pixels[(y * mode.width) + x] = readRotatedPixel(source, rotatedX, rotatedY, transform);
        }
    }
    return new RgbaPixelImage(mode.width, mode.height, pixels);
}
