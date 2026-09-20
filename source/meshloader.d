module meshloader;

import metal;
import metalkit;
import coregraphics;
import cocoa;
import macoswindowing;
import std.algorithm : min;
import std.array : split, join, replace;
import std.conv : to;
import std.exception : enforce;
import std.file : exists;
import std.path : dirName, buildPath, buildNormalizedPath;
import std.stdio;
import std.string : strip;
import types;
import texture;
import mesh;
import renderer;

/// Key used to deduplicate vertices: same position + texcoord + material texture => same vertex.
private struct VertexKey
{
    int v;
    int vt;
    uint tex;
}

class MeshLoader
{
    private VertexData[] vertices;
    private Texture[] textures;
    private int[string] materialTextureIndex; // material name -> texture index
    private int[string] texturePathIndex;     // normalized path -> texture index (cache)
    private bool[string] loadedMtlFiles;
    private int currentTextureIndex = 0;

    Mesh loadObj(string filepath, Renderer renderer)
    {
        // Assign fresh arrays (not `.length = 0`) so a previously returned Mesh
        // that still references the old data is never affected.
        vertices = null;
        textures = null;
        materialTextureIndex = null;
        texturePathIndex = null;
        loadedMtlFiles = null;
        currentTextureIndex = 0;

        float4[] positions;
        float2[] textureCoordinates;
        uint[] indices;
        uint[VertexKey] vertexCache;

        size_t lineNumber = 0;
        foreach (rawLine; File(filepath, "r").byLine())
        {
            lineNumber++;
            string line = rawLine.strip().idup;
            if (line.length == 0 || line[0] == '#')
                continue;

            string rest;
            string keyword = splitKeyword(line, rest);

            try
            {
                switch (keyword)
                {
                    case "v":
                    {
                        // "v x y z [w]" -- some exporters append r g b, so only
                        // treat the 4th token as w when it is the last one.
                        auto t = rest.split();
                        enforce(t.length >= 3, "vertex needs at least 3 components");
                        float[4] p = [0.0f, 0.0f, 0.0f, 1.0f];
                        foreach (i; 0 .. 3)
                            p[i] = to!float(t[i]);
                        if (t.length == 4)
                            p[3] = to!float(t[3]);
                        positions ~= float4(p);
                        break;
                    }

                    case "vt":
                    {
                        auto t = rest.split();
                        enforce(t.length >= 2, "texcoord needs at least 2 components");
                        float[2] uv = [to!float(t[0]), 1.0f - to!float(t[1])];
                        textureCoordinates ~= float2(uv);
                        break;
                    }

                    case "f":
                    {
                        auto tokens = rest.split();
                        enforce(tokens.length >= 3, "face needs at least 3 vertices");

                        uint[] faceIndices;
                        foreach (token; tokens)
                        {
                            auto data = token.split('/');

                            int v = parseObjIndex(data[0], positions.length, "vertex");

                            int vt = -1;
                            if (data.length > 1 && data[1].length > 0)
                                vt = parseObjIndex(data[1], textureCoordinates.length, "texcoord");

                            // data[2] (normal) is intentionally ignored: VertexData has no normal.

                            auto key = VertexKey(v, vt, cast(uint) currentTextureIndex);
                            if (auto existing = key in vertexCache)
                            {
                                faceIndices ~= *existing;
                            }
                            else
                            {
                                uint newIndex = cast(uint) vertices.length;
                                float2 tex = (vt >= 0) ? textureCoordinates[vt] : float2(0f, 0f);
                                vertices ~= VertexData(positions[v], tex, cast(uint) currentTextureIndex);
                                vertexCache[key] = newIndex;
                                faceIndices ~= newIndex;
                            }
                        }

                        // Triangle fan for polygons with more than 3 vertices.
                        for (size_t i = 1; i + 1 < faceIndices.length; i++)
                        {
                            indices ~= faceIndices[0];
                            indices ~= faceIndices[i];
                            indices ~= faceIndices[i + 1];
                        }
                        break;
                    }

                    case "mtllib":
                    {
                        // Prefer the whole remainder as one filename (may contain spaces);
                        // fall back to treating it as a list of names.
                        string baseDir = dirName(filepath);
                        string whole = buildPath(baseDir, rest);
                        if (exists(whole))
                        {
                            loadMtl(whole, renderer.device);
                        }
                        else
                        {
                            foreach (mtlName; rest.split())
                                loadMtl(buildPath(baseDir, mtlName), renderer.device);
                        }
                        break;
                    }

                    case "usemtl":
                    {
                        // Materials without a loaded map_Kd use texture index 0.
                        currentTextureIndex = materialTextureIndex.get(rest, 0);
                        break;
                    }

                    default:
                        // vn, vp, o, g, s, l, ... are ignored.
                        break;
                }
            }
            catch (Exception e)
            {
                stderr.writefln("%s:%s: skipping line (%s): %s", filepath, lineNumber, e.msg, line);
            }
        }

        if (indices.length == 0)
            stderr.writeln("Warning: no faces loaded from ", filepath);
        if (textures.length == 0)
            stderr.writeln("Warning: no textures loaded for ", filepath);

        uint indexCount = cast(uint) indices.length;

        return new Mesh(
            vertices,
            indices,
            indexCount,
            &renderer.renderPipelineState,
            &renderer.depthStencilState,
            textures
        );
    }

