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
shared bool running = true;

void renderThread()
{
    float fpsLimit = 1000/60;
    int fpsLimitInt = cast(int)round(fpsLimit);
    while (atomicLoad(running))
    {
        auto pool = NSAutoreleasePool.alloc().init();
        scope(exit) pool.drain();

        Thread.sleep(fpsLimitInt.msecs);
        double x = uniform(0, 255);
        double y = uniform(0, 255);
        double z = uniform(0, 255);
        view.clearColor = MTLClearColor(x / 255, y / 255, z / 255, 1.0);
        auto commandBuffer = commandQueue.makeCommandBuffer();
        if (commandBuffer is null) continue;
        auto renderPassDescriptor = view.currentRenderPassDescriptor;
        if (renderPassDescriptor is null) continue;
        auto renderEncoder = commandBuffer.makeRenderCommandEncoder(renderPassDescriptor);
        if (renderEncoder is null) continue;
        renderEncoder.endEncoding();
        auto drawable = view.currentDrawable;
        if (drawable is null) continue;
        commandBuffer.present(drawable);
        commandBuffer.commit();
    }
}
void main()
{
    win = new shared Window(1000, 750, "Test");
    win.doTerminateOnClose(true);
    win.start();

    frame = CGRect(CGPoint(0,0), CGSize(1000,750));
    device = MTLCreateSystemDefaultDevice();
    view = MTKView.alloc().initWithFrame(frame, device);
    view.clearColor = MTLClearColor(0.0, 0.0, 1.0, 1.0);

    win.setContentView(view);
    commandQueue = device.makeCommandQueue();

    spawn(&renderThread);
    while (atomicLoad(running))
    {
        pollEvents();
    }
}
