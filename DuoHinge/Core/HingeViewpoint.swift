/// Fixed eye positions in screen-relative coordinates; no camera or tracking.
enum HingeViewpoint: String, CaseIterable, Identifiable {
    case front = "Front"
    case desk = "Desk"

    var id: String { rawValue }

    // x is relative to screen width; y and viewing distance are relative to height.
    // Screen y increases downward. Desk preserves the original upper-screen viewpoint.
    var eye: SIMD3<Float> {
        switch self {
        case .front: SIMD3(0.5, 0.5, 2.8)
        case .desk: SIMD3(0.5, 0.35, 2.8)
        }
    }
}
