// renderengine/source/main.d
module main;

import camera;
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

Mesh createCubeMesh(Renderer renderer)
{
    VertexData[] cubeVertices =
    [
        //front
        {{-0.5, -0.5,  0.5, 1.0f}, {0.0f, 1.0f}, 0},
        {{-0.5,  0.5,  0.5, 1.0f}, {0.0f, 0.0f}, 0},
        {{ 0.5,  0.5,  0.5, 1.0f}, {1.0f, 0.0f}, 0},
        {{-0.5, -0.5,  0.5, 1.0f}, {0.0f, 1.0f}, 0},
        {{ 0.5,  0.5,  0.5, 1.0f}, {1.0f, 0.0f}, 0},
        {{ 0.5, -0.5,  0.5, 1.0f}, {1.0f, 1.0f}, 0},
        //right
        {{ 0.5,  0.5,  0.5, 1.0f}, {0.0f, 0.0f}, 0},
        {{ 0.5,  0.5, -0.5, 1.0f}, {1.0f, 0.0f}, 0},
        {{ 0.5, -0.5,  0.5, 1.0f}, {0.0f, 1.0f}, 0},
        {{ 0.5,  0.5, -0.5, 1.0f}, {1.0f, 0.0f}, 0},
        {{ 0.5, -0.5, -0.5, 1.0f}, {1.0f, 1.0f}, 0},
        {{ 0.5, -0.5,  0.5, 1.0f}, {0.0f, 1.0f}, 0},
        //back
        {{-0.5, -0.5, -0.5, 1.0f}, {0.0f, 1.0f}, 0},
        {{ 0.5,  0.5, -0.5, 1.0f}, {1.0f, 0.0f}, 0},
        {{-0.5,  0.5, -0.5, 1.0f}, {0.0f, 0.0f}, 0},
        {{-0.5, -0.5, -0.5, 1.0f}, {0.0f, 1.0f}, 0},
        {{ 0.5, -0.5, -0.5, 1.0f}, {1.0f, 1.0f}, 0},
        {{ 0.5,  0.5, -0.5, 1.0f}, {1.0f, 0.0f}, 0},
        //left
        {{-0.5, -0.5, -0.5, 1.0f}, {0.0f, 1.0f}, 0},
        {{-0.5,  0.5, -0.5, 1.0f}, {0.0f, 0.0f}, 0},
        {{-0.5,  0.5,  0.5, 1.0f}, {1.0f, 0.0f}, 0},
        {{-0.5, -0.5, -0.5, 1.0f}, {0.0f, 1.0f}, 0},
        {{-0.5,  0.5,  0.5, 1.0f}, {1.0f, 0.0f}, 0},
        {{-0.5, -0.5,  0.5, 1.0f}, {1.0f, 1.0f}, 0},
        //top
        {{-0.5,  0.5,  0.5, 1.0f}, {0.0f, 1.0f}, 2},
        {{-0.5,  0.5, -0.5, 1.0f}, {0.0f, 0.0f}, 2},
        {{ 0.5,  0.5, -0.5, 1.0f}, {1.0f, 0.0f}, 2},
        {{-0.5,  0.5,  0.5, 1.0f}, {0.0f, 1.0f}, 2},
        {{ 0.5,  0.5, -0.5, 1.0f}, {1.0f, 0.0f}, 2},
        {{ 0.5,  0.5,  0.5, 1.0f}, {1.0f, 1.0f}, 2},
        //bottom
        {{-0.5, -0.5, -0.5, 1.0f}, {0.0f, 1.0f}, 1},
        {{-0.5, -0.5,  0.5, 1.0f}, {0.0f, 0.0f}, 1},
        {{ 0.5, -0.5,  0.5, 1.0f}, {1.0f, 0.0f}, 1},
        {{-0.5, -0.5, -0.5, 1.0f}, {0.0f, 1.0f}, 1},
        {{ 0.5, -0.5,  0.5, 1.0f}, {1.0f, 0.0f}, 1},
        {{ 0.5, -0.5, -0.5, 1.0f}, {1.0f, 1.0f}, 1},
    ];
    Texture grassSideTexture = new Texture("source/assets/grass-side.jpg", renderer.device);
    Texture grassTopTexture = new Texture("source/assets/grass-top.jpg", renderer.device);
    Texture dirtTexture = new Texture("source/assets/dirt.jpg", renderer.device);
    Texture[] textures = [grassSideTexture, dirtTexture, grassTopTexture];
    Mesh mesh = new Mesh(cubeVertices, &renderer.renderPipelineState, &renderer.depthStencilState, textures);
    return mesh;
}

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


    meshes ~= createCubeMesh(renderer);
    meshes ~= createCubeMesh(renderer);
    meshes ~= createCubeMesh(renderer);

    foreach(Mesh mesh; meshes)
    {
        mesh.makeBuffer(device);
    }

    Camera camera = new Camera();

    void Start()
    {
        meshes[1].position.x = 1f;
        meshes[2].position.x = -1f;

        camera.position.y = 1f;
        camera.position.z = 3f;
    }

    void Update(float delta)
    {
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
                writeln("FPS: ", 1f/delta);
            }
        }
    );

    renderThread.start();

    while (atomicLoad(running))
    {
        pollEvents();
    }
}
