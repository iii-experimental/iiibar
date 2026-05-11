import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.24)
            HStack(alignment: .top, spacing: 0) {
                sidebar
                Divider().opacity(0.24)
                detailPane
            }
        }
        .frame(width: 660, height: 560)
        .background(shellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("iiiBar")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                    statusPill(state.status?.state ?? "unknown")
                }
                Text(state.headerSubtitle)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            endpointBadge
            Button {
                Task { await state.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(headerBackground)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            connectionCard
            VStack(alignment: .leading, spacing: 8) {
                label("Engines")
                ForEach(state.profiles) { profile in
                    profileRow(profile)
                }
            }
            quickActions
            Spacer()
        }
        .frame(width: 250)
        .padding(14)
    }

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                engineHero
                metricsGrid
                runtimeSection
                healthSection
                observabilitySection
                activitySection
                controlsSection
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusLine("Worker", state.workerRunning ? "running" : state.workerMessage, state.workerRunning ? "healthy" : "degraded")
            statusLine("Control", state.canCallIiiBarFunctions ? "connected" : "offline", state.canCallIiiBarFunctions ? "healthy" : "unreachable")
            statusLine("Engine", state.status?.reachable == true ? "reachable" : "unreachable", state.status?.state ?? "unknown")
        }
        .panelStyle(cardBackground)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Actions")
            HStack(spacing: 8) {
                actionButton("Worker", "bolt.fill") {
                    Task { await state.restartWorker() }
                }
                actionButton("Refresh", "arrow.clockwise") {
                    Task { await state.refreshAll() }
                }
            }
        }
    }

    private var engineHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(state.selectedProfile?.name ?? "Local iii Engine")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(endpoint(state.selectedProfile))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                statusPill(state.status?.state ?? "unknown")
            }
            if let message = state.status?.message ?? state.errorMessage {
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(state.canCallIiiBarFunctions ? secondaryText : BrandColors.alert)
                    .lineLimit(3)
            }
        }
        .panelStyle(heroBackground)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            metricTile("Instances", "\(state.runtime?.workerCount ?? state.status?.workers ?? 0)", "person.2.fill", (state.runtime?.workerCount ?? state.status?.workers ?? 0) > 0 ? BrandColors.success : BrandColors.medium)
            metricTile("Processes", "\(state.runtime?.processCount ?? 0)", "number", BrandColors.info)
            metricTile("CPU", formatPercent(state.runtime?.resources.cpuPercent), "speedometer", state.runtime?.resources.cpuPercent == nil ? BrandColors.medium : BrandColors.accent)
            metricTile("RAM", formatBytes(state.runtime?.resources.memoryRssBytes), "memorychip.fill", state.runtime?.resources.memoryRssBytes == nil ? BrandColors.medium : BrandColors.accentLight)
        }
    }

    private var runtimeSection: some View {
        section("Runtime") {
            HStack(spacing: 8) {
                miniMetric("Functions", "\(state.runtime?.functionCount ?? state.status?.functions ?? 0)")
                miniMetric("Triggers", "\(state.runtime?.triggerCount ?? state.status?.triggers ?? 0)")
                miniMetric("Active", "\(state.runtime?.activeInvocations ?? 0)")
                miniMetric("Uptime", formatDuration(state.runtime?.longestUptimeSeconds))
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(state.runtime?.endpoints ?? []) { endpoint in
                    endpointRow(endpoint)
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                let workers = Array((state.runtime?.workers ?? []).prefix(5))
                if workers.isEmpty {
                    emptyRow("No connected worker instances")
                } else {
                    ForEach(workers) { worker in
                        workerInstanceRow(worker)
                    }
                }
            }
            if state.runtime?.resources.metricsAvailable == false {
                Text("resource metrics unavailable")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondaryText)
            }
        }
    }

    private var healthSection: some View {
        section("Health") {
            let components = state.status?.components ?? [:]
            if components.isEmpty {
                emptyRow("No health components")
            } else {
                ForEach(components.keys.sorted(), id: \.self) { key in
                    statusLine(key, components[key] ?? "unknown", components[key] ?? "unknown")
                }
            }
        }
    }

    private var observabilitySection: some View {
        section("OTEL") {
            HStack(spacing: 8) {
                miniMetric("Calls", "\(state.telemetry?.invocations.total ?? 0)")
                miniMetric("Errors", "\(state.telemetry?.invocations.error ?? 0)")
                miniMetric("p95", String(format: "%.1fms", state.telemetry?.performance.p95DurationMs ?? 0))
                miniMetric("Slow", "\(state.telemetry?.slowTraces ?? 0)")
            }
            if let warning = state.telemetry?.warning {
                Text(warning)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BrandColors.warn)
                    .lineLimit(2)
            }
        }
    }

    private var activitySection: some View {
        section("Recent Activity") {
            let logs = Array((state.logs?.logs ?? []).prefix(3))
            let spans = Array((state.traces?.spans ?? []).prefix(3))
            if logs.isEmpty && spans.isEmpty {
                emptyRow("No logs or traces")
            }
            ForEach(logs) { log in
                activityRow(log.severityText ?? "INFO", log.body ?? "", statusColor(log.severityText == "ERROR" ? "error" : "unknown"))
            }
            ForEach(spans) { span in
                activityRow(span.status ?? "trace", span.name, statusColor(span.status ?? "unknown"))
            }
        }
    }

    private var controlsSection: some View {
        section("Controls") {
            HStack(spacing: 8) {
                actionButton("Start", "play.fill") {
                    Task { await state.startSelected() }
                }
                .disabled(!state.canCallIiiBarFunctions)
                actionButton("Stop", "stop.fill") {
                    Task { await state.stopSelected() }
                }
                .disabled(!state.canCallIiiBarFunctions)
                actionButton("Diagnostics", "doc.on.clipboard") {
                    Task { await state.copyDiagnostics() }
                }
                .disabled(!state.canCallIiiBarFunctions)
            }
            if let process = state.processState {
                statusLine("Process", process.message ?? (process.running ? "running" : "stopped"), process.running ? "running" : "stopped")
            }
        }
    }

    private var endpointBadge: some View {
        Text(state.controlEndpoint.replacingOccurrences(of: "ws://", with: ""))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(cardBackground)
            .clipShape(Capsule())
    }

    private func profileRow(_ profile: EngineProfile) -> some View {
        Button {
            state.selectedProfileId = profile.id
            Task { await state.refreshSelected() }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(state.selectedProfileId == profile.id ? statusColor(state.status?.state ?? "unknown") : BrandColors.medium)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    Text(endpoint(profile))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                if state.selectedProfileId == profile.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentColor)
                }
            }
            .padding(10)
            .background(state.selectedProfileId == profile.id ? selectedBackground : cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func metricTile(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func miniMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            label(title)
            content()
        }
        .panelStyle(cardBackground)
    }

    private func statusLine(_ title: String, _ value: String, _ status: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(secondaryText)
                .lineLimit(1)
        }
    }

    private func activityRow(_ tag: String, _ text: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(tag.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 48, alignment: .leading)
            Text(text.isEmpty ? "No message" : text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(primaryText)
                .lineLimit(2)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func endpointRow(_ endpoint: RuntimeEndpoint) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(endpoint.available == false ? BrandColors.medium : BrandColors.success)
                .frame(width: 6, height: 6)
            Text(endpoint.label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(secondaryText)
                .frame(width: 58, alignment: .leading)
            Text(endpoint.url)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(primaryText)
                .lineLimit(1)
            Spacer()
        }
    }

    private func workerInstanceRow(_ worker: RuntimeWorker) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(statusColor(worker.status))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(worker.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                Text(workerDetail(worker))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(worker.functionCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text("fn")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(secondaryText)
            }
        }
        .padding(8)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func statusPill(_ status: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 7, height: 7)
            Text(status)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor(status).opacity(0.14))
        .clipShape(Capsule())
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(secondaryText)
            .tracking(0)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private func endpoint(_ profile: EngineProfile?) -> String {
        guard let profile else { return state.controlEndpoint }
        return "ws://\(profile.host):\(String(profile.bridgePort))"
    }

    private func workerDetail(_ worker: RuntimeWorker) -> String {
        var parts: [String] = []
        if let runtime = worker.runtime {
            parts.append(runtime)
        }
        if let pid = worker.pid {
            parts.append("pid \(pid)")
        }
        if let ipAddress = worker.ipAddress {
            parts.append(ipAddress)
        }
        if let uptime = worker.uptimeSeconds {
            parts.append(formatDuration(uptime))
        }
        return parts.isEmpty ? worker.status : parts.joined(separator: " / ")
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f%%", value)
    }

    private func formatBytes(_ value: Double?) -> String {
        guard let value, value > 0 else { return "n/a" }
        let units = ["B", "KB", "MB", "GB"]
        var amount = value
        var index = 0
        while amount >= 1024, index < units.count - 1 {
            amount /= 1024
            index += 1
        }
        return String(format: index == 0 ? "%.0f %@" : "%.1f %@", amount, units[index])
    }

    private func formatDuration(_ seconds: Double?) -> String {
        guard let seconds else { return "n/a" }
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var shellBackground: some View {
        ZStack {
            backgroundColor
            LinearGradient(
                colors: [
                    BrandColors.success.opacity(colorScheme == .dark ? 0.12 : 0.08),
                    BrandColors.accentLight.opacity(colorScheme == .dark ? 0.10 : 0.06),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? BrandColors.black : BrandColors.light
    }

    private var headerBackground: Color {
        colorScheme == .dark ? BrandColors.dark.opacity(0.72) : Color.white.opacity(0.72)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? BrandColors.dark.opacity(0.72) : Color.white.opacity(0.84)
    }

    private var tileBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.05)
    }

    private var heroBackground: Color {
        state.canCallIiiBarFunctions ? cardBackground : BrandColors.alert.opacity(colorScheme == .dark ? 0.12 : 0.08)
    }

    private var selectedBackground: Color {
        colorScheme == .dark ? BrandColors.accentLight.opacity(0.32) : BrandColors.accentLight.opacity(0.16)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.12)
    }

    private var primaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.94) : BrandColors.dark
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.56) : BrandColors.medium
    }

    private var accentColor: Color {
        colorScheme == .dark ? BrandColors.accent : BrandColors.accentLight
    }
}

private extension View {
    func panelStyle(_ background: Color) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
