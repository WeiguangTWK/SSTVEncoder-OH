import { PixelImage, RgbaPixelImage } from '../../model/SstvTypes';

export function fitImageToMode(source: PixelImage, targetWidth: number, targetHeight: number): RgbaPixelImage {
  const targetPixels = new Uint32Array(targetWidth * targetHeight);
  const scale = Math.min(targetWidth / source.width, targetHeight / source.height);
  const drawWidth = Math.max(1, Math.round(source.width * scale));
  const drawHeight = Math.max(1, Math.round(source.height * scale));
  const offsetX = Math.floor((targetWidth - drawWidth) / 2);
  const offsetY = Math.floor((targetHeight - drawHeight) / 2);

  for (let y = 0; y < targetHeight; y += 1) {
    for (let x = 0; x < targetWidth; x += 1) {
      targetPixels[(y * targetWidth) + x] = 0xff000000;
    }
  }

  for (let y = 0; y < drawHeight; y += 1) {
    const sourceY = Math.min(source.height - 1, Math.floor((y * source.height) / drawHeight));
    for (let x = 0; x < drawWidth; x += 1) {
      const sourceX = Math.min(source.width - 1, Math.floor((x * source.width) / drawWidth));
      targetPixels[((y + offsetY) * targetWidth) + x + offsetX] = source.getPixel(sourceX, sourceY);
    }
  }

  return new RgbaPixelImage(targetWidth, targetHeight, targetPixels);
}

