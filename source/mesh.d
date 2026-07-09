import metalrendering;
import macoswindowing;
import std.math;
import std.stdio;
import types;

float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ)
{
    float ys = 1 / std.math.tan(fovyRadians * 0.5f);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);
    float4x4 matrix = float4x4([[xs,0f,0f,0f],
                                [0f,ys,0f,0f],
                                [0f,0f,zs,nearZ*zs],
                                [0f,0f,-1f,0f]]);
    return matrix;
}

public class Mesh
{
    shared Window win;
    VertexData[] vertices;
    uint[] indices;
    NSUInteger indexCount;

    float4x4 translationMatrix = float4x4([[1f,0,0,0],
                                           [0,1f,0,0],
                                           [0,0,1f,-1f],
                                           [0,0,0,1f]]);

    float3 rotation = float3(0f,0f,0f);
    float4x4 rotationX;
    float4x4 rotationY;
    float4x4 rotationZ;

    float4x4 rotationMatrix;

    MTLBuffer vertexBuffer;
    MTLBuffer indexBuffer;
    MTLBuffer transformationBuffer;

    this(VertexData[] inVertices, uint[] inIndices, NSUInteger inIndexCount, shared Window inWin, MTLRenderPipelineState* inMetalRenderPSO, MTLDepthStencilState* inDepthStencilState)
    {
        vertices = inVertices;
        indices = inIndices;
        indexCount = inIndexCount;
        win = inWin;

        rotationX = float4x4([[cos(rotation.x),0,sin(rotation.x),0],
                              [0,1f,0,0],
                              [-sin(rotation.x),0,cos(rotation.x),0],
                              [0,0,0,1f]]);
        rotationY = float4x4([[1f,0,0,0],
                              [0,cos(rotation.y),sin(rotation.y),0],
                              [0,-sin(rotation.y),cos(rotation.y),0],
                              [0,0,0,1f]]);
        rotationZ = float4x4([[cos(rotation.z),-sin(rotation.z),0,0],
                              [sin(rotation.z),cos(rotation.z),0,0],
                              [0,0,1f,0],
                              [0,0,0,1f]]);
        rotationMatrix = rotationX * rotationY * rotationZ;

        if(vertices is null)
        {
            writeln("vertices failed.");
        }
        if(indices is null)
        {
            writeln("indices failed.");
        }
        if(win is null)
        {
            writeln("win failed.");
        }
    }

    void makeBuffer(MTLDevice device)
    {
        vertexBuffer = device.makeBuffer(vertices.ptr, vertices.length * VertexData.sizeof, MTLResourceOptions.storageModeShared);
        transformationBuffer = device.makeBuffer(TransformationData.sizeof, MTLResourceOptions.storageModeShared);
        indexBuffer = device.makeBuffer(indices.ptr, indices.length * uint.sizeof, MTLResourceOptions.storageModeShared);
    }

    void encodeRenderCommand(MTLRenderCommandEncoder renderCommandEncoder, float4x4 viewMatrix, float4x4 perspectiveMatrix)
    {
        //writeln("encodeRenderCommand");
        if(renderCommandEncoder is null)
        {
            writeln("renderCommandEncoder failed.");
        }

        rotationX = float4x4([[cos(rotation.x),0,sin(rotation.x),0],
                            [0,1f,0,0],
                            [-sin(rotation.x),0,cos(rotation.x),0],
                            [0,0,0,1f]]);
        //writeln(rotationX.matrix);
        rotationY = float4x4([[1f,0,0,0],
                            [0,cos(rotation.y),sin(rotation.y),0],
                            [0,-sin(rotation.y),cos(rotation.y),0],
                            [0,0,0,1f]]);
        rotationZ = float4x4([[cos(rotation.z),-sin(rotation.z),0,0],
                            [sin(rotation.z),cos(rotation.z),0,0],
                            [0,0,1f,0],
                            [0,0,0,1f]]);
        rotationMatrix = rotationX * rotationY * rotationZ;

        float4x4 modelMatrix = translationMatrix * rotationMatrix;

        modelMatrix.rowToColumnMajor();
        //writeln(modelMatrix.matrix);

        TransformationData transformationData = {modelMatrix, viewMatrix, perspectiveMatrix};

        auto contentsPtr = transformationBuffer.contents();

        *(cast(TransformationData*) contentsPtr) = transformationData;

        renderCommandEncoder.setVertexBuffer(vertexBuffer, 0, 0);
        renderCommandEncoder.setVertexBuffer(transformationBuffer, 0, 1);

        MTLPrimitiveType typeTriangle = MTLPrimitiveType.triangle;
        NSUInteger indexBufferOffset = 0;
        //renderCommandEncoder.drawIndexedPrimitives(typeTriangle,indexCount, MTLIndexType.uint32, indexBuffer, indexBufferOffset);
        renderCommandEncoder.drawIndexedPrimitives(typeTriangle,indexCount, MTLIndexType.uint32, indexBuffer, indexBufferOffset);
    }
}
