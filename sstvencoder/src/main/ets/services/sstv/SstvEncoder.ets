import {
  blueOf,
  EncodeResult,
  greenOf,
  PixelImage,
  redOf,
  SstvFamily,
  SstvModeDefinition,
} from '../../model/SstvTypes';
import { PdYuv, Robot36Yuv, Robot72Yuv } from './YuvImage';

export interface StreamingEncodeCallbacks {
  onChunk(pcm: Int16Array): Promise<void>;
  onLineChanged(line: number): void;
  onLineEncoded(line: number, sampleCount: number): void;
}

class SampleWriter {
  protected sampleRate: number;
  protected samples: number[] = [];
  protected runningIntegral: number = 0;
  protected totalSampleCount: number = 0;

  constructor(sampleRate: number) {
    this.sampleRate = sampleRate;
  }

  convertMsToSamples(durationMs: number): number {
    return Math.round(durationMs * this.sampleRate / 1000);
  }

  tone(frequency: number): void {
    this.runningIntegral += (2 * frequency * Math.PI) / this.sampleRate;
    this.runningIntegral %= 2 * Math.PI;
    const value = Math.sin(this.runningIntegral);
    this.samples.push(Math.max(-1, Math.min(1, value)));
    this.totalSampleCount += 1;
  }

  colorTone(color: number): void {
    this.tone((color * 800 / 255) + 1500);
  }

  writeCalibrationHeader(visCode: number): void {
    const leaderSamples = this.convertMsToSamples(300);
    const breakSamples = this.convertMsToSamples(10);
    const bitSamples = this.convertMsToSamples(30);

    for (let i = 0; i < leaderSamples; i += 1) {
      this.tone(1900);
    }
    for (let i = 0; i < breakSamples; i += 1) {
      this.tone(1200);
    }
    for (let i = 0; i < leaderSamples; i += 1) {
      this.tone(1900);
    }
    for (let i = 0; i < bitSamples; i += 1) {
      this.tone(1200);
    }

    let parity = 0;
    for (let bit = 0; bit < 7; bit += 1) {
      const value = (visCode >> bit) & 1;
      parity ^= value;
      for (let i = 0; i < bitSamples; i += 1) {
        this.tone(value === 1 ? 1100 : 1300);
      }
    }

    for (let i = 0; i < bitSamples; i += 1) {
      this.tone(parity === 1 ? 1100 : 1300);
    }
    for (let i = 0; i < bitSamples; i += 1) {
      this.tone(1200);
    }
  }

  buildPcm(): Int16Array {
    const pcm = new Int16Array(this.samples.length);
    for (let i = 0; i < this.samples.length; i += 1) {
      pcm[i] = Math.round(this.samples[i] * 32767);
    }
    return pcm;
  }

  getSampleCount(): number {
    return this.totalSampleCount;
  }
}

class StreamingSampleWriter extends SampleWriter {
  constructor(sampleRate: number) {
    super(sampleRate);
  }

  flushPcm(): Int16Array {
    const pcm = new Int16Array(this.samples.length);
    for (let i = 0; i < this.samples.length; i += 1) {
      pcm[i] = Math.round(this.samples[i] * 32767);
    }
    this.samples = [];
    return pcm;
  }
}

function pixelAt(image: PixelImage, xSample: number, y: number, sampleCount: number): number {
  const x = Math.min(image.width - 1, Math.floor((xSample * image.width) / sampleCount));
  return image.getPixel(x, y);
}

function repeatTone(writer: SampleWriter, count: number, frequency: number): void {
  for (let i = 0; i < count; i += 1) {
    writer.tone(frequency);
  }
}

