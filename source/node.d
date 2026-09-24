module node;

import metal;
import metalkit;
import coregraphics;
import cocoa;
import macoswindowing;
import std.math;
import std.stdio;
import types;
import texture;
import mesh;

public class Node
{
    /*
        A Node should have position, rotation and scale and a Mesh object.
        It should also own the transformation buffer as this is per node data. If you do it per mesh, then every node using 1 mesh will change.
    */

    float3 position = float3(0f,0f,0f);
    float3 rotation = float3(0f,0f,0f);
    float3 scale = float3(1f,1f,1f);

    Mesh mesh;
    MTLBuffer transformationBuffer;

    this(MTLDevice device, Mesh inMesh)
    {
        transformationBuffer = device.makeBuffer(TransformationData.sizeof, MTLResourceOptions.storageModeShared);
        mesh = inMesh;
    }

    float4x4 modelMatrix()
    {
        float4x4 rotationMatrix = float4x4([[1f,0,0,0], // x
                                            [0,cos(rotation.x),sin(rotation.x),0],
                                            [0,-sin(rotation.x),cos(rotation.x),0],
                                            [0,0,0,1f]]) *
                                            float4x4([[cos(rotation.y),0,sin(rotation.y),0], // y
                                                      [0,1f,0,0],
                                                      [-sin(rotation.y),0,cos(rotation.y),0],
                                                      [0,0,0,1f]]) *
                                                      float4x4([[cos(rotation.z),-sin(rotation.z),0,0], // z
                                                                [sin(rotation.z),cos(rotation.z),0,0],
                                                                [0,0,1f,0],
                                                                [0,0,0,1f]]);

        float4x4 translationMatrix = float4x4([[1f,0,0,position.x],
                                               [0,1f,0,position.y],
                                               [0,0,1f,position.z],
                                               [0,0,0,1f]]);

        float4x4 scaleMatrix = float4x4([[scale.x,0,0,0],
                                         [0,scale.y,0,0],
                                         [0,0,scale.z,0],
                                         [0,0,0,1f]]);

        float4x4 modelMatrix = translationMatrix * rotationMatrix * scaleMatrix;
        modelMatrix.rowToColumnMajor();

        return modelMatrix;
    }
}
