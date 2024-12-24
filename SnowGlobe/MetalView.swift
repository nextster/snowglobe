import MetalKit

public protocol Interpolatable {
    static func lerp(_ l: Self, _ r: Self, _ k: Float) -> Self
}

extension Float: Interpolatable {
    public static func lerp(_ l: Float, _ r: Float, _ k: Float) -> Float {
        l + k * (r - l)
    }
}

class MetalView: MTKView, MTKViewDelegate {
    var uniforms = Uniforms()
    var commandQueue: MTLCommandQueue

    var backgroundPipelineState: MTLComputePipelineState!
    var spherePipelineState: MTLComputePipelineState!
    var backTexture: MTLTexture!

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(frame frameRect: CGRect, device: (any MTLDevice)?) {
        self.commandQueue = device!.makeCommandQueue()!
        super.init(frame: frameRect, device: device)
        self.backgroundPipelineState = self.makePipelineState("background")
        self.spherePipelineState = self.makePipelineState("glassSphere")

        self.delegate = self
        self.framebufferOnly = false

//        Task {
//            try await Task.sleep(for: .seconds(1))
//            startAnimation()
//        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.aspect = Float(size.width / size.height)
        self.backTexture = self.makeTexture(size: size)
    }

// MARK: MetalView.swift
    var currentShapeIsCircle: Bool = true
    var animationStartTime: Float = -Float.greatestFiniteMagnitude // initial low value
    var animationDuration: Float = 1 // 1 second

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        swapShape()
    }

    func startAnimation() {
        animationStartTime = uniforms.time
    }

    func swapShape() {
        currentShapeIsCircle.toggle()
        startAnimation()
    }

    func draw(in view: MTKView) {
        uniforms.time += 1 / Float(preferredFramesPerSecond)

        let buf = commandQueue.makeCommandBuffer()!
        let drawable = view.currentDrawable!

        let size = MTLSize(width: drawable.texture.width, height: drawable.texture.height, depth: 1)
        let width = spherePipelineState.threadExecutionWidth
        let height = spherePipelineState.maxTotalThreadsPerThreadgroup / width
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

//        let bgCommand = buf.makeComputeCommandEncoder()!
//        bgCommand.setComputePipelineState(backgroundPipelineState)
//        bgCommand.setBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), index: 0)
//        bgCommand.setTexture(drawable.texture, index: 0)
//        runDispatch(bgCommand)
//        bgCommand.endEncoding()

        let sphereCommand = buf.makeComputeCommandEncoder()!
        sphereCommand.setComputePipelineState(spherePipelineState)
        sphereCommand.setBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), index: 0)
        sphereCommand.setTexture(drawable.texture, index: 0)
//        sphereCommand.setTexture(backTexture, index: 1)
        runDispatch(sphereCommand)
        sphereCommand.endEncoding()

        buf.present(drawable)
        buf.commit()
    }

    func makePipelineState(_ functionName: String) -> MTLComputePipelineState {
        let library = device!.makeDefaultLibrary()!
        let function = library.makeFunction(name: functionName)!
        return try! device!.makeComputePipelineState(function: function)
    }

    func makeTexture(size: CGSize) -> MTLTexture {
        let desc = MTLTextureDescriptor()
        desc.width = Int(size.width)
        desc.height = Int(size.height)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .private
        desc.pixelFormat = self.colorPixelFormat

        return device!.makeTexture(descriptor: desc)!
    }
}
