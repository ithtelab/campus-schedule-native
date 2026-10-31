import Foundation
import CoreGraphics

enum CampusSpriteLayout {
    // Measured against the 887 × 1774 atlas: neither rows nor individual poses fit equal quarters.
    static func rect(index: Int, girl: Bool, width: Int, height: Int) -> CGRect? {
        guard (0..<16).contains(index), width > 0, height > 0 else { return nil }
        let rows = girl ? [(65,415),(445,845),(885,1288),(1295,1745)] : [(50,410),(445,865),(890,1310),(1315,1755)]
        let columns = girl
            ? [(0,226),(228,454),(454,662),(665,887),
               (0,258),(250,450),(440,658),(655,887),
               (0,221),(221,443),(440,669),(665,887),
               (0,232),(230,443),(437,665),(665,887)]
            : [(0,221),(221,443),(443,665),(665,887),
               (0,240),(235,440),(444,657),(661,887),
               (0,221),(221,443),(443,665),(665,887),
               (0,235),(236,443),(443,665),(665,887)]
        let row = rows[index / 4]
        let column = columns[index]
        let left = Int((Double(column.0) * Double(width) / 887).rounded())
        let right = Int((Double(column.1) * Double(width) / 887).rounded())
        let top = Int((Double(row.0) * Double(height) / 1774).rounded())
        let bottom = Int((Double(row.1) * Double(height) / 1774).rounded())
        return CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(right - left), height: CGFloat(bottom - top))
    }
}
