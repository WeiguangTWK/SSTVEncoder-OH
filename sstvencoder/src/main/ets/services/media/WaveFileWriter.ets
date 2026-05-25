import { EncodeResult } from '../../model/SstvTypes';

function writeAscii(view: DataView, offset: number, value: string): void {
  for (let i = 0; i < value.length; i += 1) {
    view.setUint8(offset + i, value.charCodeAt(i));
  }
}

export function createWaveBuffer(result: EncodeResult): ArrayBuffer {
  const pcmByteLength = result.pcm.length * 2;
  const buffer = new ArrayBuffer(44 + pcmByteLength);
  const header = createWaveHeaderBuffer(result.sampleRate, pcmByteLength);
  const view = new DataView(buffer);
  new Uint8Array(buffer, 0, 44).set(new Uint8Array(header));

  for (let i = 0; i < result.pcm.length; i += 1) {
    view.setInt16(44 + (i * 2), result.pcm[i], true);
  }

  return buffer;
}

export function createWaveHeaderBuffer(sampleRate: number, pcmByteLength: number): ArrayBuffer {
  const channelCount = 1;
  const bitsPerSample = 16;
  const blockAlign = channelCount * (bitsPerSample / 8);
  const byteRate = sampleRate * blockAlign;
  const buffer = new ArrayBuffer(44);
  const view = new DataView(buffer);

  writeAscii(view, 0, 'RIFF');
  view.setUint32(4, 36 + pcmByteLength, true);
  writeAscii(view, 8, 'WAVE');
  writeAscii(view, 12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, channelCount, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bitsPerSample, true);
  writeAscii(view, 36, 'data');
  view.setUint32(40, pcmByteLength, true);

  return buffer;
}
