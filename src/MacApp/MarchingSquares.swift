// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Marching Squares：隐式方程 F(x,y)=0 的等值线追踪。
// 在视窗上按网格采样 F 的符号，逐格用线性插值求 F=0 与格边的交点，
// 产出数学坐标下的线段集合；渲染层再映射到屏幕。
// 鞍点格（4 个交点）用格中心采样消歧。

import Foundation

enum MarchingSquares {
    struct Segment {
        var x1: Double, y1: Double
        var x2: Double, y2: Double
    }

    /// 在 [xMin,xMax]×[yMin,yMax] 上以 cols×rows 网格追踪 f=0 等值线。
    static func trace(
        f: (Double, Double) -> Double?,
        xMin: Double, xMax: Double, yMin: Double, yMax: Double,
        cols: Int, rows: Int
    ) -> [Segment] {
        guard cols > 0, rows > 0, xMax > xMin, yMax > yMin else { return [] }
        let dx = (xMax - xMin) / Double(cols)
        let dy = (yMax - yMin) / Double(rows)

        // 采样网格节点值（nil = 未定义）。节点值恰为 0 时视作 +ε，
        // 避免零值落在节点上时产生 1/3 个交点的退化格。
        var grid = [[Double?]](repeating: [Double?](repeating: nil, count: cols + 1), count: rows + 1)
        for r in 0...rows {
            let y = yMin + Double(r) * dy
            for c in 0...cols {
                let v = f(xMin + Double(c) * dx, y)
                grid[r][c] = v.map { $0 == 0 ? .leastNonzeroMagnitude : $0 }
            }
        }

        var segments: [Segment] = []

        for r in 0..<rows {
            for c in 0..<cols {
                // 四角：bl(c,r) br(c+1,r) tr(c+1,r+1) tl(c,r+1)
                guard let bl = grid[r][c], let br = grid[r][c + 1],
                      let tr = grid[r + 1][c + 1], let tl = grid[r + 1][c]
                else { continue }

                let x0 = xMin + Double(c) * dx, x1 = x0 + dx
                let y0 = yMin + Double(r) * dy, y1 = y0 + dy

                // 各边的零交点（线性插值）。
                var pts: [(Double, Double)] = []
                if crosses(bl, br) { pts.append((interp(x0, x1, bl, br), y0)) } // 下边
                if crosses(br, tr) { pts.append((x1, interp(y0, y1, br, tr))) } // 右边
                if crosses(tl, tr) { pts.append((interp(x0, x1, tl, tr), y1)) } // 上边
                if crosses(bl, tl) { pts.append((x0, interp(y0, y1, bl, tl))) } // 左边

                switch pts.count {
                case 2:
                    segments.append(Segment(x1: pts[0].0, y1: pts[0].1, x2: pts[1].0, y2: pts[1].1))
                case 4:
                    // 鞍点：用格中心符号决定配对方式。
                    // pts 顺序固定为 [下, 右, 上, 左]。
                    let center = f((x0 + x1) / 2, (y0 + y1) / 2) ?? 0
                    let sameAsBL = (center > 0) == (bl > 0)
                    if sameAsBL {
                        // 中心与 bl 同侧：下-右、上-左
                        segments.append(Segment(x1: pts[0].0, y1: pts[0].1, x2: pts[1].0, y2: pts[1].1))
                        segments.append(Segment(x1: pts[2].0, y1: pts[2].1, x2: pts[3].0, y2: pts[3].1))
                    } else {
                        // 下-左、上-右
                        segments.append(Segment(x1: pts[0].0, y1: pts[0].1, x2: pts[3].0, y2: pts[3].1))
                        segments.append(Segment(x1: pts[2].0, y1: pts[2].1, x2: pts[1].0, y2: pts[1].1))
                    }
                default:
                    break
                }
            }
        }
        return segments
    }

    private static func crosses(_ a: Double, _ b: Double) -> Bool {
        (a > 0) != (b > 0)
    }

    /// 在 [p0,p1] 上按值 v0→v1 线性插值零点位置。
    private static func interp(_ p0: Double, _ p1: Double, _ v0: Double, _ v1: Double) -> Double {
        let denom = v1 - v0
        guard denom != 0 else { return (p0 + p1) / 2 }
        let t = -v0 / denom
        return p0 + max(0, min(1, t)) * (p1 - p0)
    }
}
