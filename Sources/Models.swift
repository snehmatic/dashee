import Foundation
import SwiftUI
import UserNotifications

struct ModelPricing: Identifiable, Equatable {
    let id = UUID()
    let modelName: String
    let provider: String
    let inputCost: Double
    let outputCost: Double
    var totalCost: Double { inputCost + outputCost }
}

struct DailySpend: Identifiable {
    let id = UUID()
    let date: Date
    let spend: Double
}

struct PacingMetrics {
    var userId: String = "Unknown"
    var syncTime: String = "Never"
    var todaysSpend: Double = 0.0
    var spend: Double = 0.0
    var maxBudget: Double? = nil
    var burnPercent: Double = 0.0
    var avgSpendPerDay: Double = 0.0
    var dailySpendLeft: Double = 0.0
    var daysToReset: Int = 1
    var history: [DailySpend] = []
}

@MainActor
class AppState: ObservableObject {
    @Published var metrics = PacingMetrics()
    @Published var availableModels: [ModelPricing] = []
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String? = nil
    
    @AppStorage("baseURL") var baseURL: String = ""
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("userId") var userId: String = "eb4b261d-783f-45b5-b1f9-36628392d13a"
    
    // UI Settings
    @AppStorage("isDarkMode") var isDarkMode: Bool = true
    @AppStorage("useGlassEffect") var useGlassEffect: Bool = true
    
    // Alerts & Background
    @AppStorage("autoRefreshInterval") var autoRefreshInterval: Double = 15.0 // Minutes
    @AppStorage("alertThreshold") var alertThreshold: Double = 1.2 // 120% of daily spend
    @AppStorage("currencySymbol") var currencySymbol: String = "$"
    
    private var refreshTimer: Timer?
    
