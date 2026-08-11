import Foundation
import CoreGraphics

/// Works out where each window should go.
///
/// The screen is split down the middle into two columns. Windows are dealt out
/// between them, then cascaded down and to the right inside each column, so
/// that every window below the top one still shows a strip of its title bar.
/// That strip is the whole point: with AutoRaise running, the pointer landing
/// on any exposed sliver brings that window forward. Two displays become four
/// reachable working zones.
enum CascadeLayout {

    /// How far each window steps down and right from the one beneath it.
    /// 30pt clears a standard title bar with a little room to aim at.
    static let preferredStep: CGFloat = 30

    /// Below this a window is too small to be worth arranging, so the cascade
    /// tightens its step instead of shrinking further.
    static let minimumSize = CGSize(width: 420, height: 300)

    /// - Parameters:
    ///   - count: how many windows to place.
    ///   - area: the usable area of one screen, in AX coordinates.
    /// - Returns: frames in the same order as the windows given, left column
    ///   first, then right column.
    static func frames(count: Int, in area: CGRect) -> [CGRect] {
        guard count > 0 else { return [] }

        // A single window has nothing to cascade against, so it simply fills
        // the screen. Splitting it into a half would waste the display.
        if count == 1 { return [area] }

        let leftCount = Int(ceil(Double(count) / 2))
        let rightCount = count - leftCount

        let halfWidth = area.width / 2
        let left = CGRect(x: area.minX, y: area.minY, width: halfWidth, height: area.height)
        let right = CGRect(x: area.midX, y: area.minY, width: halfWidth, height: area.height)

        return column(leftCount, in: left) + column(rightCount, in: right)
    }

    private static func column(_ count: Int, in rect: CGRect) -> [CGRect] {
        guard count > 0 else { return [] }
        if count == 1 { return [rect] }

        let steps = CGFloat(count - 1)

        // Start from the comfortable step, then tighten it if the last window
        // would end up unusably small. Half the column is the hard ceiling for
        // total travel; past that the cascade is more gap than window.
        var step = preferredStep
        let maxTravelX = min(rect.width - minimumSize.width, rect.width * 0.5)
        let maxTravelY = min(rect.height - minimumSize.height, rect.height * 0.5)
        let allowed = max(0, min(maxTravelX, maxTravelY))
        if steps * step > allowed { step = allowed / steps }

        let width = rect.width - steps * step
        let height = rect.height - steps * step

        return (0..<count).map { index in
            let offset = CGFloat(index) * step
            return CGRect(x: rect.minX + offset,
                          y: rect.minY + offset,
                          width: width,
                          height: height)
        }
    }
}
