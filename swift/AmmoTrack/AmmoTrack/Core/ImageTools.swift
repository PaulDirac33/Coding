//
//  ImageTools.swift
//  AmmoTrack
//
//  Foto delle armi: ridimensiona e ricomprime in JPEG, legge le anteprime.
//  Usa ImageIO (disponibile su macOS e iOS), senza AppKit né UIKit.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

nonisolated enum ImageTools {

    /// Immagine qualunque (HEIC, PNG, JPEG...) → JPEG con il lato maggiore di al più `maxPixel` pixel,
    /// con l'orientamento EXIF già applicato.
    static func jpegData(from data: Data, maxPixel: Int, quality: Double = 0.85) -> Data? {
        guard let cg = cgImage(from: data, maxPixel: maxPixel) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, cg, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func cgImage(from data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return thumbnail(source, maxPixel: maxPixel)
    }

    static func cgImage(fromFile url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return thumbnail(source, maxPixel: maxPixel)
    }

    private static func thumbnail(_ source: CGImageSource, maxPixel: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