    init() {
        requestNotificationPermission()
        setupTimer()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in }
    }
    
    func setupTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(isBackground: true)
            }
        }
    }
    
    func checkAndNotifySpike(metrics: PacingMetrics) {
        if metrics.dailySpendLeft > 0 && metrics.todaysSpend > (metrics.dailySpendLeft * alertThreshold) {
            let percentStr = String(format: "%.0f", alertThreshold * 100)
            let content = UNMutableNotificationContent()
            content.title = "Budget Spike Detected!"
            content.body = "You have spent \(currencySymbol)\(String(format: "%.2f", metrics.todaysSpend)) today, which is over \(percentStr)% of your daily allowance (\(currencySymbol)\(String(format: "%.2f", metrics.dailySpendLeft)))."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "spike_warning_\(Date().timeIntervalSince1970)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func refresh(isBackground: Bool = false) {
        guard !baseURL.isEmpty, !apiKey.isEmpty, !userId.isEmpty else {
            errorMessage = "Please configure Base URL, API Key, and User ID in Settings."
            return
        }
        
        if !isBackground {
            isRefreshing = true
        }
        errorMessage = nil
        
        let cleanedBaseURL = baseURL.replacingOccurrences(of: "/v1", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        Task {
            do {
                async let newMetricsTask = LiteLLMAPI.fetchMetrics(baseURL: cleanedBaseURL, apiKey: apiKey, userId: userId)
                async let newModelsTask = LiteLLMAPI.fetchModels(baseURL: cleanedBaseURL, apiKey: apiKey)
                
                let (newMetrics, newModels) = try await (newMetricsTask, newModelsTask)
                
                DispatchQueue.main.async {
                    self.metrics = newMetrics
                    self.availableModels = newModels
                    if !isBackground {
                        self.isRefreshing = false
                    }
                    self.checkAndNotifySpike(metrics: newMetrics)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    if !isBackground {
                        self.isRefreshing = false
                    }
                }
            }
        }
    }
}

class LiteLLMAPI {
    enum APIError: Error, LocalizedError {
        case invalidURL, decodeError
        case networkError(String)
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid Base URL"
            case .networkError(let msg): return "Network Error: \(msg)"
            case .decodeError: return "Failed to decode response"
            }
        }
    }
    
    static func fetchMetrics(baseURL: String, apiKey: String, userId: String) async throws -> PacingMetrics {
        guard let url = URL(string: "\(baseURL)/user/info?user_id=\(userId)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.networkError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.decodeError }
        let info = json["user_info"] as? [String: Any] ?? json
        let spend = info["spend"] as? Double ?? 0.0
        
        let maxBudgetRaw = info["max_budget"]
        var maxBudget: Double? = nil
        if let maxB = maxBudgetRaw as? Double { maxBudget = maxB } 
        else if let maxStr = maxBudgetRaw as? String, let maxB = Double(maxStr) { maxBudget = maxB }
        
        let resetAt = info["budget_reset_at"] as? String
        let duration = info["budget_duration"] as? String ?? "30d"
        
        // Fetch 7-Day Activity History
        var todaysSpend = 0.0
        var history: [DailySpend] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        let todayStr = formatter.string(from: Date())
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        let startStr = formatter.string(from: sevenDaysAgo)
        
        if let actUrl = URL(string: "\(baseURL)/user/daily/activity?user_id=\(userId)&start_date=\(startStr)&end_date=\(todayStr)") {
            var actReq = URLRequest(url: actUrl)
            actReq.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            if let (actData, actResp) = try? await URLSession.shared.data(for: actReq),
               let actHttpResp = actResp as? HTTPURLResponse, actHttpResp.statusCode == 200,
               let actJson = try? JSONSerialization.jsonObject(with: actData) as? [String: Any],
               let results = actJson["results"] as? [[String: Any]] {
               
               for result in results {
                   if let dateStr = result["date"] as? String, let date = formatter.date(from: dateStr),
                      let metrics = result["metrics"] as? [String: Any], let dSpend = metrics["spend"] as? Double {
                       history.append(DailySpend(date: date, spend: dSpend))
                       if dateStr == todayStr { todaysSpend = dSpend }
                   }
               }
            }
        }
        history.sort(by: { $0.date < $1.date })
        
        var daysToReset = 1
        var totalCycleDays = 30
        if let d = Int(duration.replacingOccurrences(of: "d", with: "")) { totalCycleDays = d }
        if let resetAtStr = resetAt {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let resetDate = isoFormatter.date(from: resetAtStr.replacingOccurrences(of: "Z", with: ".000Z")) ?? ISO8601DateFormatter().date(from: resetAtStr) {
                daysToReset = max(1, Calendar.current.dateComponents([.day], from: Date(), to: resetDate).day ?? 1)
            }
        }
        
        let daysElapsed = max(1, totalCycleDays - daysToReset)
        let avgSpendPerDay = spend / Double(daysElapsed)
        var burnPercent = 0.0
        var dailySpendLeft = 0.0
        
        if let maxB = maxBudget, maxB > 0 {
            burnPercent = (spend / maxB) * 100.0
            dailySpendLeft = max(0, (maxB - spend) / Double(daysToReset))
        }
        
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        outFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        return PacingMetrics(userId: userId, syncTime: outFormatter.string(from: Date()), todaysSpend: todaysSpend, spend: spend, maxBudget: maxBudget, burnPercent: burnPercent, avgSpendPerDay: avgSpendPerDay, dailySpendLeft: dailySpendLeft, daysToReset: daysToReset, history: history)
    }

    static func fetchModels(baseURL: String, apiKey: String) async throws -> [ModelPricing] {
        guard let url = URL(string: "\(baseURL)/model/info") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.networkError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw APIError.decodeError
        }
        
        var models: [ModelPricing] = []
        for item in dataArray {
            let modelName = item["model_name"] as? String ?? "Unknown"
            
            var provider = "Unknown"
            if let params = item["litellm_params"] as? [String: Any],
               let modelString = params["model"] as? String {
                let parts = modelString.split(separator: "/")
                if parts.count > 1 {
                    provider = String(parts[0]).capitalized
                } else {
                    provider = "LiteLLM"
                }
            } else if let info = item["model_info"] as? [String: Any], let baseModel = info["base_model"] as? String {
                 let parts = baseModel.split(separator: "/")
                if parts.count > 1 {
                    provider = String(parts[0]).capitalized
                } else {
                     provider = "LiteLLM"
                }
            }
            
            var inCost = 0.0
            var outCost = 0.0
            
            if let info = item["model_info"] as? [String: Any] {
                if let iC = info["input_cost_per_token"] as? Double { inCost = iC }
                if let oC = info["output_cost_per_token"] as? Double { outCost = oC }
            }
            
            models.append(ModelPricing(modelName: modelName, provider: provider, inputCost: inCost, outputCost: outCost))
        }
        
        return models.sorted(by: { $0.totalCost < $1.totalCost })
    }
}
