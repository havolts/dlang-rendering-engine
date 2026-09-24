import metal;
import metalkit;
import coregraphics;
import cocoa;
import macoswindowing;
import std.math;
import std.stdio;
import types;
import texture;

public class Mesh
{
    VertexData[] vertices;
    uint[] indices;
    NSUInteger indexCount;
    void*[] textures;

    MTLBuffer vertexBuffer;
    MTLBuffer indexBuffer;

    this(VertexData[] inVertices, uint[] inIndices, NSUInteger inIndexCount, MTLRenderPipelineState* inMetalRenderPSO, MTLDepthStencilState* inDepthStencilState)
    {
        vertices = inVertices;
        indices = inIndices;
        indexCount = inIndexCount;

        if(vertices is null)
        {
            writeln("vertices failed.");
        }
        if(indices is null)
        {
            writeln("indices failed.");
        }
    }

    this(VertexData[] inVertices, MTLRenderPipelineState* inMetalRenderPSO, MTLDepthStencilState* inDepthStencilState)
    {
        vertices = inVertices;

        if(vertices is null)
        {
            writeln("vertices failed.");
        }
        if(indices is null)
        {
            writeln("indices failed.");
        }
    }

    this(VertexData[] inVertices, MTLRenderPipelineState* inMetalRenderPSO, MTLDepthStencilState* inDepthStencilState, Texture[] inTextures)
    {
        vertices = inVertices;
        void*[] inMTLTextures = new void*[inTextures.length];
        for(int i = 0; i < inTextures.length; i++)
        {
            inMTLTextures[i] = cast(void*) inTextures[i].texture;
        }
        textures = inMTLTextures;

        if(vertices is null)
        {
            writeln("vertices failed.");
        }
        if(textures is null)
        {
            writeln("texture failed.");
        }
    }

    this(VertexData[] inVertices, uint[] inIndices, NSUInteger inIndexCount, MTLRenderPipelineState* inMetalRenderPSO, MTLDepthStencilState* inDepthStencilState, Texture[] inTextures)
    {
        this(inVertices, inIndices, inIndexCount, inMetalRenderPSO, inDepthStencilState);

        void*[] inMTLTextures = new void*[inTextures.length];

        foreach (i, tex; inTextures)
        {
            inMTLTextures[i] = cast(void*) tex.texture;
        }
        textures = inMTLTextures;
    }

    void makeBuffer(MTLDevice device)
    {
        vertexBuffer = device.makeBuffer(vertices.ptr, vertices.length * VertexData.sizeof, MTLResourceOptions.storageModeShared);
        indexBuffer = device.makeBuffer(indices.ptr, indices.length * uint.sizeof, MTLResourceOptions.storageModeShared);
    }
}
