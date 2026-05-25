import { SstvFamily, SstvModeDefinition } from '../../model/SstvTypes';

export const SSTV_MODES: SstvModeDefinition[] = [
  { id: 'martin1', name: 'Martin 1', family: SstvFamily.MARTIN, width: 320, height: 256, visCode: 44, colorScanDurationMs: 146.432 },
  { id: 'martin2', name: 'Martin 2', family: SstvFamily.MARTIN, width: 320, height: 256, visCode: 40, colorScanDurationMs: 73.216 },
  { id: 'pd50', name: 'PD 50', family: SstvFamily.PD, width: 320, height: 256, visCode: 93, colorScanDurationMs: 91.52 },
  { id: 'pd90', name: 'PD 90', family: SstvFamily.PD, width: 320, height: 256, visCode: 99, colorScanDurationMs: 170.24 },
  { id: 'pd120', name: 'PD 120', family: SstvFamily.PD, width: 640, height: 496, visCode: 95, colorScanDurationMs: 121.6 },
  { id: 'pd160', name: 'PD 160', family: SstvFamily.PD, width: 512, height: 400, visCode: 98, colorScanDurationMs: 195.584 },
  { id: 'pd180', name: 'PD 180', family: SstvFamily.PD, width: 640, height: 496, visCode: 96, colorScanDurationMs: 183.04 },
  { id: 'pd240', name: 'PD 240', family: SstvFamily.PD, width: 640, height: 496, visCode: 97, colorScanDurationMs: 244.48 },
  { id: 'pd290', name: 'PD 290', family: SstvFamily.PD, width: 800, height: 616, visCode: 94, colorScanDurationMs: 228.8 },
  { id: 'scottie1', name: 'Scottie 1', family: SstvFamily.SCOTTIE, width: 320, height: 256, visCode: 60, colorScanDurationMs: 138.24 },
  { id: 'scottie2', name: 'Scottie 2', family: SstvFamily.SCOTTIE, width: 320, height: 256, visCode: 56, colorScanDurationMs: 88.064 },
  { id: 'scottieDx', name: 'Scottie DX', family: SstvFamily.SCOTTIE, width: 320, height: 256, visCode: 76, colorScanDurationMs: 345.6 },
  { id: 'robot36', name: 'Robot 36', family: SstvFamily.ROBOT36, width: 320, height: 240, visCode: 8 },
  { id: 'robot72', name: 'Robot 72', family: SstvFamily.ROBOT72, width: 320, height: 240, visCode: 12 },
  { id: 'wraase', name: 'Wraase SC2 180', family: SstvFamily.WRAASE, width: 320, height: 256, visCode: 55 },
];

export function getModeById(modeId: string): SstvModeDefinition {
  for (let i = 0; i < SSTV_MODES.length; i += 1) {
    if (SSTV_MODES[i].id === modeId) {
      return SSTV_MODES[i];
    }
  }
  return SSTV_MODES[12];
}

