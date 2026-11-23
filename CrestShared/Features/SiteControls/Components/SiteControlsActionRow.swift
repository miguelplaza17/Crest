import SwiftUI
import UniformTypeIdentifiers

/// The actions on top of Site Controls as a row of tiles that share its
/// width. A tile dragged along the row lifts out of it and the others open a
/// gap where it would land; an action dragged in from the editor's list does
/// the same, letting the last go when there are four. While the editor shows
/// it, each tile wears its slot's number, and the slots still empty wait at
/// the end for an action.
struct SiteControlsActionRow: View {
    // MARK: - Types

    /// One place in the row: a tile, or the gap a drag holds open.
    private enum Place: Identifiable {
        case tile(SiteControlsModel.ActionItem, slot: Int)
        case gap
        case empty(slot: Int)

        var id: String {
            switch self {
            case .tile(let item, _): item.id
            case .gap: "gap"
            case .empty(let slot): "empty-\(slot)"
            }
        }
    }

    // MARK: - Variables

    let model: SiteControlsModel
    /// Whether the editor shows the row, which numbers its slots and chooses
    /// one rather than running an action.
    var isEditing = false

    @Environment(\.siteControlsMetrics) private var metrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The row's width, which a drag over it divides among its places.
    @State private var width: CGFloat = 0

    var body: some View {
        let places = places
        HStack(spacing: metrics.tileSpacing) {
            ForEach(places) { place in
                switch place {
                case .tile(let item, let slot): tile(item, slot: slot)
                case .gap: gap
                case .empty(let slot): empty(slot: slot)
                }
            }
        }
        .frame(height: metrics.actionTileHeight)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        .animation(CrestMotion.dragSource.unlessReducingMotion(reduceMotion), value: places.map(\.id))
        .onDrop(
            of: [UTType.utf8PlainText],
            delegate: SiteControlsActionRowDrop(model: model, slots: dropSlots, width: width))
    }

    // MARK: - Actions - Places

    /// The row as it shows now: the actions on top, with a drag over the row
    /// lifting its own tile out and holding a gap where it would land, and in
    /// the editor the empty slots after them.
    private var places: [Place] {
        let items = model.topActions
        var places = items.enumerated().map { Place.tile($1, slot: $0) }
        if let dragged = model.draggedAction, let index = model.dropIndex {
            places.removeAll { $0.id == dragged.name }
            places.insert(.gap, at: min(index, places.count))
            if places.count > SiteControlTopActions.maximumCount { places.removeLast() }
        } else if isEditing {
            places += (items.count..<SiteControlTopActions.maximumCount).map { Place.empty(slot: $0) }
        }
        return places
    }

    /// How many places a drag over the row chooses between: the tiles it
    /// does not carry, and one more while there is room.
    private var dropSlots: Int {
        let count = model.topActions.count
        guard let dragged = model.draggedAction else { return count }
        let carried = model.topActions.contains { $0.action == dragged } ? count - 1 : count
        return min(carried + 1, SiteControlTopActions.maximumCount)
    }

    // MARK: - Actions - Drawing

    private func tile(_ item: SiteControlsModel.ActionItem, slot: Int) -> some View {
        SiteControlsActionTile(
            item: item, height: metrics.actionTileHeight, slotNumber: isEditing ? slot + 1 : nil,
            isSelected: isEditing && model.selectedSlot == slot
        ) {
            if isEditing { model.selectedSlot = slot } else { model.run(item.action) }
        }
        .onDrag {
            model.draggedAction = item.action
            return NSItemProvider(object: item.action.name as NSString)
        } preview: {
            SiteControlsActionTile(item: item, height: metrics.actionTileHeight, action: {})
                .frame(width: 70)
        }
        .contextMenu { SiteControlsTileMenu(model: model, slot: slot) }
        .accessibilityLabel(
            isEditing ? Text("Slot \(slot + 1), \(String(localized: item.title))") : Text(item.title)
        )
        .accessibilityValue(isEditing && model.selectedSlot == slot ? Text("Chosen") : Text(verbatim: ""))
        .accessibilityHint(isEditing ? Text("Choose an action below to put in this slot") : Text(verbatim: ""))
        .accessibilityAction(named: "Move Left") { move(item.action, from: slot, by: -1) }
        .accessibilityAction(named: "Move Right") { move(item.action, from: slot, by: 1) }
        .accessibilityAction(named: "Remove from Actions") { model.remove(item.action) }
        .accessibilityIdentifier(
            isEditing ? "site-controls-slot-\(slot + 1)" : "site-control-action-\(item.action.name)")
    }

    private var gap: some View {
        RoundedRectangle(cornerRadius: CrestRadius.compact)
            .fill(CrestColor.chromeSurface.opacity(0.5))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private func empty(slot: Int) -> some View {
        let isSelected = model.selectedSlot == slot
        return Button {
            model.selectedSlot = slot
        } label: {
            Image(systemName: "plus")
                .font(.system(size: metrics.actionGlyphSize * 0.8, weight: .medium))
                .foregroundStyle(isSelected ? CrestBrandTheme.accentText : .secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: CrestRadius.compact)
                .strokeBorder(
                    isSelected ? CrestBrandTheme.accent : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: isSelected ? [] : [4, 3]))
        }
        .accessibilityLabel(Text("Empty slot \(slot + 1)"))
        .accessibilityValue(isSelected ? Text("Chosen") : Text(verbatim: ""))
        .accessibilityHint("Choose an action below to put in this slot")
        .accessibilityIdentifier("site-controls-slot-\(slot + 1)")
    }

    /// Moves a tile one slot along, as its context menu's Move Left and Move
    /// Right do.
    private func move(_ action: SiteControlAction, from slot: Int, by offset: Int) {
        let target = slot + offset
        guard model.topActions.indices.contains(target) else { return }
        model.move(action, to: target)
    }
}

/// A drag over the row of actions: it holds the gap where the dragged action
/// would land, and letting go moves it there or brings it in. Only an action
/// dragged within Site Controls lands; text from elsewhere does nothing.
private struct SiteControlsActionRowDrop: DropDelegate {
    let model: SiteControlsModel
    /// How many places the drag chooses between.
    let slots: Int
    /// The row's width, which the places share.
    let width: CGFloat

    func validateDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated { model.draggedAction != nil }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        MainActor.assumeIsolated {
            guard model.draggedAction != nil else { return }
            model.dropIndex = index(at: info.location.x)
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        MainActor.assumeIsolated { model.dropIndex = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated {
            defer {
                model.draggedAction = nil
                model.dropIndex = nil
            }
            guard let action = model.draggedAction else { return false }
            model.move(action, to: model.dropIndex ?? index(at: info.location.x))
            return true
        }
    }

    /// The place under `x` along the row.
    private func index(at x: CGFloat) -> Int {
        guard width > 0, slots > 0 else { return 0 }
        return min(max(Int(x / (width / CGFloat(slots))), 0), slots - 1)
    }
}
