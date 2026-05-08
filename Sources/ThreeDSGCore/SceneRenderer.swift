import AppKit
import Foundation
import SceneKit
import simd

public struct DeviceRenderer: Sendable {
    public init() {}

    public func render(_ options: RenderOptions) throws -> RenderResult {
        try validateInputs(options)

        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("3dsg-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
        }

        let manifest = AssetManifest.manifest(for: options.device)
        let assetURL = options.assetsDirectoryURL.appendingPathComponent(manifest.assetFileName)
        let sceneURL = try preparedSceneURL(assetURL: assetURL, manifest: manifest, options: options, temporaryDirectory: temporaryDirectory)
        let sourceScene = try SCNScene(url: sceneURL, options: nil)
        let workingScene = SCNScene()
        workingScene.background.contents = NSColor.clear

        let wrapper = SCNNode()
        wrapper.name = "3dsg-device"
        workingScene.rootNode.addChildNode(wrapper)

        let selection = try selectAndMoveDeviceNodes(from: sourceScene, into: wrapper, manifest: manifest, options: options)
        let screenTexture = try screenTexture(for: selection.screenNode, manifest: manifest, options: options)
        if manifest.usesScreenOverlay {
            try addScreenOverlay(
                to: wrapper,
                screenNode: selection.screenNode,
                texture: screenTexture,
                nativeOrientation: manifest.nativeScreenOrientation
            )
        } else {
            replaceScreenMaterial(on: selection.screenNode, materialName: manifest.screenMaterialName, texture: screenTexture)
        }

        try orient(wrapper: wrapper, screenNode: selection.screenNode, options: options)
        center(wrapper)

        let camera = try addCamera(to: workingScene, framing: wrapper, outputSize: options.outputSize)
        addLights(to: workingScene, camera: camera)

        let png = try renderPNG(scene: workingScene, camera: camera, size: options.outputSize)
        try fileManager.createDirectory(
            at: options.outputPNGURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try png.write(to: options.outputPNGURL, options: .atomic)
        } catch {
            throw ThreeDSGError.imageWriteFailed(options.outputPNGURL)
        }

        return RenderResult(pngURL: options.outputPNGURL)
    }

