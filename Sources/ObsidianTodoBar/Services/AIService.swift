import Foundation

enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case noAPIKey
    case httpError(Int)
    case noResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL API"
        case .noAPIKey: return "API ключ не настроен"
        case .httpError(let code): return "Ошибка HTTP: \(code)"
        case .noResponse: return "Пустой ответ от AI"
        case .decodingFailed: return "Ошибка разбора ответа от AI"
        }
    }
}

struct AIService {
    let config: AppConfig

    func generateNotification(prompt: String) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }

        guard let url = URL(string: config.baseURL + "/chat/completions") else {
            throw AIServiceError.invalidURL
        }

        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": prompt]
            ],
            "max_tokens": 200,
            "temperature": 0.8
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.noResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.httpError(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AIServiceError.decodingFailed
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIServiceError.noResponse
        }

        return trimmed
    }
}