function encodeMartin(writer: SampleWriter, image: PixelImage, mode: SstvModeDefinition, lineEnds: Array<number>): void {
  const syncPulse = writer.convertMsToSamples(4.862);
  const syncPorch = writer.convertMsToSamples(0.572);
  const separator = writer.convertMsToSamples(0.572);
  const colorScan = writer.convertMsToSamples(mode.colorScanDurationMs ?? 0);

  for (let y = 0; y < image.height; y += 1) {
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, syncPorch, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(greenOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, separator, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(blueOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, separator, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(redOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, separator, 1500);
    lineEnds.push(writer.getSampleCount());
  }
}

function encodeScottie(writer: SampleWriter, image: PixelImage, mode: SstvModeDefinition, lineEnds: Array<number>): void {
  const syncPulse = writer.convertMsToSamples(9.0);
  const syncPorch = writer.convertMsToSamples(1.5);
  const separator = writer.convertMsToSamples(1.5);
  const colorScan = writer.convertMsToSamples(mode.colorScanDurationMs ?? 0);

  for (let y = 0; y < image.height; y += 1) {
    if (y === 0) {
      repeatTone(writer, syncPulse, 1200);
    }
    repeatTone(writer, separator, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(greenOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, separator, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(blueOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, syncPorch, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(redOf(pixelAt(image, i, y, colorScan)));
    }
    lineEnds.push(writer.getSampleCount());
  }
}

function encodeWraase(writer: SampleWriter, image: PixelImage, lineEnds: Array<number>): void {
  const syncPulse = writer.convertMsToSamples(5.5225);
  const porch = writer.convertMsToSamples(0.5);
  const colorScan = writer.convertMsToSamples(235.0);

  for (let y = 0; y < image.height; y += 1) {
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, porch, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(redOf(pixelAt(image, i, y, colorScan)));
    }
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(greenOf(pixelAt(image, i, y, colorScan)));
    }
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(blueOf(pixelAt(image, i, y, colorScan)));
    }
    lineEnds.push(writer.getSampleCount());
  }
}

function encodeRobot36(writer: SampleWriter, image: PixelImage, lineEnds: Array<number>): void {
  const yuv = new Robot36Yuv(image);
  const luma = writer.convertMsToSamples(88);
  const chroma = writer.convertMsToSamples(44);
  const syncPulse = writer.convertMsToSamples(9);
  const syncPorch = writer.convertMsToSamples(3);
  const porch = writer.convertMsToSamples(1.5);
  const separator = writer.convertMsToSamples(4.5);

  for (let y = 0; y < image.height; y += 1) {
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, syncPorch, 1500);
    for (let i = 0; i < luma; i += 1) {
      writer.colorTone(yuv.getY(Math.floor((i * yuv.getWidth()) / luma), y));
    }
    repeatTone(writer, separator, y % 2 === 0 ? 1500 : 2300);
    repeatTone(writer, porch, 1900);
    for (let i = 0; i < chroma; i += 1) {
      const x = Math.floor((i * yuv.getWidth()) / chroma);
      writer.colorTone(y % 2 === 0 ? yuv.getV(x, y) : yuv.getU(x, y));
    }
    lineEnds.push(writer.getSampleCount());
  }
}

function encodeRobot72(writer: SampleWriter, image: PixelImage, lineEnds: Array<number>): void {
  const yuv = new Robot72Yuv(image);
  const luma = writer.convertMsToSamples(138);
  const chroma = writer.convertMsToSamples(69);
  const syncPulse = writer.convertMsToSamples(9);
  const syncPorch = writer.convertMsToSamples(3);
  const porch = writer.convertMsToSamples(1.5);
  const separator = writer.convertMsToSamples(4.5);

  for (let y = 0; y < image.height; y += 1) {
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, syncPorch, 1500);
    for (let i = 0; i < luma; i += 1) {
      writer.colorTone(yuv.getY(Math.floor((i * yuv.getWidth()) / luma), y));
    }
    repeatTone(writer, separator, 1500);
    repeatTone(writer, porch, 1900);
    for (let i = 0; i < chroma; i += 1) {
      writer.colorTone(yuv.getV(Math.floor((i * yuv.getWidth()) / chroma), y));
    }
    repeatTone(writer, separator, 2300);
    repeatTone(writer, porch, 1900);
    for (let i = 0; i < chroma; i += 1) {
      writer.colorTone(yuv.getU(Math.floor((i * yuv.getWidth()) / chroma), y));
    }
    lineEnds.push(writer.getSampleCount());
  }
}

function encodePd(writer: SampleWriter, image: PixelImage, mode: SstvModeDefinition, lineEnds: Array<number>): void {
  const yuv = new PdYuv(image);
  const syncPulse = writer.convertMsToSamples(20);
  const porch = writer.convertMsToSamples(2.08);
  const colorScan = writer.convertMsToSamples(mode.colorScanDurationMs ?? 0);

  for (let y = 0; y < image.height; y += 2) {
    const lineBegin = writer.getSampleCount();
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, porch, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(yuv.getY(Math.floor((i * yuv.getWidth()) / colorScan), y));
    }
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(yuv.getV(Math.floor((i * yuv.getWidth()) / colorScan), y));
    }
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(yuv.getU(Math.floor((i * yuv.getWidth()) / colorScan), y));
    }
    const secondLine = Math.min(image.height - 1, y + 1);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(yuv.getY(Math.floor((i * yuv.getWidth()) / colorScan), secondLine));
    }
    const lineEnd = writer.getSampleCount();
    const midpoint = lineBegin + Math.floor((lineEnd - lineBegin) / 2);
    lineEnds.push(midpoint);
    if (lineEnds.length < image.height) {
      lineEnds.push(lineEnd);
    }
  }
}

