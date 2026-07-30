#!/usr/bin/env swift
// 程序化生成 macOS 风格计算器应用图标（1024×1024 PNG）。
// 无外部素材依赖、可复现：CoreGraphics 绘制圆角方（squircle）底 + 显示条 + 键阵，
// 右列运算键取 Apple 计算器同款橙。产物交由 package_app.sh 转 .icns 并写入 bundle。
// 用法：swift Tools/make_appicon.swift <输出png路径>

import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Tools/appicon/icon_1024.png"
let S: CGFloat = 1024

guard let ctx = CGContext(
    data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("无法创建位图上下文")
}

func rc(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

// squircle 近似：macOS 图标圆角半径约为边长的 22.37%，四周留 ~10% 边距。
let inset: CGFloat = S * 0.086
let rect = CGRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)
let radius = rect.width * 0.2237

func roundedPath(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}

// 底：竖直渐变（顶浅银灰 → 底稍深灰），圆角裁剪。
ctx.saveGState()
ctx.addPath(roundedPath(rect, radius))
ctx.clip()
let grad = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [rc(246, 247, 249), rc(214, 217, 222)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
ctx.restoreGState()

// 内层容器（键盘面板），略暗于底，营造层次。
let pad = rect.width * 0.11
let panel = rect.insetBy(dx: pad, dy: pad)

// 显示条（顶部深色圆角条）。
let dispH = panel.height * 0.20
let disp = CGRect(x: panel.minX, y: panel.maxY - dispH, width: panel.width, height: dispH)
ctx.addPath(roundedPath(disp, dispH * 0.22))
ctx.setFillColor(rc(38, 40, 46))
ctx.fillPath()

// 显示条内的示意数字（右对齐的浅色圆点条，避免依赖字体）。
let digitH = disp.height * 0.30
let digitY = disp.minY + (disp.height - digitH) / 2
var dx = disp.maxX - disp.width * 0.06
for i in 0..<4 {
    let w = digitH * (i == 0 ? 0.30 : 0.62)
    dx -= w
    let d = CGRect(x: dx, y: digitY, width: w, height: digitH)
    ctx.addPath(roundedPath(d, w * 0.28))
    ctx.setFillColor(rc(150, 154, 162, i == 0 ? 0.9 : 0.7))
    ctx.fillPath()
    dx -= digitH * 0.34
}

// 键阵：4 列 × 4 行，右列橙色（运算键），其余浅灰。
let cols = 4, rows = 4
let gridTop = disp.minY - panel.height * 0.05
let gridBottom = panel.minY
let gridH = gridTop - gridBottom
let gap = panel.width * 0.055
let keyW = (panel.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
let keyH = (gridH - gap * CGFloat(rows - 1)) / CGFloat(rows)
let keyR = min(keyW, keyH) * 0.30

for row in 0..<rows {
    for col in 0..<cols {
        let x = panel.minX + CGFloat(col) * (keyW + gap)
        let y = gridBottom + CGFloat(row) * (keyH + gap)
        let k = CGRect(x: x, y: y, width: keyW, height: keyH)
        ctx.addPath(roundedPath(k, keyR))
        if col == cols - 1 {
            ctx.setFillColor(rc(255, 149, 0))          // Apple 计算器橙
        } else {
            ctx.setFillColor(rc(252, 252, 253))         // 浅灰白键
        }
        ctx.fillPath()
    }
}

guard let img = ctx.makeImage() else { fatalError("makeImage 失败") }
let rep = NSBitmapImageRep(cgImage: img)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("PNG 编码失败") }
let url = URL(fileURLWithPath: outPath)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try! png.write(to: url)
print("wrote \(outPath)")
