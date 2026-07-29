// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// MathLive + WKWebView 公式输入编辑器，对应原版 MathRichEditBox 的角色。
// 本地打包 MathLive 0.110.0（MathLiveAssets/：mathlive.min.js + KaTeX 字体 +
// mathfield.html），离线加载；编辑时把 LaTeX 与 ASCIIMath 双格式回传 Swift，
// ASCIIMath 归一化后交 GraphExpression/Giac 解析。

import SwiftUI
import WebKit

struct MathInputField: NSViewRepresentable {
    /// 初始 LaTeX（仅加载时写入一次；后续以编辑器为准，避免循环回写打断输入法）。
    let initialLatex: String
    /// 编辑回调：(归一化 ASCIIMath, LaTeX)。
    let onChange: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(initialLatex: initialLatex, onChange: onChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "mathInput")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // 透明背景，融入行背景色。
        webView.setValue(false, forKey: "drawsBackground")
        if let url = Bundle.module.url(
            forResource: "mathfield", withExtension: "html", subdirectory: "MathLiveAssets") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "mathInput")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private let initialLatex: String
        private let onChange: (String, String) -> Void

        init(initialLatex: String, onChange: @escaping (String, String) -> Void) {
            self.initialLatex = initialLatex
            self.onChange = onChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !initialLatex.isEmpty,
                  let json = try? JSONEncoder().encode(initialLatex),
                  let literal = String(data: json, encoding: .utf8) else { return }
            webView.evaluateJavaScript("setLatexValue(\(literal))")
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let latex = body["latex"] as? String,
                  let ascii = body["ascii"] as? String else { return }
            onChange(MathInputField.normalizeAsciiMath(ascii), latex)
        }
    }

    /// 把 MathLive 的 ASCIIMath 输出归一化为计算器输入语法。
    static func normalizeAsciiMath(_ s: String) -> String {
        var t = s
        // Unicode 运算符 → ASCII。
        for (from, to) in [
            ("⋅", "*"), ("·", "*"), ("×", "*"), ("÷", "/"),
            ("−", "-"), ("√", "sqrt"), ("π", "pi"),
        ] {
            t = t.replacingOccurrences(of: from, with: to)
        }
        // ASCIIMath 记号差异。
        t = t.replacingOccurrences(of: "**", with: "^")
        return t.trimmingCharacters(in: .whitespaces)
    }
}