export function encodeSstv(source: PixelImage, mode: SstvModeDefinition, sampleRate: number = 44100): EncodeResult {
  const writer = new SampleWriter(sampleRate);
  const lineEnds: Array<number> = [];
  writer.writeCalibrationHeader(mode.visCode);

  switch (mode.family) {
    case SstvFamily.MARTIN:
      encodeMartin(writer, source, mode, lineEnds);
      break;
    case SstvFamily.SCOTTIE:
      encodeScottie(writer, source, mode, lineEnds);
      break;
    case SstvFamily.ROBOT36:
      encodeRobot36(writer, source, lineEnds);
      break;
    case SstvFamily.ROBOT72:
      encodeRobot72(writer, source, lineEnds);
      break;
    case SstvFamily.PD:
      encodePd(writer, source, mode, lineEnds);
      break;
    case SstvFamily.WRAASE:
      encodeWraase(writer, source, lineEnds);
      break;
    default:
      encodeRobot36(writer, source, lineEnds);
      break;
  }

  return {
    sampleRate,
    pcm: writer.buildPcm(),
    mode,
    lineEnds,
  };
}

async function flushChunk(writer: StreamingSampleWriter, callbacks: StreamingEncodeCallbacks): Promise<void> {
  const pcm = writer.flushPcm();
  if (pcm.length > 0) {
    await callbacks.onChunk(pcm);
  }
}

async function streamMartin(writer: StreamingSampleWriter, image: PixelImage, mode: SstvModeDefinition,
  callbacks: StreamingEncodeCallbacks): Promise<void> {
  const syncPulse = writer.convertMsToSamples(4.862);
  const syncPorch = writer.convertMsToSamples(0.572);
  const separator = writer.convertMsToSamples(0.572);
  const colorScan = writer.convertMsToSamples(mode.colorScanDurationMs ?? 0);

  for (let y = 0; y < image.height; y += 1) {
    callbacks.onLineChanged(y);
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, syncPorch, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(greenOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, separator, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(blueOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, separator, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(redOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, separator, 1500);
    callbacks.onLineEncoded(y, writer.getSampleCount());
    await flushChunk(writer, callbacks);
  }
}

async function streamScottie(writer: StreamingSampleWriter, image: PixelImage, mode: SstvModeDefinition,
  callbacks: StreamingEncodeCallbacks): Promise<void> {
  const syncPulse = writer.convertMsToSamples(9.0);
  const syncPorch = writer.convertMsToSamples(1.5);
  const separator = writer.convertMsToSamples(1.5);
  const colorScan = writer.convertMsToSamples(mode.colorScanDurationMs ?? 0);

  for (let y = 0; y < image.height; y += 1) {
    callbacks.onLineChanged(y);
    if (y === 0) {
      repeatTone(writer, syncPulse, 1200);
    }
    repeatTone(writer, separator, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(greenOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, separator, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(blueOf(pixelAt(image, i, y, colorScan)));
    }
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, syncPorch, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(redOf(pixelAt(image, i, y, colorScan)));
    }
    callbacks.onLineEncoded(y, writer.getSampleCount());
    await flushChunk(writer, callbacks);
  }
}

async function streamWraase(writer: StreamingSampleWriter, image: PixelImage,
  callbacks: StreamingEncodeCallbacks): Promise<void> {
  const syncPulse = writer.convertMsToSamples(5.5225);
  const porch = writer.convertMsToSamples(0.5);
  const colorScan = writer.convertMsToSamples(235.0);

  for (let y = 0; y < image.height; y += 1) {
    callbacks.onLineChanged(y);
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, porch, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(redOf(pixelAt(image, i, y, colorScan)));
    }
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(greenOf(pixelAt(image, i, y, colorScan)));
    }
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(blueOf(pixelAt(image, i, y, colorScan)));
    }
    callbacks.onLineEncoded(y, writer.getSampleCount());
    await flushChunk(writer, callbacks);
  }
}

async function streamRobot36(writer: StreamingSampleWriter, image: PixelImage,
  callbacks: StreamingEncodeCallbacks): Promise<void> {
  const yuv = new Robot36Yuv(image);
  const luma = writer.convertMsToSamples(88);
  const chroma = writer.convertMsToSamples(44);
  const syncPulse = writer.convertMsToSamples(9);
  const syncPorch = writer.convertMsToSamples(3);
  const porch = writer.convertMsToSamples(1.5);
  const separator = writer.convertMsToSamples(4.5);

  for (let y = 0; y < image.height; y += 1) {
    callbacks.onLineChanged(y);
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, syncPorch, 1500);
    for (let i = 0; i < luma; i += 1) {
      writer.colorTone(yuv.getY(Math.floor((i * yuv.getWidth()) / luma), y));
    }
    repeatTone(writer, separator, y % 2 === 0 ? 1500 : 2300);
    repeatTone(writer, porch, 1900);
    for (let i = 0; i < chroma; i += 1) {
      const x = Math.floor((i * yuv.getWidth()) / chroma);
      writer.colorTone(y % 2 === 0 ? yuv.getV(x, y) : yuv.getU(x, y));
    }
    callbacks.onLineEncoded(y, writer.getSampleCount());
    await flushChunk(writer, callbacks);
  }
}

