module meshloader;

import metal;
import metalkit;
import coregraphics;
import cocoa;
import macoswindowing;
import std.math;
import std.stdio;
import std.file;
import std.array;
import std.conv;
import types;
import texture;
import mesh;
import renderer;

class MeshLoader
{
    // needs to turn the data from a file into:
    //
    // VertexData[] inVertices
    // indices = inIndices;
    // indexCount = inIndexCount;
    // Texture[] inTextures

    /*
        struct VertexData
        {
            float4 position;
            float2 textureCoordinates;
            uint textureIndex;
        }
    */

    VertexData[] vertices;

    Mesh loadObj(string filepath, Renderer renderer)
    {
        Mesh mesh;
        float4[] positions; // Positions of all vertices
        float2[] textureCoordinates; // textureCoordinates of all vertices
        float3[] normals; // normals for all vertices
        uint[] indices;

        File file = File(filepath, "r");
        string s = file.readln();
        while(s != null)
        {
            if(s[0] == '#')
            {

            }
            else if(s[0] == 'v')
            {
                if(s[1] == ' ')
                {
                    s = s[1..s.length];
                    string[] temp = s.split();
                    float[4] vertexPosition;
                    for(int i = 0; i < temp.length; i++)
                    {
                        vertexPosition[i] =  to!float(temp[i]);
                    }
                    if(isNaN(vertexPosition[3])) vertexPosition[3] = 1.0f;
                    positions ~= float4(vertexPosition);
                }

                if(s[1] == 't')
                {
                    s = s[2..s.length];
                    string[] temp = s.split();
                    float[2] vertexTextureCoordinates;
                    for(int i = 0; i < temp.length; i++)
                    {
                        vertexTextureCoordinates[i] =  to!float(temp[i]);
                    }
                    textureCoordinates ~= float2(vertexTextureCoordinates);
                }

                if(s[1] == 'n')
                {
                    s = s[2..s.length];
                    string[] temp = s.split();
                    float[3] vertexNormals;
                    for(int i = 0; i < temp.length; i++)
                    {
                        vertexNormals[i] =  to!float(temp[i]);
                    }
                    normals ~= float3(vertexNormals);
                }
            }
            else if (s[0] == 'f')
            {
                s = s[1..s.length];
                string[] faceVertices = s.split();
                int[] faceIndices;

                foreach(string vertex; faceVertices)
                {
                    string[] data = vertex.split('/');
                    int v = to!int(data[0]);
                    int vt = to!int(data[1]);
                    int vn = to!int(data[2]);

                    VertexData vertexData = VertexData(positions[v-1], textureCoordinates[vt-1], 0);
                    vertices ~= vertexData;
                    faceIndices ~= cast(int)(vertices.length - 1);
                }

                //writeln(faceIndices);

                for(int i = 1; i+1 < faceIndices.length; i ++)
                {
                    indices ~= faceIndices[0];
                    indices ~= faceIndices[i];
                    indices ~= faceIndices[i+1];
                }
                //writeln(indices);
            }
            s = file.readln();
        }

        uint indexCount = cast(uint)indices.length;
        //writeln("\n indices: ", indices, " \n indexCount: ", indexCount);
        // this(VertexData[] inVertices, uint[] inIndices, NSUInteger inIndexCount, MTLRenderPipelineState* inMetalRenderPSO, MTLDepthStencilState* inDepthStencilState)
        mesh = new Mesh(vertices, indices, indexCount, &renderer.renderPipelineState, &renderer.depthStencilState);
        return mesh;
    }

    float3 calculateSurfaceNormal(float3 a, float3 b, float3 c)
    {
        float3 U = b - a;
        float3 V = c - a;
        float3 N;
        N.x = (U.y * V.z) - (U.z * V.y);
        N.y = (U.z * V.x) - (U.x * V.z);
        N.z = (U.x * V.y) - (U.y * V.x);
        return N;
    }
}
