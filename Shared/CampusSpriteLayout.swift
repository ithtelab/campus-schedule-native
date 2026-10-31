import Foundation
import CoreGraphics

enum CampusSpriteLayout {
    // The generated artwork has uneven rows. Do not divide the image into equal quarters.
    static func rect(index: Int, girl: Bool, width: Int, height: Int) -> CGRect? {
        guard (0..<16).contains(index), width > 0, height > 0 else { return nil }
        let rows = girl ? [(65,415),(445,845),(885,1288),(1295,1745)] : [(50,410),(445,865),(890,1310),(1315,1755)]
        let row = rows[index / 4]
        let left = width * (index % 4) / 4, right = width * (index % 4 + 1) / 4
        let top = Int((Double(row.0) * Double(height) / 1774).rounded())
        let bottom = Int((Double(row.1) * Double(height) / 1774).rounded())
        return CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(right - left), height: CGFloat(bottom - top))
    }
}
