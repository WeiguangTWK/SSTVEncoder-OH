export enum SstvFamily {
  MARTIN = 'Martin',
  SCOTTIE = 'Scottie',
  ROBOT36 = 'Robot36',
  ROBOT72 = 'Robot72',
  PD = 'PD',
  WRAASE = 'Wraase',
}

export interface SstvModeDefinition {
  id: string;
  name: string;
  family: SstvFamily;
  width: number;
  height: number;
  visCode: number;
  colorScanDurationMs?: number;
  linePairScanDurationMs?: number;
}

export interface PixelImage {
  width: number;
  height: number;
  getPixel(x: number, y: number): number;
}

export class ImageTransformState {
  rotationQuarterTurns: number;
  zoom: number;
  panX: number;
  panY: number;

  constructor(rotationQuarterTurns: number = 0, zoom: number = 1, panX: number = 0, panY: number = 0) {
    this.rotationQuarterTurns = rotationQuarterTurns;
    this.zoom = zoom;
    this.panX = panX;
    this.panY = panY;
  }
}

export class RgbaPixelImage implements PixelImage {
  width: number;
  height: number;
  private pixels: Uint32Array;

  constructor(width: number, height: number, pixels: Uint32Array) {
    this.width = width;
    this.height = height;
    this.pixels = pixels;
  }

  getPixel(x: number, y: number): number {
    return this.pixels[(y * this.width) + x];
  }
}

export interface EncodeResult {
  sampleRate: number;
  pcm: Int16Array;
  mode: SstvModeDefinition;
  lineEnds: Array<number>;
}

export function redOf(pixel: number): number {
  return (pixel >>> 16) & 0xff;
}

export function greenOf(pixel: number): number {
  return (pixel >>> 8) & 0xff;
}

export function blueOf(pixel: number): number {
  return pixel & 0xff;
}
