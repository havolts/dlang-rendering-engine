module renderer;
import macoswindowing.window;
import metalrendering;
import mesh;
import std.stdio;
import std.math;
import types;
import texture;
import camera;

class Renderer
{
    MTLDevice device;
    MTLCommandQueue commandQueue;
    MTLLibrary library;
    MTLRenderPipelineState renderPipelineState;
    MTLDepthStencilState depthStencilState;
    float4x4 perspectiveMatrix;

    this(MTLDevice device, float aspectRatio)
    {
        this.device = device;
        this.commandQueue = device.makeCommandQueue();
        this.library = device.makeDefaultLibrary();
        this.renderPipelineState = buildPipelineState(device, library);
        this.depthStencilState = buildDepthStencilState(device);
        this.perspectiveMatrix = matrix_perspective_right_hand(90 * PI/180f, aspectRatio, 0.1f, 100f);
        this.perspectiveMatrix.rowToColumnMajor();
    }

    void renderFrame(MTKView view, Mesh[] meshes, Camera camera)
    {
        auto pool = NSAutoreleasePool.alloc().init();
        scope(exit) pool.drain();

        MTLDrawable drawable = view.currentDrawable;
        if (drawable is null)
        {
            writeln("Drawable has value: null");
            return;
        }

        auto commandBuffer = commandQueue.makeCommandBuffer();
        if (commandBuffer is null)
        {
            writeln("Command Buffer has value: null");
            return;
        }

        auto renderPassDescriptor = view.currentRenderPassDescriptor;
        if (renderPassDescriptor is null)
        {
            writeln("Failed renderPassDescriptor check.");
            return;
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
            return;
        }
        renderEncoder.setFrontFacingWinding(MTLWinding.MTLWindingClockwise);
        renderEncoder.setCullMode(MTLCullMode.MTLCullModeBack);
        renderEncoder.setRenderPipelineState(renderPipelineState);
        renderEncoder.setDepthStencilState(depthStencilState);

        if(meshes is null)
        {
            writeln("Failed cube check.");
        }

        camera.Update();

        foreach(Mesh mesh; meshes)
        {
            mesh.encodeRenderCommand(renderEncoder, camera.viewMatrix, perspectiveMatrix);
        }

        renderEncoder.endEncoding();
        commandBuffer.present(drawable);
        commandBuffer.commit();
    }
}

MTLRenderPipelineState buildPipelineState(MTLDevice device, MTLLibrary library)
{
    auto vertexShader = library.makeFunction("vertexShader".ns);
    auto fragmentShader = library.makeFunction("fragmentShader".ns);
    if(!vertexShader) writeln("vs failed");
    if(!fragmentShader) writeln("fs failed");

    MTLRenderPipelineDescriptor renderPipelineDescriptor = MTLRenderPipelineDescriptor.alloc().init();

    renderPipelineDescriptor.label = "Triangle Rendering Pipeline".ns;
    renderPipelineDescriptor.vertexFunction = vertexShader;
    renderPipelineDescriptor.fragmentFunction = fragmentShader;
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.BGRA8Unorm_sRGB;
    renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormat.Depth32Float;

    void* error;
    MTLRenderPipelineState metalRenderPSO = device.makeRenderPipelineState(renderPipelineDescriptor, error);
    if (metalRenderPSO is null)
    {
        writeln("Failed to create pipeline: ", error);
    }

    renderPipelineDescriptor.release();
    return metalRenderPSO;
}

MTLDepthStencilState buildDepthStencilState(MTLDevice device)
{
    auto depthStencilDescriptor = MTLDepthStencilDescriptor.alloc().init();
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual;
    depthStencilDescriptor.depthWriteEnabled = true;
    MTLDepthStencilState depthStencilState = device.makeDepthStencilState(depthStencilDescriptor);
    if (depthStencilState is null)
    {
        writeln("Failed to create pipeline.");
    }
    depthStencilDescriptor.release();
    return depthStencilState;
}

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
