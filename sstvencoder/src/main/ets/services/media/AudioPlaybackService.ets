import { common } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { PixelImage, SstvModeDefinition } from '../../model/SstvTypes';
import { streamEncodeSstv, StreamingEncodeCallbacks } from '../sstv/SstvEncoder';

class ReadOptions {
  offset?: number;
  length?: number;

  constructor(offset: number, length: number) {
    this.offset = offset;
    this.length = length;
  }
}

class PlaybackPreparedData {
  tempFilePath: string;
  pcmByteLength: number;
  lineEnds: Array<number>;

  constructor(tempFilePath: string, pcmByteLength: number, lineEnds: Array<number>) {
    this.tempFilePath = tempFilePath;
    this.pcmByteLength = pcmByteLength;
    this.lineEnds = lineEnds;
  }
}

class PlaybackCancelledError extends Error {
  constructor() {
    super('Playback cancelled');
  }
}

class PlaybackTempFile {
  fd: number;

  constructor(fd: number) {
    this.fd = fd;
  }
}

class TempPlaybackPcmWriter implements StreamingEncodeCallbacks {
  private fd: number;
  private byteLength: number = 0;
  private lineEnds: Array<number> = [];

  constructor(fd: number) {
    this.fd = fd;
  }

  async onChunk(pcm: Int16Array): Promise<void> {
    const pcmBytes = new ArrayBuffer(pcm.byteLength);
    const view = new DataView(pcmBytes);
    for (let i = 0; i < pcm.length; i += 1) {
      view.setInt16(i * 2, pcm[i], true);
    }
    try {
      fs.writeSync(this.fd, pcmBytes);
    } catch (error) {
      const message = (error as Error).message;
      throw new Error(`Failed to write playback PCM: ${message}`);
    }
    this.byteLength += pcm.byteLength;
  }

  onLineChanged(_line: number): void {
  }

  onLineEncoded(line: number, sampleCount: number): void {
    while (this.lineEnds.length <= line) {
      this.lineEnds.push(sampleCount);
    }
    this.lineEnds[line] = sampleCount;
  }

  getPreparedData(tempFilePath: string): PlaybackPreparedData {
    return new PlaybackPreparedData(tempFilePath, this.byteLength, this.lineEnds);
  }
}

function createRendererOptions(sampleRate: number): audio.AudioRendererOptions {
  return {
    streamInfo: {
      samplingRate: sampleRate as audio.AudioSamplingRate,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,
    },
    rendererInfo: {
      usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      rendererFlags: 0,
    },
  };
}

function createTempPlaybackPath(context: common.UIAbilityContext): string {
  return `${context.cacheDir}/sstv_playback_${Date.now().toString()}.pcm`;
}

