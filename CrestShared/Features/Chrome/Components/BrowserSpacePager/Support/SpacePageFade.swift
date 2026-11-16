import Foundation

/// How a window's Space pages change where they don't slide, as with page
/// motion off or Reduce Motion, on every platform: every page keeps one
/// place, and the page the pager settles on fades in over the one it leaves,
/// on the pager's release curve and timing.
///
/// This decides which page shows whole and which fade out; each platform's
/// page area animates the opacities it answers.
struct SpacePageFade: Equatable {
    // MARK: - Variables

    /// The Space whose page shows whole, or fades in to.
    private(set) var wholeSpaceID: UUID?
    /// The Spaces whose pages are fading out, kept on screen until they have.
    private(set) var fadingOut: Set<UUID> = []

    // MARK: - Actions - Choosing

    /// The Space whose page shows whole at `snapshot`: the one the pager
    /// comes to rest on or settles toward, and while a finger moves it, the
    /// one it showed before, else `selectedSpaceID`.
    func target(of snapshot: SpacePagerPresentation.Snapshot, selectedSpaceID: UUID?) -> UUID? {
        snapshot.phase == .tracking ? wholeSpaceID ?? selectedSpaceID : snapshot.destinationID
    }

    /// Shows the page of `spaceID` whole. Answers whether the page shown
    /// before fades out under it: not for the first page shown, nor between
    /// Spaces that `sharePage`.
    mutating func show(_ spaceID: UUID?, sharePage: (UUID, UUID) -> Bool = { _, _ in false }) -> Bool {
        guard spaceID != wholeSpaceID else { return false }
        let previous = wholeSpaceID
        wholeSpaceID = spaceID
        if let spaceID { fadingOut.remove(spaceID) }
        guard let previous, let spaceID, !sharePage(previous, spaceID) else { return false }
        fadingOut.insert(previous)
        return true
    }

    /// Lets the pages that faded out go.
    mutating func finish() {
        fadingOut = []
    }

    /// Forgets what showed, for pages that slide again.
    mutating func reset() {
        self = SpacePageFade()
    }

    // MARK: - Actions - Opacity

    /// How opaque the page of `spaceID` is, `progress` of the way through the
    /// fade: the page shown whole fades in as the ones fading out fade away,
    /// and every other page is clear.
    func opacity(of spaceID: UUID, progress: Double = 1) -> Double {
        if spaceID == wholeSpaceID { return progress }
        return fadingOut.contains(spaceID) ? 1 - progress : 0
    }
}
