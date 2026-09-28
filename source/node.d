module node;

import std.math;
import std.stdio;
import types;
import texture;
import mesh;
import sdl;
import sdl.error;
import sdl.gpu;

public class Node
{
    float3 position = float3(0f,0f,0f);
    float3 rotation = float3(0f,0f,0f);
    float3 scale = float3(1f,1f,1f);

    Mesh mesh;

    this(SDL_GPUDevice* device, Mesh inMesh)
    {
        mesh = inMesh;
    }

    float4x4 modelMatrix()
    {
        float4x4 rotationMatrix = float4x4([[1f,0,0,0],
                                            [0,cos(rotation.x),sin(rotation.x),0],
                                            [0,-sin(rotation.x),cos(rotation.x),0],
                                            [0,0,0,1f]]) *
                                            float4x4([[cos(rotation.y),0,sin(rotation.y),0],
                                                      [0,1f,0,0],
                                                      [-sin(rotation.y),0,cos(rotation.y),0],
                                                      [0,0,0,1f]]) *
                                                      float4x4([[cos(rotation.z),-sin(rotation.z),0,0],
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
