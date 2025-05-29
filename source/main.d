// renderengine/source/main.d
import macoswindowing.window;
import metalrendering;
import std.stdio;
import std.file;
import core.thread;
import std.random;

void main()
{
    shared Window win;
    win = new shared Window(1000, 750, "Test");
    win.doTerminateOnClose(true);
    win.start();

    MTLDevice device = MTLCreateSystemDefaultDevice();
    CGRect frame = CGRect(0, 0, 1000, 750);
    MTKView view = new MTKView(device, frame);
    view.clearColor = MTLClearColor(0.0, 0.0, 1.0, 1.0);

    win.setContentView(view);
    MTLCommandQueue commandQueue = device.makeCommandQueue();
    auto running = true;
    while (running)
    {
        pollEvents();
        Thread.sleep(16.msecs);

        double x = uniform(0, 255);
        double y = uniform(0, 255);
        double z = uniform(0, 255);
        view.clearColor = MTLClearColor(x / 255, y / 255, z / 255, 1.0);

        MTLRenderPassDescriptor renderPassDescriptor = view.currentRenderPassDescriptor;
        if (renderPassDescriptor.ptr is null)
        {
            writeln("rpd failed");
            continue;
        }

        auto colorAttachment = renderPassDescriptor.colorAttachments[0];
        colorAttachment.loadAction = MTLLoadAction.MTLLoadActionClear;
        colorAttachment.clearColor = view.clearColor;

        MTLCommandBuffer commandBuffer = commandQueue.makeCommandBuffer();
        MTLRenderCommandEncoder renderEncoder = commandBuffer.makeRenderCommandEncoder(
            renderPassDescriptor);

        // Your rendering commands would go here

        renderEncoder.endEncoding();

        // Present drawable
        MTLDrawable drawable = view.currentDrawable;
        if (drawable.ptr !is null)
        {
            commandBuffer.present(drawable);
        }
        commandBuffer.commit();
    }
}
