// renderengine/source/main.d
module main;

import macoswindowing.window;
import metalrendering;
import mesh;
import renderer;
import types;
import texture;
import camera;

import std.stdio;
import std.math;
import core.atomic;
import core.time;
import core.thread;


shared Window window;
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
    MTLDevice device = MTLCreateSystemDefaultDevice();

    window = new shared Window(600, 600, "Test");

    float aspectRatio = window.width/window.height;

    Renderer renderer = new Renderer(device, aspectRatio);

    Mesh[] meshes;

    frame = CGRect(CGPoint(0,0), CGSize(600,600));
    MTKView view = MTKView.alloc().initWithFrame(frame, device);
    view.colorPixelFormat = MTLPixelFormat.BGRA8Unorm_sRGB;
    view.depthStencilPixelFormat = MTLPixelFormat.Depth32Float;
    view.clearColor = MTLClearColor(1.0, 0.0, 0.0, 1.0);

    window.doTerminateOnClose(true);
    window.setContentView(view);
    window.start();
    window.show();

    meshes ~= createCubeMesh(renderer);
    meshes ~= createCubeMesh(renderer);
    meshes ~= createCubeMesh(renderer);

    foreach(Mesh mesh; meshes)
    {
        mesh.makeBuffer(device);
    }

    Camera camera = new Camera();

    void Update(float delta)
    {
        meshes[1].position.x = 1f;
        meshes[2].position.x = -1f;

        camera.position.y = 1f;
        camera.position.z = 3f;
    }

    auto renderThread = new Thread(
        {
            MonoTime lastFrameTime = MonoTime.currTime;

            while (atomicLoad(running))
            {
                MonoTime frameStart = MonoTime.currTime;
                float delta = (frameStart - lastFrameTime).total!"usecs" / 1_000_000f;
                lastFrameTime = frameStart;

                Update(delta);

                renderer.renderFrame(view, meshes, camera);
            }
        }
    );

    renderThread.start();

    while (atomicLoad(running))
    {
        pollEvents();
    }
}
