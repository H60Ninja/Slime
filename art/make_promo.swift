// Adds the app name to the feature graphic for Amazon's 1024x500 promotional image.
//   swift art/make_promo.swift store/feature-graphic.png store/promo-1024x500.png
import AppKit
let args = CommandLine.arguments
let src = URL(fileURLWithPath: args[1]), dst = URL(fileURLWithPath: args[2])
guard let base = NSImage(contentsOf: src) else { fatalError("cannot read \(src.path)") }
let size = NSSize(width: 1024, height: 500)
let img = NSImage(size: size)
img.lockFocus()
base.draw(in: NSRect(origin: .zero, size: size))
func text(_ s: String, _ pt: CGFloat, _ color: NSColor, _ x: CGFloat, _ y: CGFloat, bold: Bool) {
    let font = NSFont(name: bold ? "ArialRoundedMTBold" : "Helvetica-Bold", size: pt) ?? NSFont.boldSystemFont(ofSize: pt)
    let shadow = NSShadow(); shadow.shadowColor = NSColor.white.withAlphaComponent(0.7); shadow.shadowOffset = NSSize(width: 2, height: -2); shadow.shadowBlurRadius = 3
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .shadow: shadow]
    NSAttributedString(string: s, attributes: attrs).draw(at: NSPoint(x: x, y: y))
}
// AppKit y is bottom-up. Keep all text >= 50px from edges.
text("Slime", 150, NSColor(red: 0.17, green: 0.18, blue: 0.26, alpha: 1), 560, 240, bold: true)
text("no ads · no purchases", 36, NSColor(red: 0.35, green: 0.39, blue: 0.47, alpha: 1), 572, 186, bold: false)
img.unlockFocus()
guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("encode") }
try! png.write(to: dst)
print("wrote", dst.path, Int(rep.pixelsWide), "x", Int(rep.pixelsHigh))
