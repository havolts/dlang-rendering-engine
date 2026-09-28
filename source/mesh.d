module mesh;

import std.math;
import std.stdio;
import types;
import texture;
import sdl;
import sdl.error;
import sdl.gpu;
import core.stdc.string : memcpy;

public class Mesh
{
    VertexData[] vertices;
    uint[] indices;
    SDL_GPUTexture*[] textures;

    SDL_GPUBuffer* vertexBuffer; // vertices formatted for the GPU
    SDL_GPUBuffer* indexBuffer; // indices formatted for the GPU

    this(VertexData[] inVertices, uint[] inIndices)
    {
        vertices = inVertices;
        indices = inIndices;

        if(vertices is null)
        {
            writeln("vertices failed.");
        }
        if(indices is null)
        {
            writeln("indices failed.");
        }
    }

    this(VertexData[] inVertices, uint[] inIndices, Texture[] inTextures)
    {
        this(inVertices, inIndices);
        textures = new SDL_GPUTexture*[inTextures.length];
        foreach (i, tex; inTextures)
        {
        textures[i] = tex.texture;
        }
    }

    void makeBuffer(SDL_GPUDevice* device)
    {
        Uint32 vertexSize = cast(Uint32) (vertices.length * VertexData.sizeof);
        Uint32 indexSize  = cast(Uint32) (indices.length * uint.sizeof);
        // 1. Create GPU Buffers
        SDL_GPUBufferCreateInfo vertexInfo =
        {
            usage: SDL_GPUBufferUsageFlags.SDL_GPU_BUFFERUSAGE_VERTEX,
            size: vertexSize,
        };
        vertexBuffer = SDL_CreateGPUBuffer(device, &vertexInfo);
        SDL_GPUBufferCreateInfo indexInfo =
        {
            usage: SDL_GPUBufferUsageFlags.SDL_GPU_BUFFERUSAGE_INDEX,
            size: indexSize,
        };
        indexBuffer = SDL_CreateGPUBuffer(device, &indexInfo);

        // 2. Create transfer buffers - we need transfer buffers as we are not allowed to write into vram with cpu.
        // We use the transfer buffer so that the GPU can copy over the bytes of data we store in the transfer buffer to the real gpu buffer

        SDL_GPUTransferBufferCreateInfo transferInfo =
        {
            usage: SDL_GPUTransferBufferUsage.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            size: cast(Uint32) (vertices.length * VertexData.sizeof),
        };
        SDL_GPUTransferBuffer* vertexTransferBuffer = SDL_CreateGPUTransferBuffer(device, &transferInfo);
        transferInfo.size = cast(Uint32) (indices.length * uint.sizeof);
        SDL_GPUTransferBuffer* indexTransferBuffer = SDL_CreateGPUTransferBuffer(device, &transferInfo);

        // 3. Map the transfer buffers, write data and unmap.
        void* vertexMapped = SDL_MapGPUTransferBuffer(device, vertexTransferBuffer, false); // Grabbing the pointer for the transfer buffer
        (cast(VertexData*) vertexMapped)[0 .. vertices.length] = vertices; // Turning that pointer into a VertexData pointer. This will essentially point to the first element of an array.
        SDL_UnmapGPUTransferBuffer(device, vertexTransferBuffer); // Then we unmap it, thereby forgetting the pointer and returning it to GPU control.

        void* indexMapped = SDL_MapGPUTransferBuffer(device, indexTransferBuffer, false);
        (cast(uint*) indexMapped)[0 .. indices.length] = indices;
        SDL_UnmapGPUTransferBuffer(device, indexTransferBuffer);

        // 4. submit a copy command to the GPU.
        SDL_GPUCommandBuffer* commandBuffer = SDL_AcquireGPUCommandBuffer(device);
        SDL_GPUCopyPass* copyPass = SDL_BeginGPUCopyPass(commandBuffer);

        SDL_GPUTransferBufferLocation src = { transfer_buffer: vertexTransferBuffer, offset: 0 };
        SDL_GPUBufferRegion dst = { buffer: vertexBuffer, offset: 0, size: vertexSize };
        SDL_UploadToGPUBuffer(copyPass, &src, &dst, false);

        SDL_GPUTransferBufferLocation src2 = { transfer_buffer: indexTransferBuffer, offset: 0 };
        SDL_GPUBufferRegion dst2 = { buffer: indexBuffer, offset: 0, size: indexSize };
        SDL_UploadToGPUBuffer(copyPass, &src2, &dst2, false);

        SDL_EndGPUCopyPass(copyPass);
        SDL_SubmitGPUCommandBuffer(commandBuffer);

        // 5. release the transfer buffers.
        SDL_ReleaseGPUTransferBuffer(device, vertexTransferBuffer);
        SDL_ReleaseGPUTransferBuffer(device, indexTransferBuffer);

    }
}
