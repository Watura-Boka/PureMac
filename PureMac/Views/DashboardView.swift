import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    var onNavigate: (AppSection) -> Void = { _ in }

    @State private var showConfirmation = false
    @State private var hoveredSegment: String?
    @State private var pendingCleanItems: [CleanableItem] = []
    @State private var confetti = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                pageHeader
                stateContent
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 1080, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: isCleanedWithoutFailures) { done in
            if done { confetti.toggle() }
        }
        .confirmationDialog(
            cleanConfirmationTitle,
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clean selected items", role: .destructive) {
                appState.cleanAll(itemIDs: Set(pendingCleanItems.map(\.id)))
                pendingCleanItems = []
            }
            Button("Cancel", role: .cancel) {
                pendingCleanItems = []
            }
        } message: {
            Text(cleanConfirmationMessage)
        }
    }

    private var isCleanedWithoutFailures: Bool {
        if case .cleaned = appState.scanState { return !appState.lastCleanupHadFailures }
        return false
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Overview")
                    .font(Typo.display(30))
                    .tracking(-0.4)
                    .accessibilityAddTraits(.isHeader)
                Text(headerSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .id(headerSubtitle)
                    .transition(.opacity)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: headerSubtitle)

            Spacer(minLength: 20)

            VStack(alignment: .trailing, spacing: 7) {
                let status = headerStatus
                StatusChip(label: status.label, systemImage: status.icon, tint: status.tint)
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    Text(lastCareText(relativeTo: timeline.date))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        Group {
            switch appState.scanState {
            case .idle:
                idleContent
            case .scanning:
                scanningContent
            case .completed:
                resultsContent
            case .cleaning:
                cleaningContent
            case .cleaned:
                cleanedContent
            }
        }
        .transition(stateTransition)
        .animation(reduceMotion ? nil : MotionTokens.gentle, value: stateKey)
    }

    private var stateKey: Int {
        switch appState.scanState {
        case .idle: return 0
        case .scanning: return 1
        case .completed: return 2
        case .cleaning: return 3
        case .cleaned: return 4
        }
    }

    private var stateTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8))
    }

    private var headerSubtitle: String {
        switch appState.scanState {
        case .idle:
            return String(localized: "Storage, cleanup, and system tools.")
        case .scanning:
            return String(localized: "Checking your Mac. Nothing is removed during a scan.")
        case .completed:
            return appState.scanWasCancelled
                ? String(localized: "The scan stopped. Available results are ready to review.")
                : String(localized: "Review the results and choose exactly what to remove.")
        case .cleaning:
            return String(localized: "Removing the items you selected.")
        case .cleaned:
            return String(localized: "Cleanup finished and disk information is refreshing.")
        }
    }

    private var headerStatus: (label: String, icon: String, tint: Color) {
        switch appState.scanState {
        case .idle:
            return appState.hasFullDiskAccess
                ? (String(localized: "Ready"), "checkmark.circle.fill", Tint.green)
                : (String(localized: "Limited access"), "lock.fill", Tint.orange)
        case .scanning:
            return (String(localized: "Scanning"), "magnifyingglass", Tint.accent)
        case .completed:
            if appState.scanWasCancelled {
                return (String(localized: "Stopped"), "stop.circle.fill", Tint.orange)
            }
            return (String(localized: "Review ready"), "checklist", Tint.accent)
        case .cleaning:
            return (String(localized: "Cleaning"), "trash.fill", Tint.orange)
        case .cleaned:
            return appState.lastCleanupHadFailures
                ? (String(localized: "Needs attention"), "exclamationmark.circle.fill", Tint.orange)
                : (String(localized: "Complete"), "checkmark.circle.fill", Tint.green)
        }
    }

    private func lastCareText(relativeTo now: Date) -> String {
        let date = appState.lastCleanedDate ?? appState.lastScanDate
        guard let date else {
            return String(localized: "No scan run yet")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: date, relativeTo: now)
        return String(format: String(localized: "Last activity: %@"), relative)
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 30) {
            heroCard
                .staggered(0, baseDelay: 0.06)

            VStack(alignment: .leading, spacing: 22) {
                toolGroup("Free up space", index: 1, tiles: [
                    ToolTileModel(title: "Space Explorer", detail: "See which folders take the most room",
                                  icon: "square.3.layers.3d.down.right", section: .spaceExplorer),
                    ToolTileModel(title: "Duplicate Finder", detail: "Find identical files you can remove",
                                  icon: "doc.on.doc", section: .duplicates),
                    ToolTileModel(title: "Similar Photos", detail: "Spot near-identical shots",
                                  icon: "photo.stack", section: .similarPhotos)
                ])
                toolGroup("Keep it healthy", index: 2, tiles: [
                    ToolTileModel(title: "Protection", detail: "Check that macOS security is on",
                                  icon: "shield.checkered", section: .protection),
                    ToolTileModel(title: "Performance", detail: "See what is using CPU and memory",
                                  icon: "gauge.with.dots.needle.67percent", section: .performance),
                    ToolTileModel(title: "Apple Features", detail: "Review Siri, image tools and extras",
                                  icon: "switch.2", section: .appleFeatures)
                ])
                toolGroup("Apps", index: 3, tiles: [
                    ToolTileModel(title: "Uninstaller", detail: "Remove apps and what they leave behind",
                                  icon: "app.dashed", section: .apps),
                    ToolTileModel(title: "App Updates", detail: "Check Homebrew-managed apps",
                                  icon: "arrow.triangle.2.circlepath", section: .appUpdates)
                ])
            }
        }
    }

    private var diskIsLoading: Bool {
        appState.diskInfo.totalSpace <= 0
    }

    private var heroCard: some View {
        CardSurface(padding: 28, elevation: .raised) {
            HStack(alignment: .center, spacing: 36) {
                DialEmblem(
                    mode: .idle(used: Double(usedPercent) / 100),
                    size: 190,
                    title: "\(usedPercent)%",
                    caption: String(localized: "used")
                )
                .opacity(diskIsLoading ? 0.35 : 1)

                VStack(alignment: .leading, spacing: 16) {
                    if diskIsLoading {
                        VStack(alignment: .leading, spacing: 10) {
                            SkeletonBar(width: 90, height: 11)
                            SkeletonBar(width: 210, height: 30, corner: 7)
                            SkeletonBar(height: 10, corner: 5)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mac storage")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(appState.diskInfo.formattedFree)
                                    .font(Typo.display(38))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                Text("available")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Text(String(
                                format: String(localized: "of %@ in total"),
                                ByteCountFormatter.string(fromByteCount: appState.diskInfo.totalSpace, countStyle: .file)
                            ))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }

                        StackedMeter(
                            segments: diskSegments.map {
                                StackedMeter.Segment(id: $0.id, value: $0.value, color: $0.color)
                            },
                            height: 8,
                            highlightedID: hoveredSegment
                        )
                        .accessibilityHidden(true)

                        HStack(spacing: 22) {
                            diskLegendRow(
                                id: "used",
                                color: Color.primary.opacity(0.5),
                                label: "Used",
                                value: ByteCountFormatter.string(
                                    fromByteCount: max(0, appState.diskInfo.usedSpace - appState.diskInfo.purgeableSpace),
                                    countStyle: .file
                                )
                            )
                            if appState.diskInfo.purgeableSpace > 0 {
                                diskLegendRow(
                                    id: "purgeable",
                                    color: Tint.cyan,
                                    label: "Purgeable",
                                    value: appState.diskInfo.formattedPurgeable
                                )
                            }
                            diskLegendRow(
                                id: "free",
                                color: Tint.accent,
                                label: "Available",
                                value: appState.diskInfo.formattedFree
                            )
                        }
                    }

                    HStack(spacing: 14) {
                        Button {
                            appState.startSmartScan()
                        } label: {
                            Label("Scan this Mac", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(GlowProminentButtonStyle(large: true))
                        .accessibilityIdentifier("dashboard.scan")

                        Text("Nothing is deleted until you approve it.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)

                    if appState.diskInfo.purgeableSpace > 0 {
                        Text("Purgeable space is managed by macOS and is not included in cleanup.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                appState.loadDiskInfo()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            .buttonStyle(.plain)
            .help("Refresh disk information")
            .accessibilityLabel("Refresh disk information")
        }
    }

    private func diskLegendRow(id: String, color: Color, label: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .opacity(hoveredSegment == nil || hoveredSegment == id ? 1 : 0.38)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                hoveredSegment = hovering ? id : nil
            }
        }
    }

    private var diskSegments: [StorageDonut.Segment] {
        let info = appState.diskInfo
        let used = max(0, info.usedSpace - info.purgeableSpace)
        var segments = [
            StorageDonut.Segment(
                id: "used",
                value: Double(used),
                color: Color.primary.opacity(0.5),
                label: "Used",
                display: ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
            )
        ]
        if info.purgeableSpace > 0 {
            segments.append(
                StorageDonut.Segment(
                    id: "purgeable",
                    value: Double(info.purgeableSpace),
                    color: Tint.cyan,
                    label: "Purgeable",
                    display: info.formattedPurgeable
                )
            )
        }
        segments.append(
            StorageDonut.Segment(
                id: "free",
                value: Double(max(0, info.freeSpace)),
                color: Tint.accent,
                label: "Available",
                display: info.formattedFree
            )
        )
        return segments
    }

    private var usedPercent: Int {
        guard appState.diskInfo.totalSpace > 0 else { return 0 }
        let used = appState.diskInfo.totalSpace - appState.diskInfo.freeSpace
        return Int((Double(max(0, used)) / Double(appState.diskInfo.totalSpace) * 100).rounded())
    }

    private func toolGroup(_ title: LocalizedStringKey, index: Int, tiles: [ToolTileModel]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            dashboardSection(title)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 250), spacing: 12, alignment: .top)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(tiles) { tile in
                    ToolTile(model: tile) { onNavigate(tile.section) }
                }
            }
        }
        .staggered(index, baseDelay: 0.06)
    }

    // MARK: - Scanning

    private var scanningContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            CardSurface(padding: 28, elevation: .raised) {
                HStack(alignment: .center, spacing: 36) {
                    DialEmblem(
                        mode: .scanning(appState.scanProgress),
                        size: 190,
                        title: "\(Int((appState.scanProgress * 100).rounded()))%",
                        caption: String(localized: "scanning")
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Scanning your Mac")
                                .font(Typo.display(24))
                            Text(LocalizedStringKey(appState.currentScanCategory))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .id(appState.currentScanCategory)
                                .transition(.opacity)
                        }
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: appState.currentScanCategory)

                        GildedProgressBar(value: appState.scanProgress, height: 6)
                        ScanPathTicker(ticker: appState.scanTicker)

                        HStack(spacing: 12) {
                            Button("Stop scan", role: .cancel) {
                                appState.cancelScan()
                            }
                            .buttonStyle(.bordered)
                            Text("Stopping keeps the results found so far.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if appState.allResults.isEmpty {
                scanSkeleton
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    dashboardSection("Found so far", detail: "\(appState.totalItemCount) items")
                    resultRows(results: Array(appState.allResults.sorted { $0.totalSize > $1.totalSize }.prefix(6)))
                }
            }
        }
    }

    /// Calm placeholder rows while the first results arrive.
    private var scanSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            dashboardSection("Looking for removable items")
            CardSurface(padding: 0, elevation: .flat) {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 12) {
                            SkeletonBar(width: 30, height: 30, corner: 8)
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonBar(width: CGFloat(150 - index * 22), height: 11)
                                SkeletonBar(width: 90, height: 9)
                            }
                            Spacer()
                            SkeletonBar(width: 54, height: 11)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        if index < 2 { Divider().padding(.leading, 58) }
                    }
                }
            }
        }
    }

    // MARK: - Results

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            CardSurface(padding: 28, elevation: .raised) {
                HStack(alignment: .center, spacing: 36) {
                    DialEmblem(
                        mode: .review,
                        size: 170,
                        title: ByteCountFormatter.string(fromByteCount: appState.totalSelectedSize, countStyle: .file),
                        caption: String(localized: "selected")
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(appState.scanWasCancelled ? "Scan stopped" : "Scan complete")
                                .font(Typo.display(24))
                            Text(resultSummary)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 14) {
                            if appState.totalSelectedSize > 0 {
                                Button {
                                    prepareCleanupConfirmation()
                                } label: {
                                    Label(cleanSelectedLabel, systemImage: "trash")
                                }
                                .buttonStyle(GlowProminentButtonStyle(large: true))
                            }
                            Button("Scan again") {
                                appState.startSmartScan()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if appState.allResults.isEmpty {
                emptyResults
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    dashboardSection(
                        appState.scanWasCancelled ? "Partial results" : "Cleanup plan",
                        detail: "Open a category to review individual items"
                    )
                    resultRows(results: appState.allResults.sorted { $0.totalSize > $1.totalSize })
                }
            }
        }
    }

    private var resultSummary: String {
        if appState.allResults.isEmpty {
            return appState.scanWasCancelled
                ? String(localized: "No reclaimable items were found before the scan stopped.")
                : String(localized: "No reclaimable items were found in the areas checked.")
        }
        let size = ByteCountFormatter.string(fromByteCount: appState.totalJunkSize, countStyle: .file)
        if appState.scanWasCancelled {
            return String(format: String(localized: "%@ found before the scan stopped. Results may be incomplete."), size)
        }
        return String(format: String(localized: "%@ found across %lld categories."), size, Int64(appState.allResults.count))
    }

    private var emptyResults: some View {
        CardSurface(padding: 28, elevation: .flat) {
            HStack(spacing: 18) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Tint.green)
                VStack(alignment: .leading, spacing: 5) {
                    Text(appState.scanWasCancelled ? "No results yet" : "Nothing to clean")
                        .font(Typo.display(20))
                    Text(
                        appState.scanWasCancelled
                            ? "Run the scan again when you are ready to check every area."
                            : "PureMac did not find removable items in the selected scan areas."
                    )
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func resultRows(results: [CategoryResult]) -> some View {
        let largest = max(1, results.map(\.totalSize).max() ?? 1)
        return CardSurface(padding: 0, elevation: .flat) {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    CategoryResultRow(
                        result: result,
                        shareOfLargest: Double(result.totalSize) / Double(largest),
                        selectedCount: appState.selectedCountInCategory(result.category),
                        selection: appState.categoryBinding(for: result.category)
                    ) {
                        onNavigate(.cleaning(result.category))
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -6)))
                    if index < results.count - 1 {
                        Divider()
                            .padding(.leading, 58)
                    }
                }
            }
            .animation(reduceMotion ? nil : MotionTokens.gentle, value: results.map(\.id))
        }
    }

    // MARK: - Cleaning

    private var cleaningContent: some View {
        CardSurface(padding: 28, elevation: .raised) {
            HStack(alignment: .center, spacing: 36) {
                DialEmblem(
                    mode: .cleaning(appState.cleanProgress),
                    size: 170,
                    title: "\(Int((appState.cleanProgress * 100).rounded()))%",
                    caption: String(localized: "cleaning")
                )
                VStack(alignment: .leading, spacing: 14) {
                    Text("Cleaning selected items")
                        .font(Typo.display(24))
                    GildedProgressBar(value: appState.cleanProgress, height: 6, tint: Tint.orange)
                    Text("Keep PureMac open until cleanup finishes.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Cleaned

    private var cleanedContent: some View {
        CardSurface(padding: 28, elevation: .raised) {
            HStack(alignment: .center, spacing: 36) {
                if appState.lastCleanupHadFailures {
                    IconTile(systemName: "exclamationmark.circle", tint: Tint.orange, size: 80, corner: 22)
                        .frame(width: 170, height: 170)
                } else {
                    DialEmblem(mode: .success, size: 170, title: "", caption: String(localized: "complete"))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(appState.lastCleanupHadFailures ? "Some items need attention" : "Cleanup complete")
                        .font(Typo.display(26))
                    if appState.totalFreedSpace > 0 {
                        Text(String(
                            format: String(localized: "%@ removed"),
                            ByteCountFormatter.string(fromByteCount: appState.totalFreedSpace, countStyle: .file)
                        ))
                        .font(Typo.display(18, weight: .regular))
                        .foregroundStyle(Tint.brass)
                        .monospacedDigit()
                    }
                    if let cleanError = appState.cleanError {
                        Text(cleanError)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    Button("Done") {
                        appState.scanState = .idle
                    }
                    .buttonStyle(GlowProminentButtonStyle())
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .overlay {
            ConfettiView(trigger: confetti, mode: .burst(origin: UnitPoint(x: 0.17, y: 0.5)))
        }
    }

    // MARK: - Confirmation

    private var cleanConfirmationTitle: String {
        let size = pendingCleanItems.reduce(Int64(0)) { $0 + $1.size }
        return String(
            format: String(localized: "Permanently delete %@?"),
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        )
    }

    private var cleanConfirmationMessage: String {
        String(
            format: String(localized: "%lld selected items will be permanently deleted. Review the list before continuing."),
            Int64(pendingCleanItems.count)
        )
    }

    private func prepareCleanupConfirmation() {
        pendingCleanItems = appState.allResults
            .flatMap(\.items)
            .filter(appState.isItemSelected)
        showConfirmation = !pendingCleanItems.isEmpty
    }

    private var cleanSelectedLabel: String {
        String(
            format: String(localized: "Clean %@"),
            ByteCountFormatter.string(fromByteCount: appState.totalSelectedSize, countStyle: .file)
        )
    }

    private func dashboardSection(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typo.display(17))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Tiles

private struct ToolTileModel: Identifiable {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let icon: String
    let section: AppSection
    var id: AppSection { section }
}

private struct ToolTile: View {
    let model: ToolTileModel
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                IconTile(systemName: model.icon, tint: Tint.accent, size: 36, corner: 9, glow: hovering)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(model.detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tint.brass)
                    .opacity(hovering ? 1 : 0)
                    .offset(x: hovering || reduceMotion ? 0 : -4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(hovering ? Tint.brass.opacity(0.55) : Palette.hairline, lineWidth: 0.75)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .pressable(hoverScale: 1.01, lift: true)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : MotionTokens.snappy, value: hovering)
        .accessibilityElement(children: .combine)
    }
}

private struct CategoryResultRow: View {
    let result: CategoryResult
    let shareOfLargest: Double
    let selectedCount: Int
    @Binding var selection: Bool
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $selection)
                .labelsHidden()
                .toggleStyle(AnimatedCheckboxStyle(tint: Tint.accent))
            IconTile(systemName: result.category.icon, tint: result.category.color, size: 32, corner: 8)
            Button(action: open) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(LocalizedStringKey(result.category.rawValue))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        GildedProgressBar(
                            value: shareOfLargest,
                            height: 3,
                            tint: result.category.color,
                            showsSheen: false
                        )
                        .frame(maxWidth: 220)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(result.formattedSize)
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text("\(selectedCount) of \(result.itemCount) selected")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ScanPathTicker: View {
    @ObservedObject var ticker: ScanProgressTicker

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 10))
            Text(ticker.path.isEmpty ? String(localized: "Preparing the next area…") : ticker.path)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(.secondary)
        .accessibilityLabel("Current scan path")
        .accessibilityValue(ticker.path)
    }
}