function computeLineIndex(lineEnds: Array<number>, samplesPlayed: number): number {
  let low = 0;
  let high = lineEnds.length;
  while (low < high) {
    const middle = low + Math.floor((high - low) / 2);
    if (samplesPlayed >= lineEnds[middle]) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

function delay(durationMs: number): Promise<void> {
  return new Promise((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, durationMs);
  });
}

export interface PlaybackCallbacks {
  onLineChanged(line: number): void;
  onPlaybackStateChanged(isPlaying: boolean): void;
}

export class AudioPlaybackService {
  private static playbackToken: number = 0;
  private static renderer: audio.AudioRenderer | null = null;

  static getPlaybackToken(): number {
    return AudioPlaybackService.playbackToken;
  }

  static async stop(): Promise<void> {
    AudioPlaybackService.playbackToken += 1;
    const renderer = AudioPlaybackService.renderer;
    AudioPlaybackService.renderer = null;
    if (renderer !== null) {
      try {
        await renderer.stop();
      } catch (_ignore) {
      }
      try {
        await renderer.release();
      } catch (_ignore) {
      }
    }
  }

  private static async preparePlaybackFile(context: common.UIAbilityContext, image: PixelImage,
    mode: SstvModeDefinition, sampleRate: number): Promise<PlaybackPreparedData> {
    const tempFilePath = createTempPlaybackPath(context);
    let tempFile: PlaybackTempFile | null = null;
    try {
      const opened = fs.openSync(tempFilePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      tempFile = new PlaybackTempFile(opened.fd);
      const writer = new TempPlaybackPcmWriter(tempFile.fd);
      await streamEncodeSstv(image, mode, writer, sampleRate);
      return writer.getPreparedData(tempFilePath);
    } catch (error) {
      const message = (error as Error).message;
      throw new Error(`Failed to prepare playback: ${message}`);
    } finally {
      if (tempFile !== null) {
        try {
          fs.closeSync(tempFile.fd);
        } catch (_ignore) {
        }
      }
    }
  }

  static async playStreamed(context: common.UIAbilityContext, image: PixelImage, mode: SstvModeDefinition,
    callbacks: PlaybackCallbacks, sampleRate: number = 44100): Promise<void> {
    await AudioPlaybackService.stop();
    const token = AudioPlaybackService.playbackToken;
    const prepared = await AudioPlaybackService.preparePlaybackFile(context, image, mode, sampleRate);
    if (token !== AudioPlaybackService.playbackToken) {
      try {
        fs.unlinkSync(prepared.tempFilePath);
      } catch (_ignore) {
      }
      throw new PlaybackCancelledError();
    }

    const renderer = await audio.createAudioRenderer(createRendererOptions(sampleRate));
    AudioPlaybackService.renderer = renderer;
    callbacks.onPlaybackStateChanged(true);
    callbacks.onLineChanged(0);

    let sourceFile: PlaybackTempFile | null = null;
    let bufferOffset = 0;
    let lastReportedLine = -1;

    const writeDataCallback = (buffer: ArrayBuffer): audio.AudioDataCallbackResult => {
      if (token !== AudioPlaybackService.playbackToken || sourceFile === null) {
        return audio.AudioDataCallbackResult.INVALID;
      }

      let bytesRead = 0;
      try {
        bytesRead = fs.readSync(sourceFile.fd, buffer, new ReadOptions(bufferOffset, buffer.byteLength));
      } catch (_ignore) {
        return audio.AudioDataCallbackResult.INVALID;
      }

      if (bytesRead <= 0) {
        return audio.AudioDataCallbackResult.INVALID;
      }

      bufferOffset += bytesRead;
      const samplesPlayed = Math.floor(bufferOffset / 2);
      const lineIndex = Math.min(mode.height - 1, computeLineIndex(prepared.lineEnds, samplesPlayed));
      if (lineIndex !== lastReportedLine) {
        lastReportedLine = lineIndex;
        callbacks.onLineChanged(lineIndex);
      }
      return audio.AudioDataCallbackResult.VALID;
    };

    try {
      const opened = fs.openSync(prepared.tempFilePath, fs.OpenMode.READ_ONLY);
      sourceFile = new PlaybackTempFile(opened.fd);
      renderer.on('writeData', writeDataCallback);
      await renderer.start();
      const durationMs = Math.ceil((prepared.pcmByteLength / 2) * 1000 / sampleRate);
      let elapsedMs = 0;
      while (token === AudioPlaybackService.playbackToken && elapsedMs <= durationMs + 250) {
        await delay(50);
        elapsedMs += 50;
      }
    } catch (error) {
      if (!(error instanceof PlaybackCancelledError)) {
        const message = (error as Error).message;
        throw new Error(message);
      }
    } finally {
      if (AudioPlaybackService.renderer === renderer) {
        AudioPlaybackService.renderer = null;
      }
      if (sourceFile !== null) {
        try {
          fs.closeSync(sourceFile.fd);
        } catch (_ignore) {
        }
      }
      try {
        fs.unlinkSync(prepared.tempFilePath);
      } catch (_ignore) {
      }
      try {
        await renderer.stop();
      } catch (_ignore) {
      }
      try {
        await renderer.release();
      } catch (_ignore) {
      }
      try {
        callbacks.onPlaybackStateChanged(false);
      } catch (_ignore) {
      }
    }
  }
}
