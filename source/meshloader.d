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
import std.algorithm : startsWith;
import std.string : strip;
import std.path : dirName, buildPath;
import types;
import texture;
import mesh;
import renderer;

class MeshLoader
{
    VertexData[] vertices;
    Texture[] textures;
    int[string] materialTextureIndex;
    int currentTextureIndex = 0;

    Mesh loadObj(string filepath, Renderer renderer)
    {
        vertices.length = 0;
        textures.length = 0;
        materialTextureIndex = null;
        currentTextureIndex = 0;

        Mesh mesh;
        float4[] positions;
        float2[] textureCoordinates;
        float3[] normals;
        uint[] indices;

        File file = File(filepath, "r");
        auto s = file.readln();

        while (s !is null)
        {
            auto line = s.strip();
            if (line.length == 0)
            {
                s = file.readln();
                continue;
            }

            if (line[0] == '#')
            {
                // comment
            }
            else if (line[0] == 'v')
            {
                if (line.length >= 2 && line[1] == ' ')
                {
                    auto temp = line[1 .. $].split();
                    float[4] vertexPosition;
                    for (int i = 0; i < temp.length; i++)
                        vertexPosition[i] = to!float(temp[i]);

                    if (isNaN(vertexPosition[3]))
                        vertexPosition[3] = 1.0f;

                    positions ~= float4(vertexPosition);
                }
                else if (line.length >= 3 && line[1] == 't')
                {
                    auto temp = line[2 .. $].split();
                    float[2] vertexTextureCoordinates;
                    for (int i = 0; i < temp.length; i++)
                        vertexTextureCoordinates[i] = to!float(temp[i]);

                    textureCoordinates ~= float2(vertexTextureCoordinates);
                }
                else if (line.length >= 3 && line[1] == 'n')
                {
                    auto temp = line[2 .. $].split();
                    float[3] vertexNormals;
                    for (int i = 0; i < temp.length; i++)
                        vertexNormals[i] = to!float(temp[i]);

                    normals ~= float3(vertexNormals);
                }
            }
            else if (line[0] == 'f')
            {
                auto faceVertices = line[1 .. $].split();
                int[] faceIndices;

                foreach (vertex; faceVertices)
                {
                    auto data = vertex.split('/');

                    int v = parseObjIndex(data[0], cast(int)positions.length);

                    float2 tex = float2(0f, 0f);
                    if (data.length > 1 && data[1].length > 0)
                    {
                        int vt = parseObjIndex(data[1], cast(int)textureCoordinates.length);
                        tex = textureCoordinates[vt];
                        tex.y = 1.0f - tex.y;
                    }

                    vertices ~= VertexData(
                        positions[v],
                        tex,
                        cast(uint)currentTextureIndex
                    );

                    faceIndices ~= cast(int)(vertices.length - 1);
                }

                for (int i = 1; i + 1 < faceIndices.length; i++)
                {
                    indices ~= faceIndices[0];
                    indices ~= faceIndices[i];
                    indices ~= faceIndices[i + 1];
                }
            }
            else if (line.startsWith("mtllib "))
            {
                foreach (mtlName; line[7 .. $].split())
                {
                    auto mtlPath = buildPath(dirName(filepath), mtlName);
                    loadMtl(mtlPath, renderer.device);
                }
            }
            else if (line.startsWith("usemtl "))
            {
                string matName = line[7 .. $].strip().idup;
                currentTextureIndex = (matName in materialTextureIndex)
                    ? materialTextureIndex[matName]
                    : 0;
            }

            s = file.readln();
        }

        uint indexCount = cast(uint)indices.length;

        mesh = new Mesh(
            vertices,
            indices,
            indexCount,
            &renderer.renderPipelineState,
            &renderer.depthStencilState,
            textures
        );

        return mesh;
    }

    private void loadMtl(string mtlPath, MTLDevice device)
    {
        if (!exists(mtlPath))
        {
            writeln("MTL file not found: ", mtlPath);
            return;
        }

        string currentMaterial;
        File mtl = File(mtlPath, "r");

        foreach (rawLine; mtl.byLine())
        {
            auto line = rawLine.strip();
            if (line.length == 0 || line[0] == '#')
                continue;

            auto parts = line.split();
            if (parts.length < 2)
                continue;

            if (parts[0] == "newmtl")
            {
                currentMaterial = parts[1].idup;
            }
            else if (parts[0] == "map_Kd")
            {
                string texName = parts[1].idup;
                auto texPath = buildPath(dirName(mtlPath), texName);

                textures ~= new Texture(texPath, device);
                materialTextureIndex[currentMaterial] = cast(int)(textures.length - 1);
            }
        }
    }

    private int parseObjIndex(string token, int count)
    {
        int idx = to!int(token);
        return idx < 0 ? count + idx : idx - 1;
    }
}
