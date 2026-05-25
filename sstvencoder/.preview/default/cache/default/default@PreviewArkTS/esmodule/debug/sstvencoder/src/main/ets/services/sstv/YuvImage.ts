import { blueOf, greenOf, redOf } from "@normalized:N&&&sstvencoder/src/main/ets/model/SstvTypes&";
import type { PixelImage } from "@normalized:N&&&sstvencoder/src/main/ets/model/SstvTypes&";
function clamp(value: number): number {
    if (value < 0) {
        return 0;
    }
    if (value > 255) {
        return 255;
    }
    return Math.floor(value);
}
function toY(pixel: number): number {
    const r = redOf(pixel);
    const g = greenOf(pixel);
    const b = blueOf(pixel);
    return clamp(16 + 0.003906 * ((65.738 * r) + (129.057 * g) + (25.064 * b)));
}
function toU(pixel: number): number {
    const r = redOf(pixel);
    const g = greenOf(pixel);
    const b = blueOf(pixel);
    return clamp(128 + 0.003906 * ((-37.945 * r) + (-74.494 * g) + (112.439 * b)));
}
function toV(pixel: number): number {
    const r = redOf(pixel);
    const g = greenOf(pixel);
    const b = blueOf(pixel);
    return clamp(128 + 0.003906 * ((112.439 * r) + (-94.154 * g) + (-18.285 * b)));
}
export class Robot36Yuv {
    private width: number;
    private height: number;
    private yPlane: Uint8Array;
    private uPlane: Uint8Array;
    private vPlane: Uint8Array;
    constructor(image: PixelImage) {
        this.width = image.width;
        this.height = image.height;
        this.yPlane = new Uint8Array(this.width * this.height);
        this.uPlane = new Uint8Array((this.width * this.height) >> 2);
        this.vPlane = new Uint8Array((this.width * this.height) >> 2);
        for (let y = 0; y < this.height; y += 1) {
            for (let x = 0; x < this.width; x += 1) {
                this.yPlane[(y * this.width) + x] = toY(image.getPixel(x, y));
            }
        }
        let pos = 0;
        for (let y = 0; y < this.height; y += 2) {
            for (let x = 0; x < this.width; x += 2) {
                const p0 = image.getPixel(x, y);
                const p1 = image.getPixel(Math.min(this.width - 1, x + 1), y);
                const p2 = image.getPixel(x, Math.min(this.height - 1, y + 1));
                const p3 = image.getPixel(Math.min(this.width - 1, x + 1), Math.min(this.height - 1, y + 1));
                this.vPlane[pos] = Math.floor((toV(p0) + toV(p1) + toV(p2) + toV(p3)) / 4);
                this.uPlane[pos] = Math.floor((toU(p0) + toU(p1) + toU(p2) + toU(p3)) / 4);
                pos += 1;
            }
        }
    }
    getWidth(): number {
        return this.width;
    }
    getY(x: number, y: number): number {
        return this.yPlane[(y * this.width) + x];
    }
    getU(x: number, y: number): number {
        const chromaWidth = this.width >> 1;
        return this.uPlane[((y >> 1) * chromaWidth) + (x >> 1)];
    }
    getV(x: number, y: number): number {
        const chromaWidth = this.width >> 1;
        return this.vPlane[((y >> 1) * chromaWidth) + (x >> 1)];
    }
}
export class PdYuv {
    private width: number;
    private height: number;
    private yPlane: Uint8Array;
    private uPlane: Uint8Array;
    private vPlane: Uint8Array;
    constructor(image: PixelImage) {
        this.width = image.width;
        this.height = image.height;
        this.yPlane = new Uint8Array(this.width * this.height);
        this.uPlane = new Uint8Array((this.width * this.height) >> 1);
        this.vPlane = new Uint8Array((this.width * this.height) >> 1);
        for (let y = 0; y < this.height; y += 1) {
            for (let x = 0; x < this.width; x += 1) {
                this.yPlane[(y * this.width) + x] = toY(image.getPixel(x, y));
            }
        }
        let uPos = 0;
        let vPos = 0;
        for (let y = 0; y < this.height; y += 2) {
            for (let x = 0; x < this.width; x += 1) {
                const topPixel = image.getPixel(x, y);
                const bottomPixel = image.getPixel(x, Math.min(this.height - 1, y + 1));
                this.uPlane[uPos] = Math.floor((toU(topPixel) + toU(bottomPixel)) / 2);
                this.vPlane[vPos] = Math.floor((toV(topPixel) + toV(bottomPixel)) / 2);
                uPos += 1;
                vPos += 1;
            }
        }
    }
    getWidth(): number {
        return this.width;
    }
    getY(x: number, y: number): number {
        return this.yPlane[(y * this.width) + x];
    }
    getU(x: number, y: number): number {
        return this.uPlane[((y >> 1) * this.width) + x];
    }
    getV(x: number, y: number): number {
        return this.vPlane[((y >> 1) * this.width) + x];
    }
}
export class Robot72Yuv {
    private width: number;
    private yPlane: Uint8Array;
    private uPlane: Uint8Array;
    private vPlane: Uint8Array;
    constructor(image: PixelImage) {
        this.width = image.width;
        this.yPlane = new Uint8Array(image.width * image.height);
        this.uPlane = new Uint8Array(image.width * image.height);
        this.vPlane = new Uint8Array(image.width * image.height);
        for (let y = 0; y < image.height; y += 1) {
            for (let x = 0; x < image.width; x += 2) {
                const left = image.getPixel(x, y);
                const right = image.getPixel(Math.min(image.width - 1, x + 1), y);
                const base = (y * image.width) + x;
                this.yPlane[base] = toY(left);
                this.yPlane[base + 1] = toY(right);
                const u = Math.floor((toU(left) + toU(right)) / 2);
                const v = Math.floor((toV(left) + toV(right)) / 2);
                this.uPlane[base] = u;
                this.uPlane[base + 1] = u;
                this.vPlane[base] = v;
                this.vPlane[base + 1] = v;
            }
        }
    }
    getWidth(): number {
        return this.width;
    }
    getY(x: number, y: number): number {
        return this.yPlane[(y * this.width) + x];
    }
    getU(x: number, y: number): number {
        return this.uPlane[(y * this.width) + x];
    }
    getV(x: number, y: number): number {
        return this.vPlane[(y * this.width) + x];
    }
}
