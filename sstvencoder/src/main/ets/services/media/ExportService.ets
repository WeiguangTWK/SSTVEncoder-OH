import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { ImageTransformState, SstvModeDefinition } from '../../model/SstvTypes';
import { streamEncodeSstv, StreamingEncodeCallbacks } from '../sstv/SstvEncoder';
import { createWaveHeaderBuffer } from './WaveFileWriter';
import { ImageLoader } from './ImageLoader';
import { renderImageForMode } from '../sstv/ImageTransform';

const MAX_EXPORT_BASE_NAME_LENGTH: number = 64;

export class ExportRequest {
  imagePath: string;
  fileName: string;
  useSampleImage: boolean;
  mode: SstvModeDefinition;
  transform: ImageTransformState;

  constructor(imagePath: string, fileName: string, useSampleImage: boolean, mode: SstvModeDefinition, transform: ImageTransformState) {
    this.imagePath = imagePath;
    this.fileName = fileName;
    this.useSampleImage = useSampleImage;
    this.mode = mode;
    this.transform = transform;
  }
}

class ExportFileHandle {
  fd: number;

  constructor(fd: number) {
    this.fd = fd;
  }
}

class TempPcmWriter implements StreamingEncodeCallbacks {
  private fd: number;
  private byteLength: number = 0;

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
      throw new Error(`Failed to write PCM chunk: ${message}`);
    }
    this.byteLength += pcm.byteLength;
  }

  onLineChanged(_line: number): void {
  }

  onLineEncoded(_line: number, _sampleCount: number): void {
  }

  getByteLength(): number {
    return this.byteLength;
  }
}

function trimTrailingDotsAndSpaces(value: string): string {
  let result = value;
  while (result.length > 0) {
    const lastChar = result.charAt(result.length - 1);
    if (lastChar === ' ' || lastChar === '.') {
      result = result.substring(0, result.length - 1);
      continue;
    }
    break;
  }
  return result;
}

function normalizeWhitespace(value: string): string {
  let result = '';
  let previousWasSpace = false;
  for (let i = 0; i < value.length; i += 1) {
    const char = value.charAt(i);
    const isWhitespace = char === ' ' || char === '\t' || char === '\n' || char === '\r';
    if (isWhitespace) {
      if (!previousWasSpace) {
        result += ' ';
        previousWasSpace = true;
      }
      continue;
    }
    result += char;
    previousWasSpace = false;
  }
  return result.trim();
}

function removeIllegalFileNameChars(value: string): string {
  let result = '';
  for (let i = 0; i < value.length; i += 1) {
    const char = value.charAt(i);
    const code = value.charCodeAt(i);
    const isControlChar = code >= 0 && code < 32;
    const isIllegalChar = char === '/' || char === '\\' || char === ':' || char === '*' ||
      char === '?' || char === '"' || char === '<' || char === '>' || char === '|';
    if (!isControlChar && !isIllegalChar) {
      result += char;
    }
  }
  return result;
}

function trimWaveSuffix(value: string): string {
  if (value.length >= 4 && value.substring(value.length - 4).toLowerCase() === '.wav') {
    return value.substring(0, value.length - 4);
  }
  return value;
}

function truncateBaseName(value: string): string {
  if (value.length <= MAX_EXPORT_BASE_NAME_LENGTH) {
    return value;
  }
  return value.substring(0, MAX_EXPORT_BASE_NAME_LENGTH);
}

export function sanitizeExportFileName(inputName: string, fallbackModeId: string): string {
  const fallbackBaseName = `sstv_${fallbackModeId}`;
  let baseName = normalizeWhitespace(inputName);
  baseName = trimWaveSuffix(baseName);
  baseName = removeIllegalFileNameChars(baseName);
  baseName = normalizeWhitespace(baseName);
  baseName = trimTrailingDotsAndSpaces(baseName);
  baseName = truncateBaseName(baseName);
  baseName = trimTrailingDotsAndSpaces(baseName);

  if (baseName.length < 1) {
    baseName = fallbackBaseName;
  }

  return `${baseName}.wav`;
}

