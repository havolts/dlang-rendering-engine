module renderer;
import mesh;
import std.stdio;
import std.math;
import std.string;
import types;
import texture;
import camera;
import node;
import sdl;
import sdl.error;
import sdl.gpu;

class Renderer
{
    SDL_GPUDevice* device;
    SDL_Window* window;
    SDL_GPUShader* vertexShader;
    SDL_GPUShader* fragmentShader;
    SDL_GPUSampler* sampler;

    float4x4 perspectiveMatrix;

    SDL_GPUTexture* depthTexture;
    Uint32 depthWidth  = 0;
    Uint32 depthHeight = 0;

    SDL_GPUGraphicsPipeline* pipeline;

    this(SDL_GPUDevice* device, SDL_Window* window, string vertexShaderPath, string fragmentShaderPath)
    {
        this.device = device;
        this.window = window;
        this.vertexShader = this.loadVertexShader(vertexShaderPath, numUniformBuffers: 1);
        this.fragmentShader = this.loadFragmentShader(fragmentShaderPath, numSamplers: 1);

        SDL_GPUSamplerCreateInfo samplerInfo = {
            min_filter: SDL_GPUFilter.SDL_GPU_FILTER_LINEAR,
            mag_filter: SDL_GPUFilter.SDL_GPU_FILTER_LINEAR,
            mipmap_mode: SDL_GPUSamplerMipmapMode.SDL_GPU_SAMPLERMIPMAPMODE_LINEAR,
            address_mode_u: SDL_GPUSamplerAddressMode.SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
            address_mode_v: SDL_GPUSamplerAddressMode.SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
            address_mode_w: SDL_GPUSamplerAddressMode.SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
        };
        this.sampler = SDL_CreateGPUSampler(device, &samplerInfo);

        this.pipeline = this.buildPipeline();
    }

    ~this()
    {
        if (depthTexture !is null) SDL_ReleaseGPUTexture(device, depthTexture);
        if (pipeline !is null) SDL_ReleaseGPUGraphicsPipeline(device, pipeline);
        if (vertexShader !is null) SDL_ReleaseGPUShader(device, vertexShader);
        if (fragmentShader !is null) SDL_ReleaseGPUShader(device, fragmentShader);
        if (sampler !is null) SDL_ReleaseGPUSampler(device, sampler);
    }

