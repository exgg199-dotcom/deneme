import Foundation

private typealias ContainerQueryCreateFn = @convention(c) () -> UnsafeMutableRawPointer?
private typealias ContainerQuerySetClassFn = @convention(c) (UnsafeMutableRawPointer?, UInt32) -> Void
private typealias ContainerQuerySetIdentifiersFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void
private typealias ContainerQueryGetSingleResultFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
private typealias ContainerObjectCopyPathFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafePointer<CChar>?
private typealias ContainerObjectCopySandboxTokenFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
private typealias ContainerSandboxExtensionActivateFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
private typealias ContainerQueryFreeFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
private typealias ContainerObjectFreeFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
private typealias ContainerTokenFreeFn = @convention(c) (UnsafeMutableRawPointer?) -> Void

enum ContainerManagerError: Error, LocalizedError {
    case libraryNotLoaded
    case symbolMissing(String)
    case queryFailed
    case pathUnavailable
    case tokenUnavailable
    case extensionActivationFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .libraryNotLoaded: return "libsystem_containermanager.dylib could not be loaded"
        case .symbolMissing(let s): return "Missing symbol: \(s)"
        case .queryFailed: return "Container query returned no result"
        case .pathUnavailable: return "Could not copy container path"
        case .tokenUnavailable: return "Sandbox token unavailable — older API or not running under TrollStore"
        case .extensionActivationFailed(let code): return "Sandbox extension activation failed with code \(code)"
        }
    }
}

final class ContainerManager {
    static let shared = ContainerManager()

    private let libPath = "/usr/lib/system/libsystem_containermanager.dylib"

    func resolveDataContainer(bundleID: String) throws -> URL {
        guard let handle = dlopen(libPath, RTLD_LAZY | RTLD_LOCAL) else {
            throw ContainerManagerError.libraryNotLoaded
        }
        defer { dlclose(handle) }

        guard let queryCreate = dlsym(handle, "container_query_create").flatMap({ unsafeBitCast($0, to: ContainerQueryCreateFn?.self) }) else {
            throw ContainerManagerError.symbolMissing("container_query_create")
        }
        guard let querySetClass = dlsym(handle, "container_query_set_class").flatMap({ unsafeBitCast($0, to: ContainerQuerySetClassFn?.self) }) else {
            throw ContainerManagerError.symbolMissing("container_query_set_class")
        }
        guard let querySetIdentifiers = dlsym(handle, "container_query_set_identifiers").flatMap({ unsafeBitCast($0, to: ContainerQuerySetIdentifiersFn?.self) }) else {
            throw ContainerManagerError.symbolMissing("container_query_set_identifiers")
        }
        guard let queryGetSingle = dlsym(handle, "container_query_get_single_result").flatMap({ unsafeBitCast($0, to: ContainerQueryGetSingleResultFn?.self) }) else {
            throw ContainerManagerError.symbolMissing("container_query_get_single_result")
        }
        guard let objectCopyPath = dlsym(handle, "container_object_copy_path").flatMap({ unsafeBitCast($0, to: ContainerObjectCopyPathFn?.self) }) else {
            throw ContainerManagerError.symbolMissing("container_object_copy_path")
        }
        guard let queryFree = dlsym(handle, "container_query_free").flatMap({ unsafeBitCast($0, to: ContainerQueryFreeFn?.self) }) else {
            throw ContainerManagerError.symbolMissing("container_query_free")
        }
        guard let objectFree = dlsym(handle, "container_object_free").flatMap({ unsafeBitCast($0, to: ContainerObjectFreeFn?.self) }) else {
            throw ContainerManagerError.symbolMissing("container_object_free")
        }

        let query = queryCreate()
        defer { queryFree(query) }

        querySetClass(query, 1)

        bundleID.withCString { ptr in
            querySetIdentifiers(query, ptr)
        }

        guard let containerObject = queryGetSingle(query) else {
            throw ContainerManagerError.queryFailed
        }
        defer { objectFree(containerObject) }

        guard let pathPtr = objectCopyPath(containerObject) else {
            throw ContainerManagerError.pathUnavailable
        }
        let path = String(cString: pathPtr)

        if let copySandboxToken = dlsym(handle, "container_object_copy_sandbox_token").flatMap({ unsafeBitCast($0, to: ContainerObjectCopySandboxTokenFn?.self) }),
           let activateExtension = dlsym(handle, "container_sandbox_extension_activate").flatMap({ unsafeBitCast($0, to: ContainerSandboxExtensionActivateFn?.self) }),
           let tokenFree = dlsym(handle, "container_token_free").flatMap({ unsafeBitCast($0, to: ContainerTokenFreeFn?.self) }) {
            if let token = copySandboxToken(containerObject) {
                defer { tokenFree(token) }
                let result = activateExtension(token)
                if result != 0 {
                    throw ContainerManagerError.extensionActivationFailed(result)
                }
            }
        }

        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func findEngineCommon(root: URL) throws -> URL {
        let candidate = root
            .appendingPathComponent("Documents")
            .appendingPathComponent("Engine")
            .appendingPathComponent("Common")
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw ContainerManagerError.queryFailed
        }
        return candidate
    }
}
