import Foundation
import SwiftUI

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
}

@MainActor
class AppState: ObservableObject {
    @Published var metrics = PacingMetrics()
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String? = nil
    
    @AppStorage("baseURL") var baseURL: String = ""
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("userId") var userId: String = "eb4b261d-783f-45b5-b1f9-36628392d13a"
    
    // UI Settings
    @AppStorage("isDarkMode") var isDarkMode: Bool = true
    @AppStorage("useGlassEffect") var useGlassEffect: Bool = true
    
    func refresh() {
        guard !baseURL.isEmpty, !apiKey.isEmpty, !userId.isEmpty else {
            errorMessage = "Please configure Base URL, API Key, and User ID in Settings."
            return
        }
        
        isRefreshing = true
        errorMessage = nil
        
        let cleanedBaseURL = baseURL.replacingOccurrences(of: "/v1", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        Task {
            do {
                let metrics = try await LiteLLMAPI.fetchMetrics(baseURL: cleanedBaseURL, apiKey: apiKey, userId: userId)
                DispatchQueue.main.async {
                    self.metrics = metrics
                    self.isRefreshing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isRefreshing = false
                }
            }
        }
    }
}

class LiteLLMAPI {
    enum APIError: Error, LocalizedError {
        case invalidURL
        case networkError(String)
        case decodeError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid Base URL"
            case .networkError(let msg): return "Network Error: \(msg)"
            case .decodeError: return "Failed to decode response"
            }
        }
    }
    
    static func fetchMetrics(baseURL: String, apiKey: String, userId: String) async throws -> PacingMetrics {
        guard let url = URL(string: "\(baseURL)/user/info?user_id=\(userId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.networkError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodeError
        }
        
        let info = json["user_info"] as? [String: Any] ?? json
        
        let spend = info["spend"] as? Double ?? 0.0
        let maxBudgetRaw = info["max_budget"]
        var maxBudget: Double? = nil
        if let maxB = maxBudgetRaw as? Double {
            maxBudget = maxB
        } else if let maxStr = maxBudgetRaw as? String, let maxB = Double(maxStr) {
            maxBudget = maxB
        }
        
        let resetAt = info["budget_reset_at"] as? String
        let duration = info["budget_duration"] as? String ?? "30d"
        
        // Fetch Today's Activity
        var todaysSpend = 0.0
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let todayStr = formatter.string(from: Date())
        
        if let actUrl = URL(string: "\(baseURL)/user/daily/activity?user_id=\(userId)&start_date=\(todayStr)&end_date=\(todayStr)") {
            var actReq = URLRequest(url: actUrl)
            actReq.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            if let (actData, actResp) = try? await URLSession.shared.data(for: actReq),
               let actHttpResp = actResp as? HTTPURLResponse, actHttpResp.statusCode == 200,
               let actJson = try? JSONSerialization.jsonObject(with: actData) as? [String: Any],
               let results = actJson["results"] as? [[String: Any]], !results.isEmpty,
               let metrics = results[0]["metrics"] as? [String: Any],
               let tSpend = metrics["spend"] as? Double {
                todaysSpend = tSpend
            }
        }
        
        // Calculations
        var daysToReset = 1
        var totalCycleDays = 30
        
        let durationStr = duration.replacingOccurrences(of: "d", with: "")
        if let d = Int(durationStr) { totalCycleDays = d }
        
        if let resetAtStr = resetAt {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let resetDate = isoFormatter.date(from: resetAtStr.replacingOccurrences(of: "Z", with: ".000Z")) ?? ISO8601DateFormatter().date(from: resetAtStr) {
                let diff = Calendar.current.dateComponents([.day], from: Date(), to: resetDate).day ?? 1
                daysToReset = max(1, diff)
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
        let syncTime = outFormatter.string(from: Date())
        
        return PacingMetrics(
            userId: userId,
            syncTime: syncTime,
            todaysSpend: todaysSpend,
            spend: spend,
            maxBudget: maxBudget,
            burnPercent: burnPercent,
            avgSpendPerDay: avgSpendPerDay,
            dailySpendLeft: dailySpendLeft,
            daysToReset: daysToReset
        )
    }
}