async function streamRobot72(writer: StreamingSampleWriter, image: PixelImage,
  callbacks: StreamingEncodeCallbacks): Promise<void> {
  const yuv = new Robot72Yuv(image);
  const luma = writer.convertMsToSamples(138);
  const chroma = writer.convertMsToSamples(69);
  const syncPulse = writer.convertMsToSamples(9);
  const syncPorch = writer.convertMsToSamples(3);
  const porch = writer.convertMsToSamples(1.5);
  const separator = writer.convertMsToSamples(4.5);

  for (let y = 0; y < image.height; y += 1) {
    callbacks.onLineChanged(y);
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, syncPorch, 1500);
    for (let i = 0; i < luma; i += 1) {
      writer.colorTone(yuv.getY(Math.floor((i * yuv.getWidth()) / luma), y));
    }
    repeatTone(writer, separator, 1500);
    repeatTone(writer, porch, 1900);
    for (let i = 0; i < chroma; i += 1) {
      writer.colorTone(yuv.getV(Math.floor((i * yuv.getWidth()) / chroma), y));
    }
    repeatTone(writer, separator, 2300);
    repeatTone(writer, porch, 1900);
    for (let i = 0; i < chroma; i += 1) {
      writer.colorTone(yuv.getU(Math.floor((i * yuv.getWidth()) / chroma), y));
    }
    callbacks.onLineEncoded(y, writer.getSampleCount());
    await flushChunk(writer, callbacks);
  }
}

async function streamPd(writer: StreamingSampleWriter, image: PixelImage, mode: SstvModeDefinition,
  callbacks: StreamingEncodeCallbacks): Promise<void> {
  const yuv = new PdYuv(image);
  const syncPulse = writer.convertMsToSamples(20);
  const porch = writer.convertMsToSamples(2.08);
  const colorScan = writer.convertMsToSamples(mode.colorScanDurationMs ?? 0);

  for (let y = 0; y < image.height; y += 2) {
    callbacks.onLineChanged(y);
    const lineBegin = writer.getSampleCount();
    repeatTone(writer, syncPulse, 1200);
    repeatTone(writer, porch, 1500);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(yuv.getY(Math.floor((i * yuv.getWidth()) / colorScan), y));
    }
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(yuv.getV(Math.floor((i * yuv.getWidth()) / colorScan), y));
    }
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(yuv.getU(Math.floor((i * yuv.getWidth()) / colorScan), y));
    }
    const secondLine = Math.min(image.height - 1, y + 1);
    for (let i = 0; i < colorScan; i += 1) {
      writer.colorTone(yuv.getY(Math.floor((i * yuv.getWidth()) / colorScan), secondLine));
    }
    const lineEnd = writer.getSampleCount();
    const midpoint = lineBegin + Math.floor((lineEnd - lineBegin) / 2);
    callbacks.onLineEncoded(y, midpoint);
    if (y + 1 < image.height) {
      callbacks.onLineEncoded(y + 1, lineEnd);
    }
    await flushChunk(writer, callbacks);
  }
}

export async function streamEncodeSstv(source: PixelImage, mode: SstvModeDefinition,
  callbacks: StreamingEncodeCallbacks, sampleRate: number = 44100): Promise<void> {
  const writer = new StreamingSampleWriter(sampleRate);
  writer.writeCalibrationHeader(mode.visCode);
  await flushChunk(writer, callbacks);

  switch (mode.family) {
    case SstvFamily.MARTIN:
      await streamMartin(writer, source, mode, callbacks);
      break;
    case SstvFamily.SCOTTIE:
      await streamScottie(writer, source, mode, callbacks);
      break;
    case SstvFamily.ROBOT36:
      await streamRobot36(writer, source, callbacks);
      break;
    case SstvFamily.ROBOT72:
      await streamRobot72(writer, source, callbacks);
      break;
    case SstvFamily.PD:
      await streamPd(writer, source, mode, callbacks);
      break;
    case SstvFamily.WRAASE:
      await streamWraase(writer, source, callbacks);
      break;
    default:
      await streamRobot36(writer, source, callbacks);
      break;
  }
}
