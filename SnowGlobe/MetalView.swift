import MetalKit

class MetalView: MTKView, MTKViewDelegate {
    var uniforms = Uniforms()
    var commandQueue: MTLCommandQueue

    var backgroundPipelineState: MTLComputePipelineState!

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(frame frameRect: CGRect, device: (any MTLDevice)?) {
        self.commandQueue = device!.makeCommandQueue()!
        super.init(frame: frameRect, device: device)
        self.backgroundPipelineState = self.makePipelineState("background")

        self.delegate = self
        self.framebufferOnly = false
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.aspect = Float(size.width / size.height)
        uniforms.color = simd_float3(0, 1, 0)
    }

    func draw(in view: MTKView) {
        uniforms.time += 1 / Float(preferredFramesPerSecond)

        let buf = commandQueue.makeCommandBuffer()!
        let drawable = view.currentDrawable!

        let size = MTLSize(width: drawable.texture.width, height: drawable.texture.height, depth: 1)
        let width = backgroundPipelineState.threadExecutionWidth
        let height = backgroundPipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        
        let runDispatch: (MTLComputeCommandEncoder) -> Void = { [self] command in
            if device!.supportsFamily(.apple4) {
                    // modern ios devices
                command.dispatchThreads(size, threadsPerThreadgroup: threadsPerGroup)
            } else {
                    // old ios devices and simulators
                let threadGroupCount = MTLSize(
                    width: (drawable.texture.width + width - 1) / width,
                    height: (drawable.texture.height + height - 1) / height,
                    depth: 1)
                command.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadsPerGroup)
            }
        }

        let bgCommand = buf.makeComputeCommandEncoder()!
        bgCommand.setComputePipelineState(backgroundPipelineState)
        bgCommand.setBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), index: 0)
        bgCommand.setTexture(drawable.texture, index: 0)
        runDispatch(bgCommand)
        bgCommand.endEncoding()

        buf.present(drawable)
        buf.commit()
    }

    func makePipelineState(_ functionName: String) -> MTLComputePipelineState {
        let library = device!.makeDefaultLibrary()!
        let function = library.makeFunction(name: functionName)!
        return try! device!.makeComputePipelineState(function: function)
    }
}
