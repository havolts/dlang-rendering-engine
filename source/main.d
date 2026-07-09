// renderengine/source/main.d
module main;
import macoswindowing.window;
import metalrendering;
import mesh;
import std.stdio;
import std.file;
import std.random;
import std.concurrency;
import std.math;
import core.atomic;
import core.time;
import core.thread;
import types;

shared Window win;
MTLDevice device;
CGRect frame;
__gshared MTKView view;
__gshared MTLCommandQueue commandQueue;

MTLLibrary metalDefaultLibrary;
MTLDrawable drawable;
__gshared MTLRenderPipelineState metalRenderPSO;
shared bool running = true;

__gshared MTLTexture depthTexture;
__gshared MTLDepthStencilState depthStencilState;

__gshared Mesh triangle;
__gshared Mesh cube;

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

void createTriangleMesh()
{
    VertexData[] triangleVertices =
    [
        // Triangle 1 (red)
        {{-0.5f, -0.5f, 0.0f, 0.5f}, {1.0f, 0.0f, 0.0f, 1.0f}},
        {{0.0f, -0.5f, 0.0f, 0.5f}, {1.0f, 0.0f, 0.0f, 1.0f}},
        {{0.0f,  0.5f, 0.0f, 0.5f}, {1.0f, 0.0f, 0.0f, 1.0f}},
    ];
    uint[] triangleIndices =
    [
        // Triangle 1 (red)
        0,1,2
    ];
    triangle = new Mesh(triangleVertices, triangleIndices, triangleIndices.length, win, &metalRenderPSO, &depthStencilState);
    triangle.makeBuffer(device);
}

void createCubeMesh()
{
    VertexData[] cubeVertices =
    [
        // Front-bottom-left  (0)
        {{-0.5f, -0.5f,  0.5f, 1.0f}, {1.0f, 0.0f, 0.0f, 1.0f}},
        // Front-bottom-right (1)
        {{ 0.5f, -0.5f,  0.5f, 1.0f}, {0.5f, 0.5f, 0.0f, 1.0f}},
        // Front-top-right    (2)
        {{ 0.5f,  0.5f,  0.5f, 1.0f}, {0.0f, 1.0f, 0.0f, 1.0f}},
        // Front-top-left     (3)
        {{-0.5f,  0.5f,  0.5f, 1.0f}, {0.0f, 0.5f, 0.5f, 1.0f}},

        // Back-bottom-left   (4)
        {{-0.5f, -0.5f, -0.5f, 1.0f}, {0.0f, 0.0f, 1.0f, 1.0f}},
        // Back-bottom-right  (5)
        {{ 0.5f, -0.5f, -0.5f, 1.0f}, {0.5f, 0.0f, 0.5f, 1.0f}},
        // Back-top-right     (6)
        {{ 0.5f,  0.5f, -0.5f, 1.0f}, {1.0f, 0.0f, 0.0f, 1.0f}},
        // Back-top-left      (7)
        {{-0.5f,  0.5f, -0.5f, 1.0f}, {0.0f, 1.0f, 0.0f, 1.0f}},
    ];

    uint[] cubeIndices =
    [
        // Front face
        0, 1, 2,  2, 3, 0,
        // Back face
        5, 4, 7,  7, 6, 5,
        // Left face
        4, 0, 3,  3, 7, 4,
        // Right face
        1, 5, 6,  6, 2, 1,
        // Top face
        3, 2, 6,  6, 7, 3,
        // Bottom face
        4, 5, 1,  1, 0, 4,
    ];

    cube = new Mesh(cubeVertices, cubeIndices, cubeIndices.length, win, &metalRenderPSO, &depthStencilState);
    cube.makeBuffer(device);
}

void createRenderPipeline()
{
    auto vertexShader = metalDefaultLibrary.makeFunction("vertexShader".ns);
    auto fragmentShader = metalDefaultLibrary.makeFunction("fragmentShader".ns);
    if(!vertexShader) writeln("vs failed");
    if(!fragmentShader) writeln("fs failed");
    MTLRenderPipelineDescriptor renderPipelineDescriptor = MTLRenderPipelineDescriptor.alloc().init();

    renderPipelineDescriptor.label = "Triangle Rendering Pipeline".ns;
    renderPipelineDescriptor.vertexFunction = vertexShader;
    renderPipelineDescriptor.fragmentFunction = fragmentShader;
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.BGRA8Unorm;
    renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormat.Depth32Float;

    void* error;
    metalRenderPSO = device.makeRenderPipelineState(renderPipelineDescriptor, error);
    if (metalRenderPSO is null) {
        writeln("Failed to create pipeline: ", error);
    }

    auto depthStencilDescriptor = MTLDepthStencilDescriptor.alloc().init();
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual;
    depthStencilDescriptor.depthWriteEnabled = true;
    depthStencilState = device.makeDepthStencilState(depthStencilDescriptor);
    depthStencilDescriptor.release();

    renderPipelineDescriptor.release();
}

