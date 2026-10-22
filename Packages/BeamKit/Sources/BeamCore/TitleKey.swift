/// Derives the stable part of a window title — the document or folder name — that identifies a window
/// across restarts. Only for apps whose titles name a document; everything else has no stable key.
public enum TitleKey {
    private static let vsCode: Set<String> = ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"]
    private static let office: Set<String> = ["com.microsoft.Excel", "com.microsoft.Powerpoint", "com.microsoft.Word"]

    /// `nil` means no stable key (browsers, unknown apps, empty titles): the window is then added for this session only.
    public static func extract(appBundleID: String?, title: String) -> String? {
        guard let appBundleID else { return nil }
        let key: String
        if vsCode.contains(appBundleID) {
            // "file — folder", "folder", "folder (Workspace)", with a "● " marker while a file has unsaved changes.
            var last = part(title, last: true)
            if last.hasSuffix(" (Workspace)") { last.removeLast(" (Workspace)".count) }
            key = last
        } else if office.contains(appBundleID) {
            key = withoutExtension(title)
        } else if appBundleID == "com.apple.Preview" {
            // "cv.pdf – Page 1 of 3"
            key = withoutExtension(part(title, separator: " – "))
        } else if appBundleID == "com.apple.dt.Xcode" {
            // "Project — File.swift"
            key = part(title)
        } else if appBundleID == "com.apple.TextEdit" {
            // "notes.txt — Edited"
            key = withoutExtension(part(title))
        } else if appBundleID == "com.apple.finder" {
            key = title
        } else {
            return nil
        }
        // Titles rarely need trimming; only pay for it when an end is whitespace.
        guard key.utf8.first.map(isSpace) == true || key.utf8.last.map(isSpace) == true else { return key.isEmpty ? nil : key }
        var trimmed = key[...]
        while trimmed.first?.isWhitespace == true { trimmed.removeFirst() }
        while trimmed.last?.isWhitespace == true { trimmed.removeLast() }
        return trimmed.isEmpty ? nil : String(trimmed)
    }

    /// The first (or last) part of a title split on an em dash (or `separator`). Scans UTF-8 bytes: this runs for
    /// every window on each panel open, and Character-by-Character splitting is several times slower.
    private static func part(_ title: String, separator: String = " — ", last: Bool = false) -> String {
        var title = title, separator = separator
        return title.withUTF8 { bytes in
            separator.withUTF8 { sep in
                var start = 0, end = bytes.count, i = 0
                while i + sep.count <= bytes.count {
                    var j = 0
                    while j < sep.count, bytes[i + j] == sep[j] { j += 1 }
                    if j == sep.count {
                        if last { start = i + sep.count } else { end = i; break }
                        i += sep.count
                    } else {
                        i += 1
                    }
                }
                return String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<end]), as: UTF8.self)
            }
        }
    }

    private static func isSpace(_ byte: UInt8) -> Bool { byte == 0x20 || (0x09...0x0D).contains(byte) || byte >= 0x80 }

    /// "Budget.xlsx" → "Budget". Only short alphanumeric extensions count ("v1.2 plan" keeps its dot).
    private static func withoutExtension(_ name: String) -> String {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return name }
        let ext = name[name.index(after: dot)...]
        guard (1...5).contains(ext.count), ext.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return name }
        return String(name[..<dot])
    }
}