    void renderFrame(Node[] nodes, Camera camera)
    {
        // Acquire Command Buffer
         SDL_GPUCommandBuffer* commandBuffer = SDL_AcquireGPUCommandBuffer(device);

        // Acquire swapchain texture
        SDL_GPUTexture* swapChainTexture;
        Uint32 swapChainWidth, swapChainHeight;
        if(!SDL_AcquireGPUSwapchainTexture(commandBuffer, window, &swapChainTexture, &swapChainWidth, &swapChainHeight))
        {
            SDL_CancelGPUCommandBuffer(commandBuffer);
            return;
        }

        // Ensure the swapchain texture and depth texture have the same width and height
        if (swapChainWidth != depthWidth || swapChainHeight != depthHeight)
        {
            if (depthTexture !is null) SDL_ReleaseGPUTexture(device, depthTexture);

                SDL_GPUTextureCreateInfo depthInfo =
                {
                    type: SDL_GPUTextureType.SDL_GPU_TEXTURETYPE_2D,
                    format: SDL_GPUTextureFormat.SDL_GPU_TEXTUREFORMAT_D32_FLOAT,
                    usage: SDL_GPUTextureUsageFlags.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
                    width: swapChainWidth,
                    height: swapChainHeight,
                    layer_count_or_depth: 1,
                    num_levels: 1,
                    sample_count: SDL_GPUSampleCount.SDL_GPU_SAMPLECOUNT_1,
                };
            depthTexture = SDL_CreateGPUTexture(device, &depthInfo);
            depthWidth  = swapChainWidth;
            depthHeight = swapChainHeight;
            float aspect = cast(float) swapChainWidth / cast(float) swapChainHeight;
            perspectiveMatrix = matrix_perspective_right_hand(90 * PI/180f, aspect, 0.1f, 100f);
        }

        // Define a colour target and depth target
        SDL_GPUColorTargetInfo colorTarget =
            SDL_GPUColorTargetInfo(
                texture: swapChainTexture,
                clear_color: SDL_FColor(r:41.0f/255.0f, g:42.0f/255.0f, b:48.0f/255.0f, a:1.0f),
                load_op: SDL_GPULoadOp.SDL_GPU_LOADOP_CLEAR,
                store_op: SDL_GPUStoreOp.SDL_GPU_STOREOP_STORE
            );
        SDL_GPUDepthStencilTargetInfo depthTarget =
            SDL_GPUDepthStencilTargetInfo(
                texture: depthTexture,
                clear_depth: 1.0f,
                load_op: SDL_GPULoadOp.SDL_GPU_LOADOP_CLEAR,
                store_op: SDL_GPUStoreOp.SDL_GPU_STOREOP_DONT_CARE,
                stencil_load_op: SDL_GPULoadOp.SDL_GPU_LOADOP_DONT_CARE,
                stencil_store_op: SDL_GPUStoreOp.SDL_GPU_STOREOP_DONT_CARE,
            );
        // Start Render Pass
        SDL_GPURenderPass* renderPass = SDL_BeginGPURenderPass(commandBuffer, &colorTarget, 1, &depthTarget);
        SDL_BindGPUGraphicsPipeline(renderPass, pipeline);
        // Draw Nodes
        camera.Update();
        foreach (node; nodes)
        {
            draw(node, camera, renderPass, commandBuffer);
        }
        // End Render Pass
        SDL_EndGPURenderPass(renderPass);
        // Submit Command Buffer
        SDL_SubmitGPUCommandBuffer(commandBuffer);
    }

    void draw(Node node, Camera camera, SDL_GPURenderPass* renderPass, SDL_GPUCommandBuffer* commandBuffer)
    {
        // 1. Push TransformationData (needs the command buffer — see note below)
        TransformationData transformationData = {node.modelMatrix(), camera.viewMatrix, perspectiveMatrix};
        SDL_PushGPUVertexUniformData(commandBuffer, 0, &transformationData, TransformationData.sizeof);

        // 2. Bind vertex buffer
        SDL_GPUBufferBinding vertexBinding = { buffer: node.mesh.vertexBuffer, offset: 0 };
        SDL_BindGPUVertexBuffers(renderPass, 0, &vertexBinding, 1);

        // 3. Bind index buffer
        SDL_GPUBufferBinding indexBinding = { buffer: node.mesh.indexBuffer, offset: 0 };
        SDL_BindGPUIndexBuffer(renderPass, &indexBinding, SDL_GPUIndexElementSize.SDL_GPU_INDEXELEMENTSIZE_32BIT);


        // 5. Bind texture + sampler
        SDL_GPUTextureSamplerBinding texBinding = { texture: node.mesh.textures[0], sampler: sampler };
        SDL_BindGPUFragmentSamplers(renderPass, 0, &texBinding, 1);

        // 6. Draw
        SDL_DrawGPUIndexedPrimitives(renderPass, cast(Uint32)node.mesh.indexCount, 1, 0, 0, 0);
    }

