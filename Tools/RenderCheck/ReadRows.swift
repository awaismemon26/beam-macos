import Foundation
import Vision
import AppKit
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
let source = NSImage(contentsOf: url)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let ctx = CGContext(data: nil, width: source.width, height: source.height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(gray: 1, alpha: 1)) // the panel is transparent; flatten onto white
ctx.fill(CGRect(x: 0, y: 0, width: source.width, height: source.height))
ctx.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
try VNImageRequestHandler(cgImage: ctx.makeImage()!).perform([request])
let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
let text = lines.joined(separator: " ")
let expected = ["Chrome tab 2", "Chrome tab 6", "Chrome tab 11"]
let strays = ["window 0", "window 1", "window 2", "Outlook", "Claude", "Insiders"]
print("missing:", expected.filter { !text.contains($0) }, "strays:", strays.filter { text.contains($0) })
print(expected.allSatisfy { text.contains($0) } && !strays.contains { text.contains($0) } ? "PASS" : "FAIL")
