import SwiftUI

/// Places one Space's card in the page area as far along as the Space pager
/// has moved it, and as opaque as a fade between Spaces has it. Only this
/// modifier reads the pager's position, so a moving pager redraws the offsets
/// and nothing beneath them.
struct MobileSpacePageSlot: ViewModifier {
    let motion: MobileSpacePageMotion
    /// The Space the card is of, or nil for a page area showing none.
    let spaceID: UUID?

    func body(content: Content) -> some View {
        content
            .offset(x: spaceID.map(motion.offset(of:)) ?? 0)
            .opacity(spaceID.map(motion.opacity(of:)) ?? 1)
    }
}
