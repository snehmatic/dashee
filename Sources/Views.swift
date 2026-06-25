import SwiftUI
import Charts

struct GlassCard<Content: View>: View {
    @EnvironmentObject var appState: AppState
    var title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if appState.useGlassEffect {
                    VisualEffectView(material: appState.isDarkMode ? .hudWindow : .popover, blendingMode: .withinWindow)
                } else {
                    Color.secondary.opacity(0.1)
                }
            }
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct MetricCard: View {
    var title: String
    var value: String
    var isWarning: Bool = false
    
    var body: some View {
        GlassCard(title: title) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(isWarning ? .red : .primary)
        }
    }
}

// macOS Visual Effect Wrapper for the perfect Liquid Glass
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    @State private var hoveredDate: Date? = nil
    
    var progressColor: Color {
        let p = appState.metrics.burnPercent
        if p >= 90 { return .red }
        if p >= 75 { return .yellow }
        return .green
    }
    
    var body: some View {
        ZStack {
            // App Background
            if appState.useGlassEffect {
                VisualEffectView(material: appState.isDarkMode ? .underWindowBackground : .windowBackground, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            } else {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dashee")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("User: \(appState.metrics.userId)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text("Last Sync: \(appState.metrics.syncTime)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                Text("Settings")
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(8)
                            
                            Button(action: { appState.refresh() }) {
                                HStack {
                                    if appState.isRefreshing {
                                        ProgressView()
                                            .controlSize(.small)
                                            .colorInvert()
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(appState.isRefreshing ? "Refreshing..." : "Refresh")
                                }
                                .frame(width: 110)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(appState.isRefreshing)
                        }
                    }
                    
                    if let err = appState.errorMessage {
                        Text(err)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Primary Metrics
                    HStack(spacing: 20) {
                        MetricCard(title: "TODAY'S SPEND", 
                                   value: String(format: "$%.2f", appState.metrics.todaysSpend),
                                   isWarning: appState.metrics.todaysSpend > appState.metrics.dailySpendLeft && appState.metrics.dailySpendLeft > 0)
                        
                        MetricCard(title: "TOTAL SPENT", 
                                   value: String(format: "$%.2f", appState.metrics.spend))
                        
                        MetricCard(title: "MAX BUDGET", 
                                   value: appState.metrics.maxBudget != nil ? String(format: "$%.2f", appState.metrics.maxBudget!) : "No Limit")
                    }
                    
                    // Budget Pacing
                    GlassCard(title: "BUDGET BURN PROGRESS") {
                        VStack(alignment: .leading, spacing: 12) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 12)
                                    
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(progressColor)
                                        .frame(width: min(CGFloat(appState.metrics.burnPercent / 100.0) * geometry.size.width, geometry.size.width), height: 12)
                                        .animation(.spring(), value: appState.metrics.burnPercent)
                                }
                            }
                            .frame(height: 12)
                            
                            let mbStr = appState.metrics.maxBudget != nil ? String(format: "$%.2f", appState.metrics.maxBudget!) : "No Limit"
                            Text("\(String(format: "%.1f", appState.metrics.burnPercent))% ($\(String(format: "%.2f", appState.metrics.spend)) / \(mbStr)) • \(appState.metrics.daysToReset) days to reset")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Velocity Panel
                    HStack(spacing: 20) {
                        MetricCard(title: "AVG SPEND / DAY", 
                                   value: String(format: "$%.2f", appState.metrics.avgSpendPerDay))
                        
                        MetricCard(title: "ALLOWED SPEND / DAY", 
                                   value: String(format: "$%.2f", appState.metrics.dailySpendLeft))
                    }
                    
                    if !appState.metrics.history.isEmpty {
                        GlassCard(title: "7-DAY SPEND TREND") {
                            Chart {
                                ForEach(appState.metrics.history) { point in
                                    BarMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("Spend", point.spend)
                                    )
                                    .foregroundStyle(Color.accentColor.gradient)
                                    .cornerRadius(4)
                                }
                                
                                if let hoveredDate {
                                    RuleMark(x: .value("Selected", hoveredDate, unit: .day))
                                        .foregroundStyle(Color.secondary.opacity(0.5))
                                        .annotation(position: .top) {
                                            if let point = appState.metrics.history.first(where: { Calendar.current.isDate($0.date, inSameDayAs: hoveredDate) }) {
                                                Text("$\(String(format: "%.2f", point.spend))")
                                                    .font(.caption.bold())
                                                    .padding(6)
                                                    .background(Color(NSColor.windowBackgroundColor))
                                                    .cornerRadius(6)
                                                    .shadow(radius: 3)
                                            }
                                        }
                                }
                            }
                            .frame(height: 120)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                }
                            }
                            .chartOverlay { proxy in
                                GeometryReader { geometry in
                                    Rectangle().fill(.clear).contentShape(Rectangle())
                                        .onContinuousHover { phase in
                                            switch phase {
                                            case .active(let location):
                                                let x = location.x - geometry[proxy.plotAreaFrame].origin.x
                                                if let date: Date = proxy.value(atX: x) {
                                                    // Snap to closest date in history
                                                    if let closest = appState.metrics.history.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                        hoveredDate = closest.date
                                                    }
                                                }
                                            case .ended:
                                                hoveredDate = nil
                                            }
                                        }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(30)
                .padding(.top, 20) // Extra padding to clear hidden title bar traffic lights
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .onAppear {
            if appState.baseURL.isEmpty {
                showingSettings = true
            } else {
                appState.refresh()
            }
        }
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
            
            Form {
                Section(header: Text("API Credentials")) {
                    TextField("Base URL", text: $appState.baseURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    SecureField("API Key", text: $appState.apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("User ID", text: $appState.userId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Divider().padding(.vertical, 8)
                
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $appState.isDarkMode)
                    Toggle("Liquid Glass / Transparency Effect", isOn: $appState.useGlassEffect)
                }
            }
            .padding()
            
            HStack {
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                    appState.refresh()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}

struct MenuBarWidgetView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) var openWindow
    
    var progressColor: Color {
        let p = appState.metrics.burnPercent
        if p >= 90 { return .red }
        if p >= 75 { return .yellow }
        return .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Dashee Status")
                    .font(.headline)
                Spacer()
                Button(action: { appState.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(Angle(degrees: appState.isRefreshing ? 360 : 0))
                }
                .buttonStyle(.plain)
                .disabled(appState.isRefreshing)
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("TODAY'S SPEND")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        let isOver = appState.metrics.todaysSpend > appState.metrics.dailySpendLeft && appState.metrics.dailySpendLeft > 0
                        Text(String(format: "$%.2f", appState.metrics.todaysSpend))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(isOver ? .red : .primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("ALLOWED / DAY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(String(format: "$%.2f", appState.metrics.dailySpendLeft))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("BUDGET BURN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", appState.metrics.burnPercent))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(progressColor)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor)
                                .frame(width: min(CGFloat(appState.metrics.burnPercent / 100.0) * geometry.size.width, geometry.size.width), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            
            HStack {
                Button("Open Dashboard") {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.caption2.bold())
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundColor(.red)
            }
        }
        .padding(20)
        .frame(width: 280)
        // Match the user's selected mode
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
    }
}

@main
struct DasheeApp: App {
    @StateObject var appState = AppState()
    
    var body: some Scene {
        Window("Dashee", id: "dashboard") {
            DashboardView()
                .environmentObject(appState)
                .frame(minWidth: 700, minHeight: 650)
                .background(Color.clear)
        }
        .windowStyle(.hiddenTitleBar)
        
        MenuBarExtra("Dashee", systemImage: "bolt.fill") {
            MenuBarWidgetView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
