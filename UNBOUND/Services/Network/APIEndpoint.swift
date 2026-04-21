import Foundation

struct APIEndpoint {
    let url: URL
    let method: String
    let body: Data?
    let timeout: TimeInterval

    static func analyzeBody(scanId: String, userId: String) -> APIEndpoint {
        let body = try? JSONSerialization.data(withJSONObject: ["scanId": scanId, "userId": userId])
        return APIEndpoint(
            url: URL(string: AppConstants.API.analyzeBodyURL)!,
            method: "POST",
            body: body,
            timeout: AppConstants.Limits.analysisTimeoutSeconds
        )
    }

    static func generateProgram(analysisId: String, userId: String, preferences: [[String: Any]]? = nil, workingWeights: [[String: Any]]? = nil, recentLogs: [[String: Any]]? = nil) -> APIEndpoint {
        var payload: [String: Any] = ["analysisId": analysisId, "userId": userId]
        if let preferences { payload["exercisePreferences"] = preferences }
        if let workingWeights { payload["workingWeights"] = workingWeights }
        if let recentLogs { payload["recentLogs"] = recentLogs }
        let body = try? JSONSerialization.data(withJSONObject: payload)
        return APIEndpoint(
            url: URL(string: AppConstants.API.generateProgramURL)!,
            method: "POST",
            body: body,
            timeout: AppConstants.Limits.analysisTimeoutSeconds
        )
    }
}
