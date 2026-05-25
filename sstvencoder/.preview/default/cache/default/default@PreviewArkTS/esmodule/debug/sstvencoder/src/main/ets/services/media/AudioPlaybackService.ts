import audio from "@ohos:multimedia.audio";
import type { PixelImage, SstvModeDefinition } from '../../model/SstvTypes';
import { streamEncodeSstv } from "@normalized:N&&&sstvencoder/src/main/ets/services/sstv/SstvEncoder&";
import type { StreamingEncodeCallbacks } from "@normalized:N&&&sstvencoder/src/main/ets/services/sstv/SstvEncoder&";
function pcmToArrayBuffer(pcm: Int16Array): ArrayBuffer {
    return pcm.buffer.slice(pcm.byteOffset, pcm.byteOffset + pcm.byteLength);
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
            usage: audio.StreamUsage.STREAM_USAGE_MEDIA,
            rendererFlags: 0,
        },
    };
}
export interface PlaybackCallbacks {
    onLineChanged(line: number): void;
    onPlaybackStateChanged(isPlaying: boolean): void;
}
class PlaybackCancelledError extends Error {
    constructor() {
        super('Playback cancelled');
    }
}
class RendererStreamingCallbacks implements StreamingEncodeCallbacks {
    private token: number;
    private renderer: audio.AudioRenderer;
    private playbackCallbacks: PlaybackCallbacks;
    constructor(token: number, renderer: audio.AudioRenderer, playbackCallbacks: PlaybackCallbacks) {
        this.token = token;
        this.renderer = renderer;
        this.playbackCallbacks = playbackCallbacks;
    }
    async onChunk(pcm: Int16Array): Promise<void> {
        if (this.token !== AudioPlaybackService.getPlaybackToken()) {
            throw new PlaybackCancelledError();
        }
        await this.renderer.write(pcmToArrayBuffer(pcm));
    }
    onLineChanged(line: number): void {
        if (this.token !== AudioPlaybackService.getPlaybackToken()) {
            throw new PlaybackCancelledError();
        }
        this.playbackCallbacks.onLineChanged(line);
    }
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
            }
            catch (_ignore) {
            }
            try {
                await renderer.release();
            }
            catch (_ignore) {
            }
        }
    }
    static async playStreamed(image: PixelImage, mode: SstvModeDefinition, callbacks: PlaybackCallbacks, sampleRate: number = 44100): Promise<void> {
        await AudioPlaybackService.stop();
        const token = AudioPlaybackService.playbackToken;
        const renderer = await audio.createAudioRenderer(createRendererOptions(sampleRate));
        AudioPlaybackService.renderer = renderer;
        callbacks.onPlaybackStateChanged(true);
        callbacks.onLineChanged(0);
        try {
            await renderer.start();
            const streamingCallbacks = new RendererStreamingCallbacks(token, renderer, callbacks);
            await streamEncodeSstv(image, mode, streamingCallbacks, sampleRate);
        }
        catch (error) {
            if (!(error instanceof PlaybackCancelledError)) {
                const message = (error as Error).message;
                throw new Error(message);
            }
        }
        finally {
            if (AudioPlaybackService.renderer === renderer) {
                AudioPlaybackService.renderer = null;
            }
            try {
                await renderer.stop();
            }
            catch (_ignore) {
            }
            try {
                await renderer.release();
            }
            catch (_ignore) {
            }
            try {
                callbacks.onPlaybackStateChanged(false);
            }
            catch (_ignore) {
            }
        }
    }
}
