import MetalKit

class ShaderReloader {
    let device: MTLDevice
    var pipelineState: MTLRenderPipelineState?
    let shaderFilePath: String
    var fileWatcher: DispatchSourceFileSystemObject?
    
    init(device: MTLDevice, shaderFilePath: String) {
        self.device = device
        self.shaderFilePath = shaderFilePath
        setupFileWatcher()
        loadShader()
    }
    
    func setupFileWatcher() {
        let fileDescriptor = open(shaderFilePath, O_EVTONLY)
        fileWatcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: DispatchQueue.global())
        
        fileWatcher?.setEventHandler { [weak self] in
            self?.loadShader()
        }
        fileWatcher?.resume()
    }
    
    func loadShader() {
        do {
            let shaderSource = try String(contentsOfFile: shaderFilePath)
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            let function = library.makeFunction(name: "vertex_main")
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = function
                // Configure other descriptor properties
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            print("Shader reloaded successfully!")
        } catch {
            print("Error reloading shader: \(error)")
        }
    }
}
