import metalrendering;
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

    float4x4 translationMatrix = float4x4([[1f,0,0,0],
                                           [0,1f,0,0],
                                           [0,0,1f,0f],
                                           [0,0,0,1f]]);

    float3 position = float3(0f,0f,0f);

    float3 rotation = float3(0f,0f,0f);
    float4x4 rotationX;
    float4x4 rotationY;
    float4x4 rotationZ;

    float4x4 rotationMatrix;

    MTLBuffer vertexBuffer;
    MTLBuffer indexBuffer;
    MTLBuffer transformationBuffer;

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

    void makeBuffer(MTLDevice device)
    {
        vertexBuffer = device.makeBuffer(vertices.ptr, vertices.length * VertexData.sizeof, MTLResourceOptions.storageModeShared);
        transformationBuffer = device.makeBuffer(TransformationData.sizeof, MTLResourceOptions.storageModeShared);
        if(indices.length > 0) indexBuffer = device.makeBuffer(indices.ptr, indices.length * uint.sizeof, MTLResourceOptions.storageModeShared);
    }

    void encodeRenderCommand(MTLRenderCommandEncoder renderCommandEncoder, float4x4 viewMatrix, float4x4 perspectiveMatrix)
    {
        //writeln("encodeRenderCommand");
        if(renderCommandEncoder is null)
        {
            writeln("renderCommandEncoder failed.");
        }

        rotationX = float4x4([[1f,0,0,0],
                            [0,cos(rotation.x),sin(rotation.x),0],
                            [0,-sin(rotation.x),cos(rotation.x),0],
                            [0,0,0,1f]]);
        //writeln(rotationX.matrix);
        rotationY = float4x4([[cos(rotation.y),0,sin(rotation.y),0],
                            [0,1f,0,0],
                            [-sin(rotation.y),0,cos(rotation.y),0],
                            [0,0,0,1f]]);
        rotationZ = float4x4([[cos(rotation.z),-sin(rotation.z),0,0],
                            [sin(rotation.z),cos(rotation.z),0,0],
                            [0,0,1f,0],
                            [0,0,0,1f]]);
        rotationMatrix = rotationX * rotationY * rotationZ;

        translationMatrix = float4x4([[1f,0,0,position.x],
                                      [0,1f,0,position.y],
                                      [0,0,1f,position.z],
                                      [0,0,0,1f]]);

        float4x4 modelMatrix = translationMatrix * rotationMatrix;

        modelMatrix.rowToColumnMajor();
        //writeln(modelMatrix.matrix);

        TransformationData transformationData = {modelMatrix, viewMatrix, perspectiveMatrix};

        auto contentsPtr = transformationBuffer.contents();

        *(cast(TransformationData*) contentsPtr) = transformationData;

        renderCommandEncoder.setVertexBuffer(vertexBuffer, 0, 0);
        NSRange range = NSMakeRange(0,textures.length);
        renderCommandEncoder.setFragmentTextures(textures.ptr, range);
        renderCommandEncoder.setVertexBuffer(transformationBuffer, 0, 1);


        MTLPrimitiveType typeTriangle = MTLPrimitiveType.triangle;
        //NSUInteger indexBufferOffset = 0;
        NSUInteger vertexStart = 0;
        NSUInteger vertexCount = vertices.length;
        renderCommandEncoder.drawPrimitives(typeTriangle, vertexStart, vertexCount);
        //renderCommandEncoder.drawIndexedPrimitives(typeTriangle,indexCount, MTLIndexType.uint32, indexBuffer, indexBufferOffset);
    }
}
