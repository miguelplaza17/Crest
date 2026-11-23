import SwiftUI
import UniformTypeIdentifiers

/// Every action outside the row on top, in its group, each run from its row;
/// or, while editing, every action the device offers under that row. The
/// person drags an action into the row and a tile back out onto the list, or
/// chooses a slot and then an action, which works from the keyboard and with
/// VoiceOver too; choosing one already in the row trades the two.
struct SiteControlsActionsPage: View {
    let model: SiteControlsModel

    @Environment(\.siteControlsMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: CrestSpacing.medium) {
            ForEach(SiteControlActionGroup.all, id: \.self) { group in
                let actions = actions(in: group)
                if !actions.isEmpty {
                    SiteControlsPageSection(title: group.title) {
                        ForEach(actions) { action in
                            if model.isEditingActions { choice(action) } else { row(action) }
                        }
                    }
                }
            }
            if model.isEditingActions {
                SiteControlsPageSection(footer: Text("Saved on this device.")) {
                    SiteControlsRow(
                        title: Text("Reset to Default"), symbol: "arrow.uturn.backward",
                        titleTint: CrestBrandTheme.accentText, action: { model.resetActions() }
                    ) {
                        EmptyView()
                    }
                    .accessibilityIdentifier("site-controls-reset-actions")
                }
            }
        }
        // A tile dragged off the row and let go over the list leaves the row.
        .onDrop(of: [UTType.utf8PlainText], isTargeted: nil) { _ in
            defer { model.draggedAction = nil }
            guard model.isEditingActions, let action = model.draggedAction,
                model.topActions.contains(where: { $0.action == action })
            else { return false }
            model.remove(action)
            return true
        }
    }

    /// The actions a group lists: while editing every one the device offers,
    /// otherwise those not on top, leaving out one that shows only
    /// while it can run and cannot now.
    private func actions(in group: SiteControlActionGroup) -> [SiteControlAction] {
        let source = model.isEditingActions ? model.offeredActions : model.moreActions
        return source.filter { action in
            action.group == group
                && (model.isEditingActions || !action.showsOnlyWhenAvailable
                    || model.platform.state(of: action).isAvailable)
        }
    }

    // MARK: - Running

    private func row(_ action: SiteControlAction) -> some View {
        let item = model.item(action)
        return SiteControlsRow(title: Text(item.title), symbol: item.symbol) {
            model.run(action)
        } trailing: {
            if let shortcut = item.shortcut {
                SiteControlsRowValue(value: shortcut.displayString)
            }
        }
        .disabled(!item.state.isAvailable)
        .accessibilityIdentifier("site-control-more-\(action.name)")
    }

    // MARK: - Editing

    /// An action as the editor lists it: its place in the row on top, or a plus,
    /// and it goes into the chosen slot when chosen.
    private func choice(_ action: SiteControlAction) -> some View {
        let item = model.item(action)
        let rank = model.core.state.siteControlTopActions.actions.firstIndex(of: action).map { $0 + 1 }
        return SiteControlsRow(title: Text(item.title), symbol: item.symbol) {
            model.placeInSelectedSlot(action)
        } trailing: {
            SiteControlsRank(rank: rank)
        }
        .onDrag {
            model.draggedAction = action
            return NSItemProvider(object: action.name as NSString)
        } preview: {
            Label(item.title, systemImage: item.symbol)
                .padding(CrestSpacing.small)
        }
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(rank.map { Text("In slot \($0)") } ?? Text(verbatim: ""))
        .accessibilityHint(Text("Puts it in slot \(model.selectedSlot + 1)"))
        .accessibilityIdentifier("site-controls-choose-\(action.name)")
    }
}

/// An action's place in the row on top, as a numbered Crest-blue disc, or an
/// outlined plus for one that is not there.
private struct SiteControlsRank: View {
    let rank: Int?

    var body: some View {
        Group {
            if let rank {
                Text(verbatim: "\(rank)")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 18, height: 18)
                    .background(CrestBrandTheme.accent, in: .circle)
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .overlay { Circle().strokeBorder(.secondary.opacity(0.5), lineWidth: 1.5) }
            }
        }
        .accessibilityHidden(true)
    }
}
