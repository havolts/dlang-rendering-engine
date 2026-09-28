module texture;

import std.math;
import std.stdio;
import std.file : exists;
import std.path : absolutePath;
import std.string;
import types;

import imageformats;

import sdl;
import sdl.error;
import sdl.gpu;

class Texture
{
    SDL_GPUTexture* texture;
    SDL_GPUDevice* device;
    int width, height;

    this(const string filepath, SDL_GPUDevice* device)
    {
        this.device = device;

        string absPath = absolutePath(filepath);
        if (!exists(absPath))
        {
            writeln("Texture file not found: ", absPath);
            return;
        }

        // 1. Decode the image with imageformats. IFImage is RGBA8,
        //    tightly packed, so pixels.length == w * h * 4.
        IFImage img = read_image(absPath);
        width  = cast(int) img.w;
        height = cast(int) img.h;

        if (width <= 0 || height <= 0)
        {
            writeln("Failed to load texture: ", absPath);
            return;
        }

        Uint32 dataSize = cast(Uint32) img.pixels.length;

        // 2. Create the GPU texture
        SDL_GPUTextureCreateInfo texInfo = {
            type: SDL_GPUTextureType.SDL_GPU_TEXTURETYPE_2D,
            format: SDL_GPUTextureFormat.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
            usage: SDL_GPUTextureUsageFlags.SDL_GPU_TEXTUREUSAGE_SAMPLER,
            width: cast(Uint32) width,
            height: cast(Uint32) height,
            layer_count_or_depth: 1,
            num_levels: 1,
            sample_count: SDL_GPUSampleCount.SDL_GPU_SAMPLECOUNT_1,
        };
        texture = SDL_CreateGPUTexture(device, &texInfo);
        if (texture is null)
        {
            writeln("Failed to create GPU texture: ", SDL_GetError().fromStringz);
            return;
        }

        // 3. Stage the pixel bytes in a transfer buffer
        SDL_GPUTransferBufferCreateInfo tbInfo = {
            usage: SDL_GPUTransferBufferUsage.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            size: dataSize,
        };
        SDL_GPUTransferBuffer* transfer = SDL_CreateGPUTransferBuffer(device, &tbInfo);

        void* mapped = SDL_MapGPUTransferBuffer(device, transfer, false);
        (cast(ubyte*) mapped)[0 .. dataSize] = img.pixels[0 .. dataSize];
        SDL_UnmapGPUTransferBuffer(device, transfer);

        // 4. Copy pass: transfer buffer -> GPU texture
        SDL_GPUCommandBuffer* cmdBuf = SDL_AcquireGPUCommandBuffer(device);
        SDL_GPUCopyPass* copyPass = SDL_BeginGPUCopyPass(cmdBuf);

        SDL_GPUTextureTransferInfo src = {
            transfer_buffer: transfer,
            offset: 0,
            pixels_per_row: cast(Uint32) width,
            rows_per_layer: cast(Uint32) height,
        };
        SDL_GPUTextureRegion dst = {
            texture: texture,
            mip_level: 0,
            layer: 0,
            x: 0, y: 0, z: 0,
            w: cast(Uint32) width,
            h: cast(Uint32) height,
            d: 1,
        };
        SDL_UploadToGPUTexture(copyPass, &src, &dst, false);

        SDL_EndGPUCopyPass(copyPass);
        SDL_SubmitGPUCommandBuffer(cmdBuf);

        // 5. Release the staging buffer
        SDL_ReleaseGPUTransferBuffer(device, transfer);
    }

    void release()
    {
        if (texture !is null) SDL_ReleaseGPUTexture(device, texture);
        texture = null;
    }
}