    private void loadMtl(string mtlPath, MTLDevice device)
    {
        string mtlKey = buildNormalizedPath(mtlPath);
        if (mtlKey in loadedMtlFiles)
            return;
        loadedMtlFiles[mtlKey] = true;

        if (!exists(mtlPath))
        {
            writeln("MTL file not found: ", mtlPath);
            return;
        }

        string currentMaterial;
        foreach (rawLine; File(mtlPath, "r").byLine())
        {
            string line = rawLine.strip().idup;
            if (line.length == 0 || line[0] == '#')
                continue;

            string rest;
            string keyword = splitKeyword(line, rest);
            if (rest.length == 0)
                continue;

            if (keyword == "newmtl")
            {
                currentMaterial = rest;
            }
            else if (keyword == "map_Kd" && currentMaterial.length > 0)
            {
                string texName = parseMapFilename(rest);
                if (texName.length == 0)
                    continue;

                string texPath = buildNormalizedPath(dirName(mtlPath), texName);

                if (auto cached = texPath in texturePathIndex)
                {
                    materialTextureIndex[currentMaterial] = *cached;
                    continue;
                }

                if (!exists(texPath))
                {
                    stderr.writeln("Texture not found: ", texPath);
                    continue;
                }

                try
                {
                    textures ~= new Texture(texPath, device);
                    int idx = cast(int)(textures.length - 1);
                    texturePathIndex[texPath] = idx;
                    materialTextureIndex[currentMaterial] = idx;
                }
                catch (Exception e)
                {
                    stderr.writefln("Failed to load texture %s: %s", texPath, e.msg);
                }
            }
        }
    }

    /// Converts a 1-based (or negative, relative) OBJ index to a 0-based array index,
    /// validating it against the number of elements parsed so far.
    private static int parseObjIndex(string token, size_t count, string what)
    {
        int idx = to!int(token);
        int resolved = idx < 0 ? cast(int) count + idx : idx - 1;
        enforce(idx != 0 && resolved >= 0 && resolved < cast(int) count,
                what ~ " index out of range: " ~ token);
        return resolved;
    }

    /// Splits "keyword rest of line" into the keyword (returned) and the remainder (`rest`).
    private static string splitKeyword(string line, out string rest)
    {
        ptrdiff_t i = -1;
        foreach (k, c; line)
        {
            if (c == ' ' || c == '\t')
            {
                i = k;
                break;
            }
        }

        if (i < 0)
        {
            rest = "";
            return line;
        }

        rest = line[i .. $].strip();
        return line[0 .. i];
    }

    /// Extracts the filename from a map_Kd argument string, skipping options such as
    /// "-s 1 1 1", "-o 0 0 0", "-mm 0 1", "-clamp on". The filename may contain spaces.
    private static string parseMapFilename(string rest)
    {
        auto t = rest.split();
        size_t i = 0;
        while (i < t.length && t[i].length > 1 && t[i][0] == '-')
            i += 1 + optionArgCount(t[i]);

        if (i >= t.length)
            return "";

        return t[i .. $].join(" ").replace("\\", "/");
    }

    private static size_t optionArgCount(string option)
    {
        switch (option)
        {
            case "-s":
            case "-o":
            case "-t":
                return 3;
            case "-mm":
                return 2;
            default:
                return 1; // -bm, -boost, -texres, -clamp, -imfchan, -type, -blendu, -blendv, -cc
        }
    }
}
