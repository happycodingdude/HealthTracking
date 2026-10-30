// Ghép bộ ảnh so sánh (06 Bản 4 ED4-04): mỗi ô một trang PDF — tiêu đề (id ·
// màn · trạng thái), trái = ảnh simulator, phải = vùng cắt từ trang mock.
//   review_pdf <cells.tsv> <shots-dir> <mock-dir> <out.pdf> <mockScale>
import Foundation
import CoreGraphics
import ImageIO
import AppKit

let a = CommandLine.arguments
guard a.count >= 6 else { print("usage: review_pdf tsv shots mock out.pdf mockScale"); exit(2) }
let tsv = try! String(contentsOfFile: a[1], encoding: .utf8)
let shots = a[2], mockDir = a[3], out = a[4]
let mockScale = CGFloat(Double(a[5]) ?? 2)

func loadImage(_ path: String) -> CGImage? {
  guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
  return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

let pageW: CGFloat = 1000, pageH: CGFloat = 1100
var box = CGRect(x: 0, y: 0, width: pageW, height: pageH)
guard let ctx = CGContext(URL(fileURLWithPath: out) as CFURL, mediaBox: &box, nil) else { exit(1) }
var missing: [String] = []
for line in tsv.split(separator: "\n") {
  let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
  guard f.count >= 8 else { continue }
  let id = f[0], screen = f[1], state = f[2]
  let page = Int(f[3]) ?? 1
  let x = CGFloat(Double(f[4]) ?? 0), y = CGFloat(Double(f[5]) ?? 0)
  let w = CGFloat(Double(f[6]) ?? 0), h = CGFloat(Double(f[7]) ?? 0)
  ctx.beginPDFPage(nil)
  ctx.setFillColor(CGColor(gray: 0.12, alpha: 1))
  ctx.fill(box)
  // Tiêu đề
  let title = "\(id) · \(screen) · \(state)" as NSString
  let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: NSColor.white]
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
  title.draw(at: NSPoint(x: 30, y: pageH - 50), withAttributes: attrs)
  ("simulator" as NSString).draw(at: NSPoint(x: 30, y: pageH - 80), withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.lightGray])
  ("mock 04 (trang \(page))" as NSString).draw(at: NSPoint(x: 520, y: pageH - 80), withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.lightGray])
  NSGraphicsContext.restoreGraphicsState()
  let areaH: CGFloat = pageH - 120, areaY: CGFloat = 30
  // Trái: ảnh simulator
  if let shot = loadImage("\(shots)/\(id).png") {
    let sw = CGFloat(shot.width), sh = CGFloat(shot.height)
    let scale = min(440 / sw, areaH / sh)
    let r = CGRect(x: 30, y: areaY + areaH - sh * scale, width: sw * scale, height: sh * scale)
    ctx.draw(shot, in: r)
  } else {
    missing.append(id)
  }
  // Phải: vùng mock
  if let mock = loadImage("\(mockDir)/page-\(page).png") {
    let crop = CGRect(x: x * mockScale, y: y * mockScale, width: w * mockScale, height: h * mockScale)
    if let part = mock.cropping(to: crop) {
      let pw = CGFloat(part.width), ph = CGFloat(part.height)
      let scale = min(450 / pw, areaH / ph)
      let r = CGRect(x: 520, y: areaY + areaH - ph * scale, width: pw * scale, height: ph * scale)
      ctx.draw(part, in: r)
    }
  }
  ctx.endPDFPage()
}
ctx.closePDF()
if !missing.isEmpty { print("review_pdf: thiếu ảnh: \(missing.joined(separator: ", "))") }
print("review_pdf: đã ghi \(out)")
