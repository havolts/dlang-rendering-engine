// renderengine/source/main.d
import macoswindowing.window;
import metalrendering;
import std.stdio;
import std.file;
import std.random;
import std.concurrency;
import std.math;
import core.atomic;
import core.time;
import core.thread;

shared Window win;
MTLDevice device;
CGRect frame;
__gshared MTKView view;
__gshared MTLCommandQueue commandQueue;

MTLLibrary metalDefaultLibrary;
MTLDrawable drawable;
__gshared MTLBuffer triangleVertexBuffer;
__gshared MTLRenderPipelineState metalRenderPSO;
shared bool running = true;

void createTriangle()
{
    static immutable float[9] triangleVertices =
    [
        -0.5f, -0.5f, 0.0f,
         0.5f, -0.5f, 0.0f,
         0.0f,  0.5f, 0.0f,
    ];
    triangleVertexBuffer = device.makeBuffer(
        triangleVertices.ptr,
        triangleVertices.length * float.sizeof,
        MTLResourceOptions.storageModeShared
    );
}

void createDefaultLibrary()
{
    metalDefaultLibrary = device.makeDefaultLibrary();
    if(metalDefaultLibrary is null)
    {
        writeln("Failed to load default library.");
    }
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

    void* error;
    metalRenderPSO = device.makeRenderPipelineState(renderPipelineDescriptor, error);
    if (metalRenderPSO is null) {
        writeln("Failed to create pipeline: ", error);
    }

    renderPipelineDescriptor.release();
}

void renderThread()
{
    float fpsLimit = 120;
    int fpsLimitInt = cast(int)round((1000/fpsLimit));
    void* lastDrawablePtr = null;

    while (atomicLoad(running))
    {
        auto pool = NSAutoreleasePool.alloc().init();
        scope(exit) pool.drain();
        Thread.sleep(fpsLimitInt.msecs);

        auto commandBuffer = commandQueue.makeCommandBuffer();
        if (commandBuffer is null) continue;

        drawable = view.currentDrawable;
        if (drawable is null) continue;

        auto currentPtr = cast(void*) drawable;
        if (currentPtr == lastDrawablePtr) continue;
        lastDrawablePtr = currentPtr;

        auto renderPassDescriptor = view.currentRenderPassDescriptor;
        if (renderPassDescriptor is null) continue;

        auto cd = renderPassDescriptor.colorAttachments[0];
        cd.texture = drawable.texture;
        cd.loadAction = MTLLoadAction.clear;
        cd.clearColor = MTLClearColor(41.0f/255.0f, 42.0f/255.0f, 48.0f/255.0f, 1.0);
        cd.storeAction = MTLStoreAction.store;

        auto renderEncoder = commandBuffer.makeRenderCommandEncoder(renderPassDescriptor);
        if (renderEncoder is null) continue;

        renderEncoder.setRenderPipelineState(metalRenderPSO);
        renderEncoder.setVertexBuffer(triangleVertexBuffer, 0, 0);
        MTLPrimitiveType typeTriangle = MTLPrimitiveType.triangle;

        size_t vertexStart = 0;
        size_t vertexCount = 3;
        renderEncoder.drawPrimitives(typeTriangle, vertexStart, vertexCount);
        renderEncoder.endEncoding();
        commandBuffer.present(drawable);
        commandBuffer.commit();
    }
}

void main()
{
    frame = CGRect(CGPoint(0,0), CGSize(600,600));
    device = MTLCreateSystemDefaultDevice();
    view = MTKView.alloc().initWithFrame(frame, device);
    view.clearColor = MTLClearColor(0.0, 0.0, 1.0, 1.0);

    win = new shared Window(600, 600, "Test");
    win.doTerminateOnClose(true);
    win.setContentView(view);
    win.start();
    win.show();
    createTriangle();
    createDefaultLibrary();
    commandQueue = device.makeCommandQueue();
    createRenderPipeline();

    spawn(&renderThread);
    while (atomicLoad(running))
    {
        pollEvents();
    }
}