    private func validateInputs(_ options: RenderOptions) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: options.screenURL.path) else {
            throw ThreeDSGError.missingFile(options.screenURL)
        }
        guard options.outputPNGURL.pathExtension.lowercased() == "png" else {
            throw ThreeDSGError.invalidValue("--output must point to a .png file")
        }
        let manifest = AssetManifest.manifest(for: options.device)
        let assetURL = options.assetsDirectoryURL.appendingPathComponent(manifest.assetFileName)
        guard fileManager.fileExists(atPath: assetURL.path) else {
            throw ThreeDSGError.assetNotFound(manifest.assetFileName, assetURL)
        }
    }

    private func preparedSceneURL(
        assetURL: URL,
        manifest: AssetManifest,
        options: RenderOptions,
        temporaryDirectory: URL
    ) throws -> URL {
        guard options.device.isIPhone else {
            return assetURL
        }

        let overlayURL = temporaryDirectory.appendingPathComponent("iphone-color.usda")
        let overlay = """
        #usda 1.0
        (
            subLayers = [@\(assetURL.path)@]
        )

        over "\(manifest.rootNodeName)" (
            variants = {
                string Color = "\(options.color.usdVariantName)"
            }
        )
        {
        }
        """
        try overlay.write(to: overlayURL, atomically: true, encoding: .utf8)
        return overlayURL
    }

    private func selectAndMoveDeviceNodes(
        from scene: SCNScene,
        into wrapper: SCNNode,
        manifest: AssetManifest,
        options: RenderOptions
    ) throws -> DeviceSelection {
        let root = scene.rootNode
        let subjectNodeName: String

        switch options.device {
        case .iPhone17Pro:
            subjectNodeName = manifest.iPhoneProNodeName
        case .iPhone17ProMax:
            subjectNodeName = manifest.iPhoneProMaxNodeName
        case .iPad:
            subjectNodeName = manifest.iPadNodeName
        }

        guard let subject = root.childNode(withName: subjectNodeName, recursively: true) else {
            throw ThreeDSGError.sceneNodeNotFound(subjectNodeName)
        }

        let group = SCNNode()
        group.name = "3dsg-selected-device"
        wrapper.addChildNode(group)
        movePreservingWorld(subject, into: group)

        // Keyboard and Pencil support is WIP; the CLI does not expose these options yet.
        if options.device == .iPad {
            if options.showKeyboard, let keyboard = root.childNode(withName: manifest.iPadKeyboardNodeName, recursively: true) {
                movePreservingWorld(keyboard, into: group)
            }
            if options.showPencil, let pencil = root.childNode(withName: manifest.iPadPencilNodeName, recursively: true) {
                movePreservingWorld(pencil, into: group)
            }
        }

        let screenNode: SCNNode
        if let explicitName = manifest.screenNodeName,
           let node = subject.childNode(withName: explicitName, recursively: true) {
            screenNode = node
        } else if let node = firstGeometryNode(namedMaterial: manifest.screenMaterialName, under: subject) {
            screenNode = node
        } else {
            throw ThreeDSGError.sceneNodeNotFound(manifest.screenMaterialName)
        }

        return DeviceSelection(subjectNode: group, screenNode: screenNode)
    }

    private func movePreservingWorld(_ node: SCNNode, into parent: SCNNode) {
        let transform = node.worldTransform
        node.removeFromParentNode()
        node.transform = transform
        parent.addChildNode(node)
    }

    private func firstGeometryNode(namedMaterial materialName: String, under node: SCNNode) -> SCNNode? {
        if let geometry = node.geometry,
           geometry.materials.contains(where: { $0.name == materialName }) {
            return node
        }
        for child in node.childNodes {
            if let match = firstGeometryNode(namedMaterial: materialName, under: child) {
                return match
            }
        }
        return nil
    }

    private func screenTexture(for screenNode: SCNNode, manifest: AssetManifest, options: RenderOptions) throws -> NSImage {
        let textureSize = try screenTextureSize(for: screenNode, manifest: manifest)
        let rotate = options.orientation.rotationQuarterTurns(toNativeOrientation: manifest.nativeScreenOrientation)
        let fit = effectiveScreenFit(for: manifest, options: options)
        return try ImageFitter.fittedImage(
            from: options.screenURL,
            fit: fit,
            targetSize: textureSize,
            rotateQuarterTurns: rotate
        )
    }

    private func effectiveScreenFit(for manifest: AssetManifest, options: RenderOptions) -> ScreenFit {
        if manifest.usesScreenOverlay,
           !options.screenFitWasSpecified,
           options.screenFit == .cover {
            return .stretch
        }
        return options.screenFit
    }

    private func replaceScreenMaterial(on node: SCNNode, materialName: String, texture: NSImage) {
        guard let geometry = node.geometry else {
            return
        }

        var replaced = false
        geometry.materials = geometry.materials.map { existing in
            if existing.name == materialName {
                replaced = true
                return screenReplacementMaterial(copying: existing, texture: texture)
            }
            return existing
        }
        if !replaced {
            let replacement = SCNMaterial()
            replacement.name = materialName
            configureScreenMaterial(replacement, texture: texture)
            geometry.materials = [replacement]
        }
    }

    private func screenReplacementMaterial(copying existing: SCNMaterial, texture: NSImage) -> SCNMaterial {
        let replacement = existing.copy() as? SCNMaterial ?? SCNMaterial()
        replacement.name = existing.name

        let diffuseTransform = existing.diffuse.contentsTransform
        let diffuseMappingChannel = existing.diffuse.mappingChannel
        configureScreenMaterial(replacement, texture: texture)
        replacement.diffuse.contentsTransform = diffuseTransform
        replacement.diffuse.mappingChannel = diffuseMappingChannel
        return replacement
    }

    private func configureScreenMaterial(_ material: SCNMaterial, texture: NSImage) {
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.diffuse.contents = texture
        material.diffuse.intensity = 1
        material.emission.contents = NSColor.black
        material.emission.intensity = 0
        material.diffuse.magnificationFilter = .linear
        material.diffuse.minificationFilter = .linear
        material.diffuse.mipFilter = .linear
    }

    private func addScreenOverlay(
        to parent: SCNNode,
        screenNode: SCNNode,
        texture: NSImage,
        nativeOrientation: DeviceOrientation
    ) throws {
        let metrics = try screenPlaneMetrics(for: screenNode)
        let xAxis: SIMD3<Float>
        let yAxis: SIMD3<Float>
        let width: Float
        let height: Float

        switch nativeOrientation {
        case .landscape:
            xAxis = axis(metrics.majorAxis, alignedWith: SIMD3<Float>(1, 0, 0))
            yAxis = axis(metrics.minorAxis, alignedWith: SIMD3<Float>(0, 1, 0))
            width = metrics.majorLength
            height = metrics.minorLength
        case .portrait:
            xAxis = axis(metrics.minorAxis, alignedWith: SIMD3<Float>(1, 0, 0))
            yAxis = axis(metrics.majorAxis, alignedWith: SIMD3<Float>(0, 1, 0))
            width = metrics.minorLength
            height = metrics.majorLength
        }

        var normal = metrics.normal
        if simd_dot(normal, SIMD3<Float>(0, 0, 1)) < 0 {
            normal = -normal
        }

        let material = SCNMaterial()
        material.name = "3dsg-screen-overlay-material"
        configureScreenMaterial(material, texture: texture)
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = false

        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        plane.cornerRadius = CGFloat(min(width, height) * 0.035)
        plane.cornerSegmentCount = 16
        plane.materials = [material]

        let overlay = SCNNode(geometry: plane)
        overlay.name = "3dsg-screen-overlay"
        overlay.simdTransform = simd_float4x4(columns: (
            SIMD4<Float>(xAxis.x, xAxis.y, xAxis.z, 0),
            SIMD4<Float>(yAxis.x, yAxis.y, yAxis.z, 0),
            SIMD4<Float>(normal.x, normal.y, normal.z, 0),
            SIMD4<Float>(
                metrics.center.x + normal.x * 0.02,
                metrics.center.y + normal.y * 0.02,
                metrics.center.z + normal.z * 0.02,
                1
            )
        ))
        parent.addChildNode(overlay)
    }

    private func orient(wrapper: SCNNode, screenNode: SCNNode, options: RenderOptions) throws {
        var normal = try screenNormal(screenNode)
        if simd_dot(normal, SIMD3<Float>(0, 0, 1)) < 0 {
            normal = -normal
        }
        let frontFacing = quaternion(from: normal, to: SIMD3<Float>(0, 0, 1))
        wrapper.simdOrientation = frontFacing * wrapper.simdOrientation

        let majorAxis = try projectedMajorAxis(for: screenNode)
        let targetAxis = options.orientation == .landscape
            ? SIMD2<Float>(1, 0)
            : SIMD2<Float>(0, 1)
        let adjustedMajor = simd_dot(majorAxis, targetAxis) < 0 ? -majorAxis : majorAxis
        let angle = atan2(
            adjustedMajor.x * targetAxis.y - adjustedMajor.y * targetAxis.x,
            simd_dot(adjustedMajor, targetAxis)
        )
        wrapper.simdOrientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 0, 1)) * wrapper.simdOrientation

        let assetNormalizationRotation = rotationQuaternion(options.device.assetNormalizationRotation)
        wrapper.simdOrientation = assetNormalizationRotation * wrapper.simdOrientation

        let userRotation = rotationQuaternion(options.rotation)
        wrapper.simdOrientation = userRotation * wrapper.simdOrientation
    }

    private func center(_ wrapper: SCNNode) {
        guard let bounds = worldBounds(of: wrapper), bounds.isValid else {
            return
        }
        wrapper.simdPosition -= bounds.center
    }

    private func addCamera(to scene: SCNScene, framing node: SCNNode, outputSize: Dimensions) throws -> SCNNode {
        guard let bounds = worldBounds(of: node), bounds.isValid else {
            throw ThreeDSGError.renderFailed("could not compute scene bounds")
        }

        let camera = SCNCamera()
        camera.fieldOfView = 32
        camera.wantsHDR = true
        camera.zNear = 0.01
        camera.zFar = 10_000

        let aspect = Float(outputSize.width) / Float(outputSize.height)
        let width = max(bounds.size.x, 0.1)
        let height = max(bounds.size.y, 0.1)
        let depth = max(bounds.size.z, 0.1)
        let requiredHeight = max(height, width / aspect)
        let fov = Float(camera.fieldOfView) * .pi / 180
        let padding: Float = 1.15
        let distance = (requiredHeight * padding / 2) / tan(fov / 2)

        let cameraNode = SCNNode()
        cameraNode.name = "RenderCamera"
        cameraNode.camera = camera
        cameraNode.simdPosition = SIMD3<Float>(0, 0, bounds.max.z + depth + distance)
        scene.rootNode.addChildNode(cameraNode)
        return cameraNode
    }

    private func addLights(to scene: SCNScene, camera: SCNNode) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 550
        let ambientNode = SCNNode()
        ambientNode.name = "RenderAmbientLight"
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 900
        let keyNode = SCNNode()
        keyNode.name = "RenderKeyLight"
        keyNode.light = key
        keyNode.simdPosition = camera.simdPosition
        keyNode.eulerAngles = SCNVector3(-Float.pi / 5, Float.pi / 7, 0)
        scene.rootNode.addChildNode(keyNode)
    }

    private func renderPNG(scene: SCNScene, camera: SCNNode, size: Dimensions) throws -> Data {
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = true

        let image = renderer.snapshot(
            atTime: 0,
            with: CGSize(width: size.width, height: size.height),
            antialiasingMode: .multisampling4X
        )
        return try ImageFitter.pngData(from: image)
    }

    private func screenNormal(_ node: SCNNode) throws -> SIMD3<Float> {
        if let geometry = node.geometry,
           let normalSource = geometry.sources(for: .normal).first {
            let normals = vectors(from: normalSource)
            let sum = normals.reduce(SIMD3<Float>(repeating: 0), +)
            if simd_length(sum) > 0.0001 {
                let local = simd_normalize(sum)
                let world = node.convertVector(SCNVector3(local.x, local.y, local.z), to: nil)
                let vector = SIMD3<Float>(Float(world.x), Float(world.y), Float(world.z))
                if simd_length(vector) > 0.0001 {
                    return simd_normalize(vector)
                }
            }
        }

        guard let geometry = node.geometry,
              let vertexSource = geometry.sources(for: .vertex).first else {
            throw ThreeDSGError.renderFailed("screen node has no geometry")
        }
        let localBounds = geometryBoundingBox(vectors(from: vertexSource))
        let sizes = localBounds.size
        let axis: SIMD3<Float>
        if sizes.x <= sizes.y && sizes.x <= sizes.z {
            axis = SIMD3<Float>(1, 0, 0)
        } else if sizes.y <= sizes.z {
            axis = SIMD3<Float>(0, 1, 0)
        } else {
            axis = SIMD3<Float>(0, 0, 1)
        }
        let world = node.convertVector(SCNVector3(axis.x, axis.y, axis.z), to: nil)
        return simd_normalize(SIMD3<Float>(Float(world.x), Float(world.y), Float(world.z)))
    }

    private func projectedMajorAxis(for node: SCNNode) throws -> SIMD2<Float> {
        let metrics = try screenPlaneMetrics(for: node)
        let axis = SIMD2<Float>(metrics.majorAxis.x, metrics.majorAxis.y)
        if simd_length(axis) > 0.0001 {
            return simd_normalize(axis)
        }
        return SIMD2<Float>(0, 1)
    }

    private func screenTextureSize(for node: SCNNode, manifest: AssetManifest) throws -> PixelSize {
        let baseSize = try manifest.textureSize
        let displayAspect = try screenDisplayAspect(for: node, nativeOrientation: manifest.nativeScreenOrientation)
        let baseAspect = Float(baseSize.width) / Float(baseSize.height)

        guard displayAspect.isFinite, displayAspect > 0 else {
            return baseSize
        }

        let relativeDelta = abs(displayAspect - baseAspect) / baseAspect
        guard relativeDelta > 0.01 else {
            return baseSize
        }

        switch manifest.nativeScreenOrientation {
        case .portrait:
            let width = max(1, Int((Float(baseSize.height) * displayAspect).rounded()))
            return try PixelSize(width: width, height: baseSize.height)
        case .landscape:
            let height = max(1, Int((Float(baseSize.width) / displayAspect).rounded()))
            return try PixelSize(width: baseSize.width, height: height)
        }
    }

    private func screenDisplayAspect(for node: SCNNode, nativeOrientation: DeviceOrientation) throws -> Float {
        let metrics = try screenPlaneMetrics(for: node)

        switch nativeOrientation {
        case .portrait:
            return metrics.minorLength / metrics.majorLength
        case .landscape:
            return metrics.majorLength / metrics.minorLength
        }
    }

    private func screenPlaneMetrics(for node: SCNNode) throws -> ScreenPlaneMetrics {
        let points = try worldVertices(of: node)
        guard points.count >= 3 else {
            throw ThreeDSGError.renderFailed("screen node has too few vertices")
        }

        var normal = try screenNormal(node)
        if simd_length(normal) <= 0.0001 {
            throw ThreeDSGError.renderFailed("could not measure screen normal")
        }
        normal = simd_normalize(normal)

        let reference = abs(normal.y) < 0.9
            ? SIMD3<Float>(0, 1, 0)
            : SIMD3<Float>(1, 0, 0)
        let basisU = simd_normalize(simd_cross(reference, normal))
        let basisV = simd_normalize(simd_cross(normal, basisU))

        let projected = points.map { point in
            SIMD2<Float>(
                simd_dot(point, basisU),
                simd_dot(point, basisV)
            )
        }
        var axes = principalSurfaceAxes(for: projected)
        var majorLength = projectedLength(of: projected, along: axes.major)
        var minorLength = projectedLength(of: projected, along: axes.minor)
        if minorLength > majorLength {
            swap(&majorLength, &minorLength)
            axes = (major: axes.minor, minor: axes.major)
        }

        guard majorLength > 0.0001, minorLength > 0.0001 else {
            throw ThreeDSGError.renderFailed("could not measure screen aspect")
        }

        let majorAxis = simd_normalize(basisU * axes.major.x + basisV * axes.major.y)
        let minorAxis = simd_normalize(basisU * axes.minor.x + basisV * axes.minor.y)
        let midMajor = projectedMidpoint(of: projected, along: axes.major)
        let midMinor = projectedMidpoint(of: projected, along: axes.minor)
        let normalCoordinate = points.reduce(Float(0)) { $0 + simd_dot($1, normal) } / Float(points.count)
        let center = majorAxis * midMajor + minorAxis * midMinor + normal * normalCoordinate

        return ScreenPlaneMetrics(
            center: center,
            normal: normal,
            majorAxis: majorAxis,
            minorAxis: minorAxis,
            majorLength: majorLength,
            minorLength: minorLength
        )
    }

    private func principalSurfaceAxes(for points: [SIMD2<Float>]) -> (major: SIMD2<Float>, minor: SIMD2<Float>) {
        let mean = points.reduce(SIMD2<Float>(repeating: 0), +) / Float(points.count)
        var xx: Float = 0
        var xy: Float = 0
        var yy: Float = 0
        for point in points {
            let delta = point - mean
            xx += delta.x * delta.x
            xy += delta.x * delta.y
            yy += delta.y * delta.y
        }
        let angle = 0.5 * atan2(2 * xy, xx - yy)
        let axis = SIMD2<Float>(cos(angle), sin(angle))
        let major = simd_length(axis) > 0.0001 ? simd_normalize(axis) : SIMD2<Float>(1, 0)
        let minor = SIMD2<Float>(-major.y, major.x)
        return (major, minor)
    }

    private func projectedLength(of points: [SIMD2<Float>], along axis: SIMD2<Float>) -> Float {
        var minimum = Float.greatestFiniteMagnitude
        var maximum = -Float.greatestFiniteMagnitude
        for point in points {
            let projected = simd_dot(point, axis)
            minimum = min(minimum, projected)
            maximum = max(maximum, projected)
        }
        return maximum - minimum
    }

    private func projectedMidpoint(of points: [SIMD2<Float>], along axis: SIMD2<Float>) -> Float {
        var minimum = Float.greatestFiniteMagnitude
        var maximum = -Float.greatestFiniteMagnitude
        for point in points {
            let projected = simd_dot(point, axis)
            minimum = min(minimum, projected)
            maximum = max(maximum, projected)
        }
        return (minimum + maximum) / 2
    }

    private func axis(_ source: SIMD3<Float>, alignedWith target: SIMD3<Float>) -> SIMD3<Float> {
        let axis = simd_length(source) > 0.0001 ? simd_normalize(source) : target
        return simd_dot(axis, target) < 0 ? -axis : axis
    }

    private func worldVertices(of node: SCNNode) throws -> [SIMD3<Float>] {
        guard let geometry = node.geometry,
              let vertexSource = geometry.sources(for: .vertex).first else {
            throw ThreeDSGError.renderFailed("screen node has no vertices")
        }
        return vectors(from: vertexSource).map { vertex in
            let point = node.convertPosition(SCNVector3(vertex.x, vertex.y, vertex.z), to: nil)
            return SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z))
        }
    }

    private func vectors(from source: SCNGeometrySource) -> [SIMD3<Float>] {
        guard source.componentsPerVector >= 3 else {
            return []
        }

        return source.data.withUnsafeBytes { rawBuffer -> [SIMD3<Float>] in
            var values: [SIMD3<Float>] = []
            values.reserveCapacity(source.vectorCount)
            for index in 0..<source.vectorCount {
                let base = source.dataOffset + index * source.dataStride
                let x = component(in: rawBuffer, source: source, offset: base)
                let y = component(in: rawBuffer, source: source, offset: base + source.bytesPerComponent)
                let z = component(in: rawBuffer, source: source, offset: base + source.bytesPerComponent * 2)
                values.append(SIMD3<Float>(x, y, z))
            }
            return values
        }
    }

    private func component(in rawBuffer: UnsafeRawBufferPointer, source: SCNGeometrySource, offset: Int) -> Float {
        if source.usesFloatComponents {
            if source.bytesPerComponent == 8 {
                return Float(rawBuffer.loadUnaligned(fromByteOffset: offset, as: Double.self))
            }
            return rawBuffer.loadUnaligned(fromByteOffset: offset, as: Float.self)
        }

        if source.bytesPerComponent == 2 {
            let value = rawBuffer.loadUnaligned(fromByteOffset: offset, as: Int16.self)
            return Float(value)
        }
        let value = rawBuffer.loadUnaligned(fromByteOffset: offset, as: Int32.self)
        return Float(value)
    }

    private func worldBounds(of node: SCNNode) -> Bounds? {
        var bounds = Bounds.empty
        includeBounds(for: node, into: &bounds)
        return bounds.isValid ? bounds : nil
    }

    private func includeBounds(for node: SCNNode, into bounds: inout Bounds) {
        if node.geometry != nil {
            let box = node.boundingBox
            let corners = [
                SCNVector3(box.min.x, box.min.y, box.min.z),
                SCNVector3(box.min.x, box.min.y, box.max.z),
                SCNVector3(box.min.x, box.max.y, box.min.z),
                SCNVector3(box.min.x, box.max.y, box.max.z),
                SCNVector3(box.max.x, box.min.y, box.min.z),
                SCNVector3(box.max.x, box.min.y, box.max.z),
                SCNVector3(box.max.x, box.max.y, box.min.z),
                SCNVector3(box.max.x, box.max.y, box.max.z)
            ]
            for corner in corners {
                let point = node.convertPosition(corner, to: nil)
                bounds.include(SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z)))
            }
        }
        for child in node.childNodes {
            includeBounds(for: child, into: &bounds)
        }
    }

    private func geometryBoundingBox(_ points: [SIMD3<Float>]) -> Bounds {
        var bounds = Bounds.empty
        for point in points {
            bounds.include(point)
        }
        return bounds
    }

    private func quaternion(from source: SIMD3<Float>, to target: SIMD3<Float>) -> simd_quatf {
        let from = simd_normalize(source)
        let to = simd_normalize(target)
        let dot = max(-1, min(1, simd_dot(from, to)))
        if dot > 0.9999 {
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
        }
        if dot < -0.9999 {
            let fallback = abs(from.x) < 0.9 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
            let axis = simd_normalize(simd_cross(from, fallback))
            return simd_quatf(angle: .pi, axis: axis)
        }
        let axis = simd_normalize(simd_cross(from, to))
        return simd_quatf(angle: acos(dot), axis: axis)
    }

    private func rotationQuaternion(_ rotation: Rotation) -> simd_quatf {
        let x = Float(rotation.x * .pi / 180)
        let y = Float(rotation.y * .pi / 180)
        let z = Float(rotation.z * .pi / 180)
        let qx = simd_quatf(angle: x, axis: SIMD3<Float>(1, 0, 0))
        let qy = simd_quatf(angle: y, axis: SIMD3<Float>(0, 1, 0))
        let qz = simd_quatf(angle: z, axis: SIMD3<Float>(0, 0, 1))
        return qz * qy * qx
    }
}

