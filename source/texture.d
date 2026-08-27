module texture;
import metalrendering;
import macoswindowing;
import std.math;
import std.stdio;
import std.file : exists;
import std.path : absolutePath;
import types;

class Texture
{
    MTLTexture texture;
    private MTLDevice device;

    this(const string filepath, MTLDevice mtlDevice)
    {
        device = mtlDevice;

        string absPath = absolutePath(filepath);
        if (!exists(absPath))
        {
            writeln("Texture file not found: ", absPath);
        }

        MTKTextureLoader textureLoader = MTKTextureLoader.alloc().init(device);
        void* options;
        NSError error;

        NSURL url = NSURL.fileURLWithPath(absPath.ns);
        texture = textureLoader.newTexture(url, options, error);

        if (texture is null)
        {
            writeln("Failed to load texture at: ", absPath);
        }
        else
        {
            //writeln(texture.pixelFormat);
        }
    }
}
