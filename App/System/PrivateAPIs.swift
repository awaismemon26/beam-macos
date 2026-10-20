import ApplicationServices
import CoreGraphics
import Darwin

/// Undocumented macOS functions Beam needs to list windows on other Desktops and to focus one exact window.
/// Each is resolved once with `dlsym`; a missing symbol (e.g. after a macOS update) leaves it nil, and
/// Beam then greys the affected windows out instead of guessing.
enum PrivateAPIs {
    typealias AXGetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    typealias AXCreateWithRemoteToken = @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    typealias MainConnectionID = @convention(c) () -> Int32
    typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    typealias CopySpacesForWindows = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    typealias SetFrontProcessWithOptions = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    typealias PostEventRecordTo = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
    typealias GetProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

    private nonisolated(unsafe) static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private nonisolated(unsafe) static let hiServices = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices", RTLD_LAZY)

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer?, as type: T.Type) -> T? {
        let pointer = (handle.flatMap { dlsym($0, name) }) ?? dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) // RTLD_DEFAULT
        guard let pointer else { return nil }
        return unsafeBitCast(pointer, to: type)
    }

    static let axGetWindow = symbol("_AXUIElementGetWindow", in: hiServices, as: AXGetWindow.self)
    static let axCreateWithRemoteToken = symbol("_AXUIElementCreateWithRemoteToken", in: hiServices, as: AXCreateWithRemoteToken.self)
    static let mainConnectionID = symbol("CGSMainConnectionID", in: skyLight, as: MainConnectionID.self)
    static let copyManagedDisplaySpaces = symbol("CGSCopyManagedDisplaySpaces", in: skyLight, as: CopyManagedDisplaySpaces.self)
    static let copySpacesForWindows = symbol("CGSCopySpacesForWindows", in: skyLight, as: CopySpacesForWindows.self)
    static let setFrontProcessWithOptions = symbol("_SLPSSetFrontProcessWithOptions", in: skyLight, as: SetFrontProcessWithOptions.self)
    static let postEventRecordTo = symbol("SLPSPostEventRecordTo", in: skyLight, as: PostEventRecordTo.self)
    static let getProcessForPID = symbol("GetProcessForPID", in: hiServices, as: GetProcessForPID.self)

    /// All symbols needed to bring one exact window to the front are present.
    static var canFocusExactWindows: Bool {
        axGetWindow != nil && setFrontProcessWithOptions != nil && postEventRecordTo != nil && getProcessForPID != nil
    }

    /// The `CGWindowID` behind an Accessibility window element.
    static func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let axGetWindow else { return nil }
        var id: CGWindowID = 0
        return axGetWindow(element, &id) == .success && id != 0 ? id : nil
    }

    /// Names of required symbols that failed to resolve, for logging.
    static var missingSymbols: [String] {
        [
            ("_AXUIElementGetWindow", axGetWindow == nil),
            ("_AXUIElementCreateWithRemoteToken", axCreateWithRemoteToken == nil),
            ("CGSMainConnectionID", mainConnectionID == nil),
            ("CGSCopyManagedDisplaySpaces", copyManagedDisplaySpaces == nil),
            ("CGSCopySpacesForWindows", copySpacesForWindows == nil),
            ("_SLPSSetFrontProcessWithOptions", setFrontProcessWithOptions == nil),
            ("SLPSPostEventRecordTo", postEventRecordTo == nil),
            ("GetProcessForPID", getProcessForPID == nil),
        ].filter(\.1).map(\.0)
    }
}
