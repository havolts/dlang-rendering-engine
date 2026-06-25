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

__gshared MTLBuffer cubeVertexBuffer;
__gshared MTLBuffer transformationBuffer;

__gshared MTLTexture depthTexture;
__gshared MTLDepthStencilState depthStencilState;

float angleInDegrees = 45;

struct VertexData
{
    float4 position;
    float4 color;
}

struct TransformationData
{
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 perspectiveMatrix;
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

void encodeRenderCommand(MTLRenderCommandEncoder renderCommandEncoder)
{
    float4x4 translationMatrix = float4x4([[1f,0,0,0],
                                           [0,1f,0,0],
                                           [0,0,1f,-1f],
                                           [0,0,0,1f]]);

    angleInDegrees++;
    float angleInRadians = angleInDegrees * PI /180.0f;

    float4x4 rotationMatrix = float4x4([[cos(angleInRadians),0,sin(angleInRadians),0],
                                        [0,1f,0,0],
                                        [-sin(angleInRadians),0,cos(angleInRadians),0],
                                        [0,0,0,1f]]) * float4x4([[1f,0,0,0],
                                                                 [0,cos(angleInRadians),sin(angleInRadians),0],
                                                                 [0,-sin(angleInRadians),cos(angleInRadians),0],
                                                                 [0,0,0,1f]]) * float4x4([[cos(angleInRadians),-sin(angleInRadians),0,0],
                                                                                          [sin(angleInRadians),cos(angleInRadians),0,0],
                                                                                          [0,0,1f,0],
                                                                                          [0,0,0,1f]]);

    float4x4 modelMatrix = translationMatrix * rotationMatrix;

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
    modelMatrix.rowToColumnMajor();
    viewMatrix.rowToColumnMajor();
    perspectiveMatrix.rowToColumnMajor();
    TransformationData transformationData = {modelMatrix, viewMatrix, perspectiveMatrix};

    auto contentsPtr = transformationBuffer.contents();
    *(cast(TransformationData*) contentsPtr) = transformationData;

    renderCommandEncoder.setFrontFacingWinding(MTLWinding.MTLWindingCounterClockwise);
    renderCommandEncoder.setCullMode(MTLCullMode.MTLCullModeBack);
    renderCommandEncoder.setRenderPipelineState(metalRenderPSO);
    renderCommandEncoder.setDepthStencilState(depthStencilState);
    renderCommandEncoder.setVertexBuffer(cubeVertexBuffer, 0, 0);
    renderCommandEncoder.setVertexBuffer(transformationBuffer, 0, 1);
    MTLPrimitiveType typeTriangle = MTLPrimitiveType.triangle;
    NSUInteger vertexStart = 0;
    NSUInteger vertexCount = 36;
    renderCommandEncoder.drawPrimitives(typeTriangle, vertexStart, vertexCount);
}

void createCube()
{
VertexData[] cubeVertices =
    [
        // Front face (RED)
        {{-0.5, -0.5, 0.5, 1.0}, {1.0, 0.2, 0.2, 1.0}},
        {{0.5, -0.5, 0.5, 1.0}, {1.0, 0.2, 0.2, 1.0}},
        {{0.5, 0.5, 0.5, 1.0}, {1.0, 0.2, 0.2, 1.0}},
        {{0.5, 0.5, 0.5, 1.0}, {1.0, 0.2, 0.2, 1.0}},
        {{-0.5, 0.5, 0.5, 1.0}, {1.0, 0.2, 0.2, 1.0}},
        {{-0.5, -0.5, 0.5, 1.0}, {1.0, 0.2, 0.2, 1.0}},

        // Back face (BLUE)
        {{0.5, -0.5, -0.5, 1.0}, {0.2, 0.2, 1.0, 1.0}},
        {{-0.5, -0.5, -0.5, 1.0}, {0.2, 0.2, 1.0, 1.0}},
        {{-0.5, 0.5, -0.5, 1.0}, {0.2, 0.2, 1.0, 1.0}},
        {{-0.5, 0.5, -0.5, 1.0}, {0.2, 0.2, 1.0, 1.0}},
        {{0.5, 0.5, -0.5, 1.0}, {0.2, 0.2, 1.0, 1.0}},
        {{0.5, -0.5, -0.5, 1.0}, {0.2, 0.2, 1.0, 1.0}},

        // Top face (GREEN)
        {{-0.5, 0.5, 0.5, 1.0}, {0.2, 1.0, 0.2, 1.0}},
        {{0.5, 0.5, 0.5, 1.0}, {0.2, 1.0, 0.2, 1.0}},
        {{0.5, 0.5, -0.5, 1.0}, {0.2, 1.0, 0.2, 1.0}},
        {{0.5, 0.5, -0.5, 1.0}, {0.2, 1.0, 0.2, 1.0}},
        {{-0.5, 0.5, -0.5, 1.0}, {0.2, 1.0, 0.2, 1.0}},
        {{-0.5, 0.5, 0.5, 1.0}, {0.2, 1.0, 0.2, 1.0}},

        // Bottom face (YELLOW)
        {{-0.5, -0.5, -0.5, 1.0}, {1.0, 1.0, 0.2, 1.0}},
        {{0.5, -0.5, -0.5, 1.0}, {1.0, 1.0, 0.2, 1.0}},
        {{0.5, -0.5, 0.5, 1.0}, {1.0, 1.0, 0.2, 1.0}},
        {{0.5, -0.5, 0.5, 1.0}, {1.0, 1.0, 0.2, 1.0}},
        {{-0.5, -0.5, 0.5, 1.0}, {1.0, 1.0, 0.2, 1.0}},
        {{-0.5, -0.5, -0.5, 1.0}, {1.0, 1.0, 0.2, 1.0}},

        // Left face (MAGENTA/PURPLE)
        {{-0.5, -0.5, -0.5, 1.0}, {1.0, 0.2, 1.0, 1.0}},
        {{-0.5, -0.5, 0.5, 1.0}, {1.0, 0.2, 1.0, 1.0}},
        {{-0.5, 0.5, 0.5, 1.0}, {1.0, 0.2, 1.0, 1.0}},
        {{-0.5, 0.5, 0.5, 1.0}, {1.0, 0.2, 1.0, 1.0}},
        {{-0.5, 0.5, -0.5, 1.0}, {1.0, 0.2, 1.0, 1.0}},
        {{-0.5, -0.5, -0.5, 1.0}, {1.0, 0.2, 1.0, 1.0}},

        // Right face (CYAN)
        {{0.5, -0.5, 0.5, 1.0}, {0.2, 1.0, 1.0, 1.0}},
        {{0.5, -0.5, -0.5, 1.0}, {0.2, 1.0, 1.0, 1.0}},
        {{0.5, 0.5, -0.5, 1.0}, {0.2, 1.0, 1.0, 1.0}},
        {{0.5, 0.5, -0.5, 1.0}, {0.2, 1.0, 1.0, 1.0}},
        {{0.5, 0.5, 0.5, 1.0}, {0.2, 1.0, 1.0, 1.0}},
        {{0.5, -0.5, 0.5, 1.0}, {0.2, 1.0, 1.0, 1.0}},
    ];

    cubeVertexBuffer = device.makeBuffer(cubeVertices.ptr, cubeVertices.length * VertexData.sizeof, MTLResourceOptions.storageModeShared);
    transformationBuffer = device.makeBuffer(TransformationData.sizeof, MTLResourceOptions.storageModeShared);
}

void createTriangle()
{
    static immutable float[42] triangleVertices =
    [
        // Triangle 1 (red)
        -0.5f, -0.5f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f,
         0.0f, -0.5f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f,
         0.0f,  0.5f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f,

        // Triangle 2 (blue)
         0.5f, -0.5f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f,
         0.0f, -0.5f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f,
         0.0f,  0.5f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f,
    ];
    //triangleVertexBuffer = device.makeBuffer(
        //triangleVertices.ptr,
        //triangleVertices.length * float.sizeof,
        //MTLResourceOptions.storageModeShared
    //);
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
        auto depthAttachment = renderPassDescriptor.depthAttachment;
        depthAttachment.loadAction = MTLLoadAction.clear;
        depthAttachment.clearDepth = 1.0;
        depthAttachment.storeAction = MTLStoreAction.dontCare;

        auto renderEncoder = commandBuffer.makeRenderCommandEncoder(renderPassDescriptor);
        if (renderEncoder is null) continue;

        size_t vertexStart = 0;
        size_t vertexCount = 6;

        encodeRenderCommand(renderEncoder);

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
    view.depthStencilPixelFormat = MTLPixelFormat.Depth32Float;
    view.clearColor = MTLClearColor(0.0, 0.0, 1.0, 1.0);

    win = new shared Window(600, 600, "Test");
    win.doTerminateOnClose(true);
    win.setContentView(view);
    win.start();
    win.show();
    //createTriangle();
    createCube();
    createDefaultLibrary();
    commandQueue = device.makeCommandQueue();
    createRenderPipeline();

    spawn(&renderThread);
    while (atomicLoad(running))
    {
        pollEvents();
    }
}
