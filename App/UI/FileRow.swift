import AppKit
import BeamCore
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

/// One file in file search: icon or thumbnail, name, and the folder it is in.
struct FileRow: View {
    let file: FileResult
    let icon: NSImage?
    let isSelected: Bool

    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: Theme.iconSize + 4, height: Theme.iconSize + 4)

            Text(file.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .layoutPriority(1)
            Spacer(minLength: 12)
            Text(FilePaths.display(FilePaths.folder(of: file.path), home: Self.home))
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.head)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
        }
        .font(.system(size: 14))
        .padding(.horizontal, 10)
        .frame(height: Theme.rowHeight + 4)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.rowCornerRadius, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}

/// File icons by path, loaded off the main thread: the Finder icon first, then a thumbnail for images and PDFs.
/// Rows read `images`; nothing here runs while a row renders, so a keystroke never waits for the disk.
@MainActor @Observable
final class FileIcons {
    private(set) var images: [String: NSImage] = [:]
    @ObservationIgnored private var requested: Set<String> = []
    /// Bounds the cache; past it, everything is dropped and reloaded on demand.
    private static let capacity = 400
    private static let thumbnailSize = CGSize(width: 48, height: 48)

    func load(_ paths: [String]) {
        var missing = paths.filter { !requested.contains($0) }
        guard !missing.isEmpty else { return }
        if requested.count + missing.count > Self.capacity {
            requested.removeAll()
            images.removeAll()
            missing = paths
        }
        for path in missing {
            requested.insert(path)
            let size = Self.thumbnailSize
            let wantsThumbnail = UTType(filenameExtension: (path as NSString).pathExtension)
                .map { $0.conforms(to: .image) || $0.conforms(to: .pdf) } ?? false
            Task.detached(priority: .userInitiated) { [weak self] in
                let icon = NSWorkspace.shared.icon(forFile: path)
                await self?.set(icon, for: path)
                guard wantsThumbnail else { return }
                let request = QLThumbnailGenerator.Request(
                    fileAt: URL(fileURLWithPath: path), size: size, scale: 2, representationTypes: .thumbnail)
                if let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                    await self?.set(thumbnail.nsImage, for: path)
                }
            }
        }
    }

    private func set(_ image: NSImage, for path: String) {
        guard requested.contains(path) else { return } // dropped meanwhile
        images[path] = image
    }
}