private struct DeviceSelection {
    var subjectNode: SCNNode
    var screenNode: SCNNode
}

private struct ScreenPlaneMetrics {
    var center: SIMD3<Float>
    var normal: SIMD3<Float>
    var majorAxis: SIMD3<Float>
    var minorAxis: SIMD3<Float>
    var majorLength: Float
    var minorLength: Float
}

private struct AssetManifest {
    var assetFileName: String
    var rootNodeName: String
    var nativeScreenOrientation: DeviceOrientation
    var textureWidth: Int
    var textureHeight: Int
    var screenNodeName: String?
    var screenMaterialName: String
    var usesScreenOverlay: Bool

    let iPhoneProNodeName = "VEyUSflTHtkVqsc"
    let iPhoneProMaxNodeName = "fXODuXAELCboksi"
    let iPadNodeName = "zRrSLDpdYmKeRJQ"
    let iPadKeyboardNodeName = "PoBqSMmyhhcJsBX"
    let iPadPencilNodeName = "UlaXKoqepypaGMQ"

    var textureSize: PixelSize {
        get throws {
            try PixelSize(width: textureWidth, height: textureHeight)
        }
    }

    static func manifest(for device: Device) -> AssetManifest {
        switch device {
        case .iPhone17Pro, .iPhone17ProMax:
            AssetManifest(
                assetFileName: "iphone17pro-cosmicorange-ar-202509_GEO_US-3A37738F56E29114.usdz",
                rootNodeName: "JjEbhuORCZuXqjs",
                nativeScreenOrientation: .portrait,
                textureWidth: 1024,
                textureHeight: 2048,
                screenNodeName: "TlsdYMuhscHijgo",
                screenMaterialName: "vGYRiudxdzSQpSA",
                usesScreenOverlay: false
            )
        case .iPad:
            AssetManifest(
                assetFileName: "ipad-pro-m5-13in-spaceblack-mgk-black-pencil-pro-ios26-33F49B60F49CE47A.usdz",
                rootNodeName: "COLLuSkZTNlzRUw",
                nativeScreenOrientation: .landscape,
                textureWidth: 2732,
                textureHeight: 2048,
                screenNodeName: nil,
                screenMaterialName: "OXrDZyQkqgcIHDh",
                usesScreenOverlay: true
            )
        }
    }
}

private struct Bounds {
    var min: SIMD3<Float>
    var max: SIMD3<Float>

    static let empty = Bounds(
        min: SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude),
        max: SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
    )

    var isValid: Bool {
        min.x <= max.x && min.y <= max.y && min.z <= max.z
    }

    var center: SIMD3<Float> {
        (min + max) / 2
    }

    var size: SIMD3<Float> {
        max - min
    }

    mutating func include(_ point: SIMD3<Float>) {
        min = simd_min(min, point)
        max = simd_max(max, point)
    }
}
