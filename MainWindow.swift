import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject private var permission = PermissionCoordinator.shared
    @State private var selectedSection: AppSection? = .cleaning(.smartScan)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var cleanupExpanded = false
    @State private var advancedToolsExpanded = false
    @State private var showAppearance = false
    @FocusState private var focusedSection: AppSection?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private static let cleanupCategories: [CleaningCategory] = [
        .systemJunk,
        .userCache,
        .mailAttachments,
        .trashBins,
        .largeFiles
    ]

    private static let advancedCategories: [CleaningCategory] = [
        .aiApps,
        .xcodeJunk,
        .brewCache,
        .nodeCache,
        .dockerCache
    ].filter(CleaningCategory.scannable.contains)

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 232, ideal: 252, max: 288)
        } detail: {
            detailContainer
        }
        .frame(minWidth: 960, minHeight: 640)
        .tint(Tint.accent)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.checkFullDiskAccess()
            permission.refreshStatus()
        }
        .onChange(of: appState.pendingExternalApp) { app in
            guard app != nil else { return }
            selectSection(.apps)
            appState.pendingExternalApp = nil
        }
        .onChange(of: appState.showUpdateSettings) { showUpdates in
            if showUpdates { selectSection(.settings) }
        }
        .onAppear {
            if appState.showUpdateSettings {
                selectSection(.settings)
            } else if appState.pendingExternalApp != nil {
                selectSection(.apps)
                appState.pendingExternalApp = nil
            } else if let selectedSection {
                focusedSection = selectedSection
            }
        }
        .onChange(of: appState.cleanErrorIsFDAFixable) { isFDAFixable in
            guard isFDAFixable else { return }
            let pending = appState.pendingPermissionRetryItems
            appState.cleanError = nil
            appState.cleanErrorIsFDAFixable = false
            appState.requestFullDiskAccessAndRetry(
                items: pending,
                context: .cleanup(failedCount: pending.count)
            )
        }
        .alert("Couldn't clean everything", isPresented: Binding(
            get: { appState.cleanError != nil && !appState.cleanErrorIsFDAFixable },
            set: { if !$0 { appState.cleanError = nil } }
        )) {
            Button("OK", role: .cancel) { appState.cleanError = nil }
        } message: {
            Text(appState.cleanError ?? "")
        }
        .sheet(isPresented: Binding(
            get: { permission.isRequesting && permission.presentation == .mainWindow },
            set: { if !$0 && permission.presentation == .mainWindow { permission.dismiss(callRetry: false) } }
        )) {
            PermissionSheet()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List {
            Section {
                navRow(
                    section: .cleaning(.smartScan),
                    label: "Overview",
                    icon: "house",
                    tint: Tint.accent,
                    badge: dashboardBadge,
                    emphasized: true
                )
                navRow(
                    section: .protection,
                    label: "Protection",
                    icon: "shield.checkered",
                    tint: Tint.green,
                    badge: nil
                )
                navRow(
                    section: .performance,
                    label: "Performance",
                    icon: "gauge.with.dots.needle.67percent",
                    tint: Tint.cyan,
                    badge: nil
                )
            } header: {
                sectionLabel("Maintain")
            }

            Section {
                navRow(
                    section: .spaceExplorer,
                    label: "Space Explorer",
                    icon: "square.3.layers.3d.down.right",
                    tint: Tint.accent,
                    badge: nil
                )
                navRow(
                    section: .duplicates,
                    label: "Duplicate Finder",
                    icon: "doc.on.doc",
                    tint: Tint.purple,
                    badge: nil
                )
                navRow(
                    section: .similarPhotos,
                    label: "Similar Photos",
                    icon: "photo.stack",
                    tint: Tint.pink,
                    badge: nil
                )
                disclosureRow(
                    title: "Cleanup",
                    icon: "trash.slash",
                    isExpanded: $cleanupExpanded,
                    categories: Self.cleanupCategories
                )
                disclosureRow(
                    title: "Developer Cleanup",
                    icon: "wrench.and.screwdriver",
                    isExpanded: $advancedToolsExpanded,
                    categories: Self.advancedCategories
                )
            } header: {
                sectionLabel("Free up space")
            }

            Section {
                navRow(
                    section: .apps,
                    label: "Uninstaller",
                    icon: "app.dashed",
                    tint: Tint.blue,
                    badge: appState.installedApps.isEmpty ? nil : "\(appState.installedApps.count)"
                )
                navRow(
                    section: .appUpdates,
                    label: "App Updates",
                    icon: "arrow.triangle.2.circlepath",
                    tint: Tint.accent,
                    badge: nil
                )
                navRow(
                    section: .orphans,
                    label: "Leftovers",
                    icon: "doc.questionmark",
                    tint: Tint.orange,
                    badge: appState.orphanedFiles.isEmpty ? nil : "\(appState.orphanedFiles.count)"
                )
                navRow(
                    section: .appleFeatures,
                    label: "Apple Features",
                    icon: "switch.2",
                    tint: Tint.accent,
                    badge: nil
                )
            } header: {
                sectionLabel("Apps")
            }
        }
        // Rebuild rows when the colour theme changes so every tint refreshes.
        .id(theme.themeID)
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 34)
        .scrollContentBackground(.hidden)
        .background(sidebarBackground)
        .navigationTitle("PureMac")
        .onMoveCommand(perform: moveSelection)
        .onChange(of: selectedSection) { section in
            guard case let .cleaning(category)? = section else { return }
            withAnimation(reduceMotion ? nil : MotionTokens.gentle) {
                if Self.cleanupCategories.contains(category) {
                    cleanupExpanded = true
                }
                if Self.advancedCategories.contains(category) {
                    advancedToolsExpanded = true
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarFooter
        }
    }

    private func disclosureRow(
        title: LocalizedStringKey,
        icon: String,
        isExpanded: Binding<Bool>,
        categories: [CleaningCategory]
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            ForEach(categories) { category in
                navRow(
                    section: .cleaning(category),
                    label: LocalizedStringKey(category.rawValue),
                    icon: category.icon,
                    tint: category.color,
                    badge: sizeBadge(for: category)
                )
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(sidebarLabelColor)
            }
            .frame(minHeight: 34)
            .contentShape(Rectangle())
        }
        .tint(.secondary)
        .listRowInsets(rowInsets)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 1, leading: 12, bottom: 1, trailing: 12)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typo.display(12, weight: .medium))
            .italic()
            .foregroundStyle(Tint.brass)
            .textCase(nil)
            .padding(.top, 4)
    }

    private func navRow(
        section: AppSection,
        label: LocalizedStringKey,
        icon: String,
        tint: Color,
        badge: String?,
        emphasized: Bool = false
    ) -> some View {
        Button {
            selectSection(section)
        } label: {
            SidebarNavRow(
                label: label,
                icon: icon,
                tint: tint,
                accent: Tint.accent,
                brass: Tint.brass,
                badge: badge,
                isSelected: selectedSection == section,
                emphasized: emphasized
            )
        }
        .buttonStyle(.plain)
        .focused($focusedSection, equals: section)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(accessibilityIdentifier(for: section))
        .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
        .listRowInsets(rowInsets)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var visibleSections: [AppSection] {
        var sections: [AppSection] = [
            .cleaning(.smartScan),
            .protection,
            .performance,
            .spaceExplorer,
            .duplicates,
            .similarPhotos
        ]
        if cleanupExpanded {
            sections.append(contentsOf: Self.cleanupCategories.map(AppSection.cleaning))
        }
        if advancedToolsExpanded {
            sections.append(contentsOf: Self.advancedCategories.map(AppSection.cleaning))
        }
        sections.append(contentsOf: [.apps, .appUpdates, .orphans, .appleFeatures])
        sections.append(.settings)
        return sections
    }

    private func selectSection(_ section: AppSection) {
        selectedSection = section
        focusedSection = section
    }

    private func accessibilityIdentifier(for section: AppSection) -> String {
        switch section {
        case .apps: return "sidebar.uninstaller"
        case .orphans: return "sidebar.leftovers"
        case .spaceExplorer: return "sidebar.spaceExplorer"
        case .duplicates: return "sidebar.duplicates"
        case .similarPhotos: return "sidebar.similarPhotos"
        case .protection: return "sidebar.protection"
        case .performance: return "sidebar.performance"
        case .appleFeatures: return "sidebar.appleFeatures"
        case .settings: return "sidebar.settings"
        case .appUpdates: return "sidebar.appUpdates"
        case .cleaning(let category): return "sidebar.cleaning.\(category.id)"
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        let sections = visibleSections
        guard !sections.isEmpty else { return }
        let current = focusedSection ?? selectedSection
        let currentIndex = current.flatMap(sections.firstIndex(of:))
        let targetIndex: Int

        switch direction {
        case .up:
            targetIndex = max(0, (currentIndex ?? sections.count) - 1)
        case .down:
            targetIndex = min(sections.count - 1, (currentIndex ?? -1) + 1)
        default:
            return
        }

        selectSection(sections[targetIndex])
    }

    private var dashboardBadge: String? {
        guard appState.totalJunkSize > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: appState.totalJunkSize, countStyle: .file)
    }

    private func sizeBadge(for category: CleaningCategory) -> String? {
        guard let size = appState.categoryResults[category]?.totalSize, size > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private var sidebarBackground: some View {
        Palette.sidebar
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(width: 0.5)
            }
            .ignoresSafeArea()
    }

    // MARK: - Footer

    private var usedFraction: Double {
        let total = appState.diskInfo.totalSpace
        guard total > 0 else { return 0 }
        return Double(max(0, total - appState.diskInfo.freeSpace)) / Double(total)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appState.diskInfo.totalSpace > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Storage")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: String(localized: "%@ free"), appState.diskInfo.formattedFree))
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                    }
                    GildedProgressBar(
                        value: usedFraction,
                        height: 4,
                        tint: usedFraction >= 0.9 ? Tint.orange : Tint.accent,
                        showsSheen: false
                    )
                }
            }

            HStack(spacing: 4) {
                Button {
                    selectSection(.settings)
                } label: {
                    SidebarNavRow(
                        label: "Settings",
                        icon: "gearshape",
                        tint: Tint.accent,
                        accent: Tint.accent,
                        brass: Tint.brass,
                        badge: nil,
                        isSelected: selectedSection == .settings,
                        emphasized: false
                    )
                }
                .buttonStyle(.plain)
                .focused($focusedSection, equals: .settings)
                .accessibilityIdentifier("sidebar.settings")
                .accessibilityAddTraits(selectedSection == .settings ? .isSelected : [])

                Button {
                    showAppearance.toggle()
                } label: {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Color theme and appearance")
                .accessibilityLabel("Color theme and appearance")
                .popover(isPresented: $showAppearance, arrowEdge: .top) {
                    AppearancePanel()
                        .environmentObject(theme)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Palette.sidebar)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
        }
    }

    private var sidebarLabelColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.90) : Color.black.opacity(0.82)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContainer: some View {
        VStack(spacing: 0) {
            if selectedSection != .settings && !appState.hasFullDiskAccess && !appState.fdaBannerDismissed {
                accessBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
            detailView
                .id(selectedSection)
                .id(theme.themeID)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
        }
        .animation(reduceMotion ? nil : MotionTokens.settle, value: selectedSection)
        .animation(reduceMotion ? nil : MotionTokens.gentle, value: appState.fdaBannerDismissed)
        .animation(reduceMotion ? nil : MotionTokens.gentle, value: appState.hasFullDiskAccess)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AmbientBackdrop())
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .apps:
            AppListView()
        case .orphans:
            OrphanListView()
        case .spaceExplorer:
            SpaceExplorerView()
        case .duplicates:
            DuplicateFinderView()
        case .similarPhotos:
            SimilarPhotosView()
        case .protection:
            ProtectionView()
        case .performance:
            PerformanceView()
        case .appleFeatures:
            AppleFeaturesView()
        case .appUpdates:
            AppUpdatesView()
        case .settings:
            SettingsView()
        case .cleaning(let category):
            if category == .smartScan {
                DashboardView { selectSection($0) }
            } else {
                CategoryDetailView(category: category)
            }
        case nil:
            EmptyStateView(
                "PureMac",
                systemImage: "internaldrive",
                description: "Select a tool from the sidebar."
            )
        }
    }

    private var accessBanner: some View {
        HStack(spacing: 12) {
            IconTile(systemName: "lock.shield", tint: Tint.orange, size: 32, corner: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("Full Disk Access is off")
                    .font(.system(size: 13, weight: .semibold))
                Text("Protected caches and app containers will be skipped.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Set up") {
                permission.requestAccess(context: .general) {
                    appState.checkFullDiskAccess()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(Tint.accent)
            Button {
                appState.fdaBannerDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Tint.orange.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Tint.orange.opacity(0.22), lineWidth: 0.5)
        }
    }
}

// MARK: - Sidebar row

private struct SidebarNavRow: View {
    let label: LocalizedStringKey
    let icon: String
    let tint: Color
    let accent: Color
    let brass: Color
    let badge: String?
    let isSelected: Bool
    let emphasized: Bool

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? accent : .secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 13, weight: isSelected || emphasized ? .semibold : .regular))
                .foregroundStyle(labelColor)
                .lineLimit(1)
            Spacer(minLength: 5)
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? accent : .secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowFill)
        }
        .overlay(alignment: .leading) {
            // Brass marker: grows from the centre when the row is selected.
            Capsule()
                .fill(brass)
                .frame(width: 2.5, height: 16)
                .scaleEffect(y: isSelected ? 1 : 0.1, anchor: .center)
                .opacity(isSelected ? 1 : 0)
                .offset(x: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(reduceMotion ? nil : MotionTokens.snappy, value: hovering)
        .animation(reduceMotion ? nil : MotionTokens.snappy, value: isSelected)
        .onHover { hovering = $0 }
    }

    private var rowFill: Color {
        if isSelected {
            return accent.opacity(colorScheme == .dark ? 0.20 : 0.11)
        }
        if hovering {
            return Color.primary.opacity(0.045)
        }
        return .clear
    }

    private var labelColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.91) : Color.black.opacity(0.82)
    }
}