    SDL_GPUGraphicsPipeline* buildPipeline()
    {
        SDL_GPUGraphicsPipeline* p;

        SDL_GPUVertexBufferDescription vertexBufferDescription = {
            slot: 0,              // which slot this buffer binds to
            pitch: VertexData.sizeof,  // bytes per vertex (28)
            input_rate: SDL_GPUVertexInputRate.SDL_GPU_VERTEXINPUTRATE_VERTEX,  // advance per vertex
        };

        SDL_GPUVertexAttribute[] vertexAttributes = [
            SDL_GPUVertexAttribute(
                location: 0,
                buffer_slot: 0,
                format: SDL_GPUVertexElementFormat.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
                offset: VertexData.position.offsetof,
            ),
            SDL_GPUVertexAttribute(
                location: 1,
                buffer_slot: 0,
                format: SDL_GPUVertexElementFormat.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
                offset: VertexData.textureCoordinates.offsetof,
            ),
            SDL_GPUVertexAttribute(
                location: 2,
                buffer_slot: 0,
                format: SDL_GPUVertexElementFormat.SDL_GPU_VERTEXELEMENTFORMAT_UINT,
                offset: VertexData.textureIndex.offsetof,
            )
        ];

        SDL_GPUVertexInputState vertexInputState = SDL_GPUVertexInputState(vertex_buffer_descriptions: &vertexBufferDescription, num_vertex_buffers: 1, vertex_attributes: vertexAttributes.ptr, num_vertex_attributes: cast(Uint32) vertexAttributes.length);

        SDL_GPURasterizerState  rasterizerState = SDL_GPURasterizerState(fill_mode: SDL_GPUFillMode.SDL_GPU_FILLMODE_FILL, cull_mode: SDL_GPUCullMode.SDL_GPU_CULLMODE_BACK, front_face: SDL_GPUFrontFace.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE);

        SDL_GPUMultisampleState multiSampleState = SDL_GPUMultisampleState(sample_count: SDL_GPUSampleCount.SDL_GPU_SAMPLECOUNT_1);

        SDL_GPUDepthStencilState depthStencilState = {
            enable_depth_test: true,
            enable_depth_write: true,
            compare_op: SDL_GPUCompareOp.SDL_GPU_COMPAREOP_LESS_OR_EQUAL,
        };

        SDL_GPUColorTargetDescription colorTargetDescription = {
            format: SDL_GetGPUSwapchainTextureFormat(device, window),
            blend_state: { enable_blend: false },
        };

        SDL_GPUGraphicsPipelineTargetInfo targetInfo = {
            color_target_descriptions: &colorTargetDescription,
            num_color_targets: 1,
            depth_stencil_format: SDL_GPUTextureFormat.SDL_GPU_TEXTUREFORMAT_D32_FLOAT,
            has_depth_stencil_target: true,
        };

        SDL_GPUGraphicsPipelineCreateInfo pipelineInfo = {
            vertex_shader: vertexShader,
            fragment_shader: fragmentShader,
            vertex_input_state:vertexInputState,
            primitive_type: SDL_GPUPrimitiveType.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            rasterizer_state: rasterizerState,
            multisample_state: multiSampleState,
            depth_stencil_state: depthStencilState,
            target_info: targetInfo
        };

        p = SDL_CreateGPUGraphicsPipeline(device, &pipelineInfo);

        if (p is null) writeln("Pipeline creation failed: ", SDL_GetError().fromStringz);
        return p;
    }

    SDL_GPUShader* loadVertexShader(string path, Uint32 numSamplers = 0, Uint32 numUniformBuffers = 0, Uint32 numStorageBuffers = 0, Uint32 numStorageTextures = 0)
    {
        SDL_GPUShaderFormat shaderFormats = SDL_GetGPUShaderFormats(device);
        SDL_GPUShaderFormat format;
        string entrypoint;

        if (shaderFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV)
        {
            format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV;
            path ~= ".spv";
            entrypoint = "main";
        }
        else if (shaderFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL)
        {
            format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL;
            path ~= ".msl";
            entrypoint = "main0";
        }
        else if (shaderFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_DXIL)
        {
            format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_DXIL;
            path ~= ".dxil";
            entrypoint = "main";
        }
        else {
            writeln("No supported shader format for vertex shader");
            return null;
        }

        size_t codeSize;
        void* code = SDL_LoadFile(path.toStringz(), &codeSize);
        if (code is null) {
            writeln("Failed to load vertex shader: ", path);
            return null;
        }
        scope(exit) SDL_free(code);

        SDL_GPUShaderCreateInfo info = {
            code_size: codeSize,
            code: cast(const(Uint8)*) code,
            entrypoint: entrypoint.toStringz(),
            format: format,
            stage: SDL_GPUShaderStage.SDL_GPU_SHADERSTAGE_VERTEX,
            num_samplers: numSamplers,
            num_uniform_buffers: numUniformBuffers,
            num_storage_buffers: numStorageBuffers,
            num_storage_textures: numStorageTextures,
        };

        auto shader = SDL_CreateGPUShader(device, &info);
        if (shader is null) writeln("Failed to create vertex shader: ", SDL_GetError().fromStringz);

        return shader;
    }

