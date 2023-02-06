//
//  NSImage+.swift
//  
//
//  Created by Alex Nagy on 03.01.2023.
//

#if canImport(Cocoa)
import Cocoa
#endif

#if os(macOS)
public extension NSImage {
    func jpegData() -> Data? {
        let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [:]) else {
            return nil
        }
        return jpegData
    }
}
#endif