function createTempPcmPath(context: common.UIAbilityContext): string {
  const baseDir = `${context.cacheDir}`;
  const suffix = Date.now().toString();
  return `${baseDir}/sstv_export_${suffix}.pcm`;
}

function copyFileContents(sourceFd: number, targetFd: number): void {
  const buffer = new ArrayBuffer(64 * 1024);
  while (true) {
    let bytesRead = 0;
    try {
      bytesRead = fs.readSync(sourceFd, buffer);
    } catch (error) {
      const message = (error as Error).message;
      throw new Error(`Failed to read PCM temp file: ${message}`);
    }
    if (bytesRead <= 0) {
      break;
    }
    if (bytesRead === buffer.byteLength) {
      try {
        fs.writeSync(targetFd, buffer);
      } catch (error) {
        const message = (error as Error).message;
        throw new Error(`Failed to write WAV data: ${message}`);
      }
      continue;
    }
    const chunk = buffer.slice(0, bytesRead);
    try {
      fs.writeSync(targetFd, chunk);
    } catch (error) {
      const message = (error as Error).message;
      throw new Error(`Failed to write WAV data: ${message}`);
    }
  }
}

export class ExportService {
  static async exportWave(context: common.UIAbilityContext, request: ExportRequest): Promise<string> {
    const sourceImage = request.useSampleImage
      ? await ImageLoader.loadSampleImage(context)
      : await ImageLoader.loadFromPath(request.imagePath);
    const transformedImage = renderImageForMode(sourceImage, request.mode, request.transform);
    const fileName = sanitizeExportFileName(request.fileName, request.mode.id);
    const documentPicker = new picker.DocumentViewPicker();
    const saveOptions = new picker.DocumentSaveOptions();
    saveOptions.newFileNames = [fileName];
    saveOptions.fileSuffixChoices = ['.wav'];
    const savedUris = await documentPicker.save(saveOptions);
    if (savedUris.length < 1) {
      throw new Error('Save cancelled');
    }

    const targetPath = savedUris[0];
    const tempPcmPath = createTempPcmPath(context);
    let tempFile: ExportFileHandle | null = null;
    let sourceFile: ExportFileHandle | null = null;
    let targetFile: ExportFileHandle | null = null;
    try {
      const openedTemp = fs.openSync(tempPcmPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      tempFile = new ExportFileHandle(openedTemp.fd);
      const pcmWriter = new TempPcmWriter(tempFile.fd);
      await streamEncodeSstv(transformedImage, request.mode, pcmWriter);
      fs.closeSync(tempFile.fd);
      tempFile = null;

      const openedTarget = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      targetFile = new ExportFileHandle(openedTarget.fd);
      fs.writeSync(targetFile.fd, createWaveHeaderBuffer(44100, pcmWriter.getByteLength()));

      const openedSource = fs.openSync(tempPcmPath, fs.OpenMode.READ_ONLY);
      sourceFile = new ExportFileHandle(openedSource.fd);
      copyFileContents(sourceFile.fd, targetFile.fd);
    } catch (error) {
      const message = (error as Error).message;
      throw new Error(`Failed to export wave file: ${message}`);
    } finally {
      if (sourceFile !== null) {
        try {
          fs.closeSync(sourceFile.fd);
        } catch (_ignore) {
        }
      }
      if (targetFile !== null) {
        try {
          fs.closeSync(targetFile.fd);
        } catch (_ignore) {
        }
      }
      if (tempFile !== null) {
        try {
          fs.closeSync(tempFile.fd);
        } catch (_ignore) {
        }
      }
      try {
        fs.unlinkSync(tempPcmPath);
      } catch (_ignore) {
      }
    }

    return targetPath;
  }
}