    SDL_GPUShader* loadFragmentShader(string path, Uint32 numSamplers = 0, Uint32 numUniformBuffers = 0, Uint32 numStorageBuffers = 0, Uint32 numStorageTextures = 0)
    {
        SDL_GPUShaderFormat shaderFormats = SDL_GetGPUShaderFormats(device);
        SDL_GPUShaderFormat format;
        string entrypoint;

        if (shaderFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV)
        {
            format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV;
            path ~= ".spv";
            entrypoint = "main";
        }
        else if (shaderFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL)
        {
            format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL;
            path ~= ".msl";
            entrypoint = "main0";
        }
        else if (shaderFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_DXIL)
        {
            format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_DXIL;
            path ~= ".dxil";
            entrypoint = "main";
        }
        else {
            writeln("No supported shader format for fragment shader");
            return null;
        }

        size_t codeSize;
        void* code = SDL_LoadFile(path.toStringz(), &codeSize);
        if (code is null) {
            writeln("Failed to load fragment shader: ", path);
            return null;
        }
        scope(exit) SDL_free(code);

        SDL_GPUShaderCreateInfo info = {
            code_size: codeSize,
            code: cast(const(Uint8)*) code,
            entrypoint: entrypoint.toStringz(),
            format: format,
            stage: SDL_GPUShaderStage.SDL_GPU_SHADERSTAGE_FRAGMENT,
            num_samplers: numSamplers,
            num_uniform_buffers: numUniformBuffers,
            num_storage_buffers: numStorageBuffers,
            num_storage_textures: numStorageTextures,
        };

        auto shader = SDL_CreateGPUShader(device, &info);
        if (shader is null) writeln("Failed to create fragment shader: ", SDL_GetError().fromStringz);

        return shader;
    }
}

/*
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

void renderFrame(MTKView view,  Node[] nodes, Camera camera)
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
    renderEncoder.setFrontFacingWinding(MTLWinding.MTLWindingCounterClockwise);
    renderEncoder.setCullMode(MTLCullMode.MTLCullModeBack);
    renderEncoder.setRenderPipelineState(renderPipelineState);
    renderEncoder.setDepthStencilState(depthStencilState);

    camera.Update();

    foreach(Node node; nodes)
    {
        draw(node, camera, renderEncoder);
    }

    renderEncoder.endEncoding();
    commandBuffer.present(drawable);
    commandBuffer.commit();
}

void draw(Node node, Camera camera, MTLRenderCommandEncoder encoder)
{
    TransformationData transformationData = {node.modelMatrix(), camera.viewMatrix, perspectiveMatrix};
    auto contentsPtr = node.transformationBuffer.contents();
    *(cast(TransformationData*) contentsPtr) = transformationData;

    encoder.setVertexBuffer(node.mesh.vertexBuffer, 0, 0);
    encoder.setFragmentTextures(node.mesh.textures.ptr, NSMakeRange(0,node.mesh.textures.length));
    encoder.setVertexBuffer(node.transformationBuffer, 0, 1);

    MTLPrimitiveType typeTriangle = MTLPrimitiveType.triangle;
    NSUInteger indexBufferOffset = 0;
    encoder.drawIndexedPrimitives(typeTriangle,node.mesh.indexCount, MTLIndexType.uint32, node.mesh.indexBuffer, indexBufferOffset);
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
*/

float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ)
{
    float ys = 1 / std.math.tan(fovyRadians * 0.5f);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);
    float4x4 matrix = float4x4([[xs,0f,0f,0f],
                                [0f,ys,0f,0f],
                                [0f,0f,zs,nearZ*zs],
                                [0f,0f,-1f,0f]]);
    matrix.rowToColumnMajor();
    return matrix;
}
