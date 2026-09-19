// renderengine/source/main.d
module main;

import camera;
import meshloader;
import cocoa;
import coregraphics;
import coreanimation;
import macoswindowing.window;
import osxwindowing;

import mesh;
import metal;
import metalkit;
import renderer;
import texture;
import types;

import core.atomic;
import core.thread;
import core.time;
import std.math;
import std.stdio;

OSXApplication app;
OSXWindow window;
CGRect frame;

shared bool running = true;

void main()
{
    app = new OSXApplication();
    MTLDevice device = MTLCreateSystemDefaultDevice();

    window = app.CreateWindow(600, 600, "window 1");
    window.terminateApp = true;


    float aspectRatio = window.width/window.height;

    Renderer renderer = new Renderer(device, aspectRatio);

    Mesh[] meshes;

    frame = CGRect(CGPoint(0,0), CGSize(600,600));
    MTKView view = MTKView.alloc().initWithFrame(frame, device);
    view.colorPixelFormat = MTLPixelFormat.BGRA8Unorm_sRGB;
    view.depthStencilPixelFormat = MTLPixelFormat.Depth32Float;
    view.clearColor = MTLClearColor(1.0, 0.0, 0.0, 1.0);
    CAMetalLayer layer = view.metalLayer();
    layer.displaySyncEnabled = false;

    window.setContentView(view);

    MeshLoader loader = new MeshLoader();
    Texture grassSideTexture = new Texture("source/assets/grass-side.jpg", renderer.device);
    Texture[] textures = [];
    void*[] inMTLTextures = new void*[textures.length];
    for(int i = 0; i < textures.length; i++)
    {
        inMTLTextures[i] = cast(void*) textures[i].texture;
    }

    //loader.load("source/assets/square.obj", renderer);
    meshes ~= loader.loadObj("source/assets/Suzanne.obj", renderer);
    meshes[0].textures = inMTLTextures;

    foreach(Mesh mesh; meshes)
    {
        mesh.makeBuffer(device);
    }

    Camera camera = new Camera();

    void Start()
    {

        camera.position.y = 1f;
        camera.position.z = 3f;
    }

    void Update(float delta)
    {
        meshes[0].rotation.y += 1.0f * delta;
    }

    auto renderThread = new Thread(
        {
            int fpsLimit = 60;
            float delta = 0f;

            Start();

            while (atomicLoad(running))
            {
                MonoTime frameStart = MonoTime.currTime;

                Update(delta);
                renderer.renderFrame(view, meshes, camera);

                Duration elapsed = MonoTime.currTime - frameStart;
                double targetMs = 1000.0 / fpsLimit;
                double msToSleep = targetMs - elapsed.total!"usecs" / 1000.0;
                if (msToSleep > 0) Thread.sleep(dur!"msecs"(cast(int) (msToSleep*4/5)));
                while ((MonoTime.currTime - frameStart) < dur!"usecs"(cast(int)(targetMs*1000)))
                {}

                delta = (MonoTime.currTime - frameStart).total!"usecs" / 1_000_000f;
                //writeln("FPS: ", 1f/delta);
            }
        }
    );

    renderThread.start();

    while (atomicLoad(running))
    {
        pollEvents();
    }
}