void renderThread()
{
    writeln("Passed renderThread Start.");
    void* lastDrawablePtr = null;

    MonoTime lastFrameTime = MonoTime.currTime;
    long fpsLimit = 60L; // Changed to 60 for testing
    long targetFrameTime = 1_000_000L / fpsLimit; // microseconds per frame

    while (atomicLoad(running))
    {
        MonoTime frameStart = MonoTime.currTime;

        // Calculate delta time
        Duration frameTime = frameStart - lastFrameTime;
        lastFrameTime = frameStart;
        float delta = frameTime.total!"usecs" / 1_000_000f;

        // Optional: print FPS (comment out for performance)
        // writeln(1f/delta);

        cube.rotation.x += 1f * delta;

        auto pool = NSAutoreleasePool.alloc().init();
        scope(exit) pool.drain();

        auto commandBuffer = commandQueue.makeCommandBuffer();
        if (commandBuffer is null)
        {
            writeln("Failed commandBuffer check.");
            continue;
        }

        drawable = view.currentDrawable;
        if (drawable is null)
        {
            writeln("Failed drawable check.");
            continue;
        }

        auto currentPtr = cast(void*) drawable;
        if (currentPtr == lastDrawablePtr)
        {
            continue;
        }
        lastDrawablePtr = currentPtr;

        auto renderPassDescriptor = view.currentRenderPassDescriptor;
        if (renderPassDescriptor is null)
        {
            writeln("Failed renderPassDescriptor check.");
            continue;
        }

        auto cd = renderPassDescriptor.colorAttachments[0];
        cd.texture = drawable.texture;
        cd.loadAction = MTLLoadAction.clear;
        cd.clearColor = MTLClearColor(41.0f/255.0f, 42.0f/255.0f, 48.0f/255.0f, 1.0);
        cd.storeAction = MTLStoreAction.store;
        auto depthAttachment = renderPassDescriptor.depthAttachment;
        depthAttachment.loadAction = MTLLoadAction.clear;
        depthAttachment.clearDepth = 1.0;
        depthAttachment.storeAction = MTLStoreAction.dontCare;

        auto renderEncoder = commandBuffer.makeRenderCommandEncoder(renderPassDescriptor);
        if (renderEncoder is null)
        {
            writeln("Failed renderEncoder check.");
            continue;
        }
        renderEncoder.setFrontFacingWinding(MTLWinding.MTLWindingCounterClockwise);
        renderEncoder.setCullMode(MTLCullMode.MTLCullModeNone);
        renderEncoder.setRenderPipelineState(metalRenderPSO);
        renderEncoder.setDepthStencilState(depthStencilState);

        if(cube is null)
        {
            writeln("Failed cube check.");
        }

        float3 R = float3(1f,0,0);
        float3 U = float3(0,1f,0);
        float3 F = float3(0,0,-1f);
        float3 P = float3(0,0,3f);

        float4x4 viewMatrix = float4x4([[R.x, R.y, R.z, dot(-R, P)],
                                        [U.x, U.y, U.z, dot(-U, P)],
                                        [-F.x, -F.y, -F.z, dot(F, P)],
                                        [0f , 0f , 0f , 1f]]);

        float aspectRatio = win.width/win.height;
        float fov = 90 * (PI / 180f);
        float nearZ = 0.1f;
        float farZ = 100.0f;

        float4x4 perspectiveMatrix = matrix_perspective_right_hand(fov, aspectRatio, nearZ, farZ);

        viewMatrix.rowToColumnMajor();
        perspectiveMatrix.rowToColumnMajor();

        triangle.encodeRenderCommand(renderEncoder, viewMatrix, perspectiveMatrix);
        cube.encodeRenderCommand(renderEncoder, viewMatrix, perspectiveMatrix);

        renderEncoder.endEncoding();
        commandBuffer.present(drawable);
        commandBuffer.commit();

        // Frame limiting with proper handling
        MonoTime frameEnd = MonoTime.currTime;
        long elapsed = (frameEnd - frameStart).total!"usecs";
        long sleepTime = targetFrameTime - elapsed;

        if (sleepTime > 0)
        {
            Thread.sleep(sleepTime.usecs);
        }
        else if (sleepTime < 0)
        {
            // Optionally warn about frame drops
            //writeln("Frame took too long: ", elapsed, "us (target: ", targetFrameTime, "us)");
        }

        // Optionally yield to other threads even when not sleeping
        if (sleepTime <= 0)
        {
            Thread.yield();
        }
    }
}

void main()
{
    device = MTLCreateSystemDefaultDevice();
    commandQueue = device.makeCommandQueue();
    metalDefaultLibrary = device.makeDefaultLibrary();

    frame = CGRect(CGPoint(0,0), CGSize(600,600));
    view = MTKView.alloc().initWithFrame(frame, device);
    view.depthStencilPixelFormat = MTLPixelFormat.Depth32Float;
    view.clearColor = MTLClearColor(1.0, 0.0, 0.0, 1.0);

    win = new shared Window(600, 600, "Test");
    win.doTerminateOnClose(true);
    win.setContentView(view);
    win.start();
    win.show();

    writeln("Passed init.");

    createRenderPipeline();
    writeln("Passed createRenderPipeline.");
    createTriangleMesh();
    createCubeMesh();
    writeln("Passed createTriangleMesh.");
    spawn(&renderThread);
    while (atomicLoad(running))
    {
        pollEvents();
    }
}
