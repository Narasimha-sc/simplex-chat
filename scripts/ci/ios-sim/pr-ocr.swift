import CoreGraphics
import Foundation
import ImageIO
import Vision

let usage = "usage: pr-ocr <screen height in points> <image>...\nprints <image>\\t<centre y in points>\\t<text> for each text line Vision recognizes\n"

func recognize(_ image: CGImage, _ level: VNRequestTextRecognitionLevel) throws -> [VNRecognizedTextObservation] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = level
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US"]
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return request.results ?? []
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2, let screenHeight = Double(args[0]) else {
    FileHandle.standardError.write(usage.data(using: .utf8)!)
    exit(2)
}

var failed = false
for path in args.dropFirst() {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        print("\(path)\terror\tthe image cannot be read")
        failed = true
        continue
    }
    let observations: [VNRecognizedTextObservation]
    do {
        observations = try recognize(image, .accurate)
    } catch {
        do {
            observations = try recognize(image, .fast)
            print("\(path)\tnote\taccurate recognition failed (\(error)), fast recognition used")
        } catch {
            print("\(path)\terror\t\(error)")
            failed = true
            continue
        }
    }
    for observation in observations {
        guard let text = observation.topCandidates(1).first?.string else { continue }
        let box = observation.boundingBox
        let y = (1 - box.midY) * screenHeight
        print("\(path)\t\(Int(y.rounded()))\t\(text.replacingOccurrences(of: "\t", with: " "))")
    }
}
exit(failed ? 1 : 0)
