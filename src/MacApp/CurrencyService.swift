// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 汇率数据源。原版 CurrencyHttpClient 依赖微软内部 API（开源版被 Mock），
// 这里按项目决策改用开源免费数据源：
//   - 主源：fawazahmed0 currency-api（jsDelivr CDN，无需 key）
//     https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json
//     格式：{ "date": "YYYY-MM-DD", "usd": { "eur": 0.87, "jpy": 163.7, ... } }
//   - 兜底：Frankfurter（欧洲央行数据）
//     https://api.frankfurter.dev/v1/latest?base=USD
//     格式：{ "amount":1, "base":"USD", "date":"YYYY-MM-DD", "rates": { "EUR":0.87, ... } }
// 汇率均以 USD 为基准（rates[x] = 1 USD 可兑换的 x 数量）。
// 结果写入本地缓存，离线或请求失败时回退到缓存。

import Foundation

struct CurrencyRates: Codable {
    /// 基准货币代码（统一为 "USD"）。
    let base: String
    /// 数据日期（YYYY-MM-DD）。
    let date: String
    /// 大写货币代码 → 1 USD 可兑换的该货币数量。
    let rates: [String: Double]
}

enum CurrencyService {
    private static let fawazURL = URL(string: "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json")!
    private static let frankfurterURL = URL(string: "https://api.frankfurter.dev/v1/latest?base=USD")!

    /// 获取最新汇率：优先网络（主源→兜底），失败回退本地缓存。
    static func loadRates() async -> CurrencyRates? {
        if let fresh = await fetchFromNetwork() {
            saveCache(fresh)
            return fresh
        }
        return loadCache()
    }

    /// 仅刷新网络数据（供手动刷新按钮使用）。失败返回 nil。
    static func refreshFromNetwork() async -> CurrencyRates? {
        if let fresh = await fetchFromNetwork() {
            saveCache(fresh)
            return fresh
        }
        return nil
    }

    // MARK: - 网络

    private static func fetchFromNetwork() async -> CurrencyRates? {
        if let r = await fetchFawaz() { return r }
        if let r = await fetchFrankfurter() { return r }
        return nil
    }

    private static func fetchFawaz() async -> CurrencyRates? {
        guard let data = try? await fetch(fawazURL) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let date = json["date"] as? String ?? ""
        guard let usd = json["usd"] as? [String: Any] else { return nil }
        var rates: [String: Double] = ["USD": 1.0]
        for (code, value) in usd {
            if let d = (value as? Double) ?? (value as? NSNumber)?.doubleValue {
                rates[code.uppercased()] = d
            }
        }
        guard rates.count > 1 else { return nil }
        return CurrencyRates(base: "USD", date: date, rates: rates)
    }

    private static func fetchFrankfurter() async -> CurrencyRates? {
        guard let data = try? await fetch(frankfurterURL) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let date = json["date"] as? String ?? ""
        guard let ratesRaw = json["rates"] as? [String: Any] else { return nil }
        var rates: [String: Double] = ["USD": 1.0]
        for (code, value) in ratesRaw {
            if let d = (value as? Double) ?? (value as? NSNumber)?.doubleValue {
                rates[code.uppercased()] = d
            }
        }
        guard rates.count > 1 else { return nil }
        return CurrencyRates(base: "USD", date: date, rates: rates)
    }

    private static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // MARK: - 本地缓存

    private static var cacheURL: URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let appDir = dir.appendingPathComponent("MacCalculator", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("currency_rates.json")
    }

    private static func saveCache(_ rates: CurrencyRates) {
        guard let url = cacheURL, let data = try? JSONEncoder().encode(rates) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func loadCache() -> CurrencyRates? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CurrencyRates.self, from: data)
    }
}
