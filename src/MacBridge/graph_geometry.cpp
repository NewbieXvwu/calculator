// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// graph_geometry.cpp — S7 共享图形几何实现。
// 语义与 macOS 首发实现（GraphingView.swift / GraphingViewModel.swift /
// MarchingSquares.swift）逐行对齐，由 GraphGeometryTests 平价锁定。

#include "include/graph_geometry.h"

#include <algorithm>
#include <cfloat>
#include <cmath>
#include <vector>

namespace {

inline double x_span(const graph_viewport_t* vp) { return vp->x_max - vp->x_min; }
inline double y_span(const graph_viewport_t* vp) { return vp->y_max - vp->y_min; }

inline void emit_sample(graph_sample_t* out, size_t cap, size_t index,
                        double sx, double sy, bool move) {
    if (index < cap) out[index] = graph_sample_t{sx, sy, move};
}

inline void emit_segment(graph_segment_t* out, size_t cap, size_t index,
                         double x1, double y1, double x2, double y2) {
    if (index < cap) out[index] = graph_segment_t{x1, y1, x2, y2};
}

inline bool crosses(double a, double b) { return (a > 0) != (b > 0); }

// 在 [p0,p1] 上按值 v0→v1 线性插值零点，t 夹在 [0,1]。
inline double interp(double p0, double p1, double v0, double v1) {
    const double denom = v1 - v0;
    if (denom == 0) return (p0 + p1) / 2;
    const double t = -v0 / denom;
    return p0 + std::max(0.0, std::min(1.0, t)) * (p1 - p0);
}

}  // namespace

extern "C" {

// MARK: - 坐标变换

double graph_to_screen_x(const graph_viewport_t* vp, double x) {
    return (x - vp->x_min) / x_span(vp) * vp->width;
}

double graph_to_screen_y(const graph_viewport_t* vp, double y) {
    return vp->height - (y - vp->y_min) / y_span(vp) * vp->height;
}

double graph_to_math_x(const graph_viewport_t* vp, double sx) {
    return vp->x_min + sx / vp->width * x_span(vp);
}

double graph_to_math_y(const graph_viewport_t* vp, double sy) {
    return vp->y_min + (vp->height - sy) / vp->height * y_span(vp);
}

// MARK: - 刻度（1-2-5）

double graph_nice_step(double span, int target_ticks) {
    if (!(span > 0) || !std::isfinite(span) || target_ticks <= 0) return 0;
    const double rough = span / static_cast<double>(target_ticks);
    const double mag = std::pow(10.0, std::floor(std::log10(rough)));
    const double norm = rough / mag;
    double step;
    if (norm < 1.5) step = 1;
    else if (norm < 3) step = 2;
    else if (norm < 7) step = 5;
    else step = 10;
    return step * mag;
}

size_t graph_ticks(double range_min, double range_max, double step, double* out, size_t cap) {
    if (!(step > 0) || !std::isfinite(step) || !std::isfinite(range_min) || !std::isfinite(range_max)) return 0;
    size_t count = 0;
    double x = std::ceil(range_min / step) * step;
    while (x <= range_max) {
        if (out && count < cap) out[count] = x;
        ++count;
        x += step;
    }
    return count;
}

// MARK: - 视窗操作

void graph_pan(graph_viewport_t* vp, double dx_math, double dy_math) {
    vp->x_min -= dx_math;
    vp->x_max -= dx_math;
    vp->y_min -= dy_math;
    vp->y_max -= dy_math;
}

void graph_zoom(graph_viewport_t* vp, double factor) {
    const double cx = (vp->x_min + vp->x_max) / 2;
    const double cy = (vp->y_min + vp->y_max) / 2;
    const double hx = x_span(vp) / 2 * factor;
    const double hy = y_span(vp) / 2 * factor;
    vp->x_min = cx - hx;
    vp->x_max = cx + hx;
    vp->y_min = cy - hy;
    vp->y_max = cy + hy;
}

void graph_zoom_at(graph_viewport_t* vp, double factor, double anchor_x, double anchor_y) {
    vp->x_min = anchor_x + (vp->x_min - anchor_x) * factor;
    vp->x_max = anchor_x + (vp->x_max - anchor_x) * factor;
    vp->y_min = anchor_y + (vp->y_min - anchor_y) * factor;
    vp->y_max = anchor_y + (vp->y_max - anchor_y) * factor;
}

bool graph_apply_range(graph_viewport_t* vp, double x_min, double x_max, double y_min, double y_max) {
    if (!(x_min < x_max) || !(y_min < y_max)) return false;
    if (!std::isfinite(x_min) || !std::isfinite(x_max) ||
        !std::isfinite(y_min) || !std::isfinite(y_max)) return false;
    vp->x_min = x_min;
    vp->x_max = x_max;
    vp->y_min = y_min;
    vp->y_max = y_max;
    return true;
}

bool graph_auto_fit_y(const double* ys, size_t count, double* out_y_min, double* out_y_max) {
    if (count == 0 || !ys || !out_y_min || !out_y_max) return false;
    std::vector<double> sorted(ys, ys + count);
    std::sort(sorted.begin(), sorted.end());
    // 5%–95% 分位裁掉渐近线附近的爆炸值（与 Swift Int(Double) 同为向零截断）。
    const double lo = sorted[static_cast<size_t>(static_cast<double>(count - 1) * 0.05)];
    const double hi = sorted[static_cast<size_t>(static_cast<double>(count - 1) * 0.95)];
    double new_min = lo;
    double new_max = hi;
    if (new_max - new_min < 1e-9) {
        new_min -= 1;
        new_max += 1;
    }
    const double margin = (new_max - new_min) * 0.1;
    *out_y_min = new_min - margin;
    *out_y_max = new_max + margin;
    return true;
}

// MARK: - 显式曲线逐列采样

size_t graph_sample_curve(
    const graph_viewport_t* vp, graph_eval_fn eval, void* ctx,
    graph_sample_t* out, size_t cap) {
    if (!vp || !eval || !(vp->width > 1)) return 0;

    size_t count = 0;
    bool pen_down = false;
    double last_sy = 0;
    // 间断阈值：单像素列 y 跳变超过 1.5 倍画布高度视为断裂（垂直渐近线等）。
    const double jump_threshold = vp->height * 1.5;

    const int columns = static_cast<int>(vp->width);
    for (int column = 0; column <= columns; ++column) {
        const double sx = static_cast<double>(column);
        const double math_x = vp->x_min + sx / vp->width * x_span(vp);
        double math_y = 0;
        if (!eval(ctx, math_x, &math_y)) {
            pen_down = false;
            continue;
        }
        const double sy = graph_to_screen_y(vp, math_y);

        if (pen_down && std::fabs(sy - last_sy) > jump_threshold) {
            pen_down = false;  // 断裂
        }

        emit_sample(out, cap, count, sx, sy, !pen_down);
        ++count;
        pen_down = true;
        last_sy = sy;
    }
    return count;
}

// MARK: - Marching squares（隐式等值线）

int graph_cell_count(double extent_px, double cell_px) {
    if (!(cell_px > 0) || !std::isfinite(extent_px)) return 8;
    return std::max(8, static_cast<int>(extent_px / cell_px));
}

int graph_pow2_cell_count(double extent_px, double pixel_px) {
    if (!(pixel_px > 0) || !std::isfinite(extent_px) || !(extent_px > 0)) return 1;
    int cells = 1;
    double size = extent_px;
    while (size > pixel_px && cells < (1 << 20)) {
        size /= 2;
        cells *= 2;
    }
    return cells;
}

size_t graph_marching_squares(
    double x_min, double x_max, double y_min, double y_max,
    int cols, int rows, graph_eval2_fn eval, void* ctx,
    graph_segment_t* out, size_t cap) {
    if (!eval || cols <= 0 || rows <= 0 || !(x_max > x_min) || !(y_max > y_min)) return 0;

    const double dx = (x_max - x_min) / static_cast<double>(cols);
    const double dy = (y_max - y_min) / static_cast<double>(rows);

    // 采样网格节点值；节点值恰为 0 时视作 +ε，避免退化格。NaN 表示未定义。
    const size_t stride = static_cast<size_t>(cols) + 1;
    std::vector<double> grid(stride * (static_cast<size_t>(rows) + 1));
    for (int r = 0; r <= rows; ++r) {
        const double y = y_min + static_cast<double>(r) * dy;
        for (int c = 0; c <= cols; ++c) {
            double v = 0;
            if (eval(ctx, x_min + static_cast<double>(c) * dx, y, &v)) {
                grid[static_cast<size_t>(r) * stride + c] = (v == 0) ? DBL_TRUE_MIN : v;
            } else {
                grid[static_cast<size_t>(r) * stride + c] = NAN;
            }
        }
    }

    size_t count = 0;
    for (int r = 0; r < rows; ++r) {
        for (int c = 0; c < cols; ++c) {
            // 四角：bl(c,r) br(c+1,r) tr(c+1,r+1) tl(c,r+1)
            const double bl = grid[static_cast<size_t>(r) * stride + c];
            const double br = grid[static_cast<size_t>(r) * stride + c + 1];
            const double tr = grid[(static_cast<size_t>(r) + 1) * stride + c + 1];
            const double tl = grid[(static_cast<size_t>(r) + 1) * stride + c];
            if (std::isnan(bl) || std::isnan(br) || std::isnan(tr) || std::isnan(tl)) continue;

            const double x0 = x_min + static_cast<double>(c) * dx, x1 = x0 + dx;
            const double y0 = y_min + static_cast<double>(r) * dy, y1 = y0 + dy;

            // 各边的零交点（线性插值），顺序固定为 [下, 右, 上, 左]。
            double px[4], py[4];
            int n = 0;
            if (crosses(bl, br)) { px[n] = interp(x0, x1, bl, br); py[n] = y0; ++n; }
            if (crosses(br, tr)) { px[n] = x1; py[n] = interp(y0, y1, br, tr); ++n; }
            if (crosses(tl, tr)) { px[n] = interp(x0, x1, tl, tr); py[n] = y1; ++n; }
            if (crosses(bl, tl)) { px[n] = x0; py[n] = interp(y0, y1, bl, tl); ++n; }

            if (n == 2) {
                emit_segment(out, cap, count++, px[0], py[0], px[1], py[1]);
            } else if (n == 4) {
                // 鞍点：用格中心符号决定配对方式（未定义按 0 处理）。
                double center = 0;
                if (!eval(ctx, (x0 + x1) / 2, (y0 + y1) / 2, &center)) center = 0;
                const bool same_as_bl = (center > 0) == (bl > 0);
                if (same_as_bl) {
                    // 中心与 bl 同侧：下-右、上-左
                    emit_segment(out, cap, count++, px[0], py[0], px[1], py[1]);
                    emit_segment(out, cap, count++, px[2], py[2], px[3], py[3]);
                } else {
                    // 下-左、上-右
                    emit_segment(out, cap, count++, px[0], py[0], px[3], py[3]);
                    emit_segment(out, cap, count++, px[2], py[2], px[1], py[1]);
                }
            }
        }
    }
    return count;
}

// MARK: - 不等式区域

bool graph_relation_satisfied(graph_relation_t relation, double f) {
    switch (relation) {
        case GRAPH_REL_LESS: return f < 0;
        case GRAPH_REL_LESS_EQUAL: return f <= 0;
        case GRAPH_REL_GREATER: return f > 0;
        case GRAPH_REL_GREATER_EQUAL: return f >= 0;
    }
    return false;
}

bool graph_relation_is_strict(graph_relation_t relation) {
    return relation == GRAPH_REL_LESS || relation == GRAPH_REL_GREATER;
}

size_t graph_inequality_runs(
    const graph_viewport_t* vp, double cell_px,
    graph_relation_t relation, graph_eval2_fn eval, void* ctx,
    graph_rect_t* out, size_t cap) {
    if (!vp || !eval || !(vp->width > 1) || !(vp->height > 1)) return 0;

    const int cols = graph_cell_count(vp->width, cell_px);
    const int rows = graph_cell_count(vp->height, cell_px);
    const double cell_w = vp->width / static_cast<double>(cols);
    const double cell_h = vp->height / static_cast<double>(rows);

    size_t count = 0;
    for (int row = 0; row < rows; ++row) {
        const double sy = (static_cast<double>(row) + 0.5) * cell_h;
        const double math_y = vp->y_max - sy / vp->height * y_span(vp);
        int run_start = -1;
        for (int col = 0; col <= cols; ++col) {
            bool inside = false;
            if (col < cols) {
                const double sx = (static_cast<double>(col) + 0.5) * cell_w;
                const double math_x = vp->x_min + sx / vp->width * x_span(vp);
                double f = 0;
                if (eval(ctx, math_x, math_y, &f)) {
                    inside = graph_relation_satisfied(relation, f);
                }
            }
            if (inside) {
                if (run_start < 0) run_start = col;
            } else if (run_start >= 0) {
                // 合并同行连续单元为一个矩形，减少路径元素。
                if (count < cap) {
                    out[count] = graph_rect_t{
                        static_cast<double>(run_start) * cell_w,
                        static_cast<double>(row) * cell_h,
                        static_cast<double>(col - run_start) * cell_w,
                        cell_h};
                }
                ++count;
                run_start = -1;
            }
        }
    }
    return count;
}

// MARK: - 跟踪吸附

int32_t graph_trace_snap(const double* ys, size_t count, double math_y, double y_span) {
    if (!ys) return -1;
    int32_t best = -1;
    double best_dist = HUGE_VAL;
    for (size_t i = 0; i < count; ++i) {
        if (std::isnan(ys[i])) continue;
        const double dist = std::fabs(ys[i] - math_y) / y_span;
        if (dist < best_dist) {
            best_dist = dist;
            best = static_cast<int32_t>(i);
        }
    }
    return best;
}

}  // extern "C"

// MARK: - 区间算术四叉树（Tupper，S4）

namespace {

// 屏幕空间盒（像素，原点左上）。四叉树在屏幕空间细分，保证叶子对齐像素粒度；
// 求值时映射回数学空间（y 翻转：屏幕 y0..y1 对应数学 y(y1)..y(y0)）。
struct ScreenBox {
    double sx0, sy0, sx1, sy1;
};

// 对盒内 F 求区间围栏。NaN 界按无信息处理（[-inf,inf]），保守不丢解。
graph_box_domain_t eval_box(
    const graph_viewport_t* vp, graph_eval2_interval_fn eval, void* ctx,
    const ScreenBox& b, double* lo, double* hi) {
    const double x_lo = graph_to_math_x(vp, b.sx0);
    const double x_hi = graph_to_math_x(vp, b.sx1);
    const double y_lo = graph_to_math_y(vp, b.sy1);
    const double y_hi = graph_to_math_y(vp, b.sy0);
    *lo = -HUGE_VAL;
    *hi = HUGE_VAL;
    const graph_box_domain_t domain = eval(ctx, x_lo, x_hi, y_lo, y_hi, lo, hi);
    if (std::isnan(*lo)) *lo = -HUGE_VAL;
    if (std::isnan(*hi)) *hi = HUGE_VAL;
    return domain;
}

void split4(const ScreenBox& b, ScreenBox out[4]) {
    const double mx = (b.sx0 + b.sx1) / 2;
    const double my = (b.sy0 + b.sy1) / 2;
    out[0] = ScreenBox{b.sx0, b.sy0, mx, my};
    out[1] = ScreenBox{mx, b.sy0, b.sx1, my};
    out[2] = ScreenBox{b.sx0, my, mx, b.sy1};
    out[3] = ScreenBox{mx, my, b.sx1, b.sy1};
}

// 逐轴二分：只切超过 pixel_px 的轴。返回子盒数；0 = 已是叶子。
// 这样叶子恰好构成 2^kx × 2^ky 均匀网格（kx/ky 为各轴对分次数），
// 与 graph_pow2_cell_count 给 marching squares 的网格逐节点对齐——
// corner_eval 抑制的前提（"该格 MS 已画"）才成立。
int split_box(const ScreenBox& b, double pixel_px, ScreenBox out[4]) {
    const bool split_x = (b.sx1 - b.sx0) > pixel_px;
    const bool split_y = (b.sy1 - b.sy0) > pixel_px;
    if (split_x && split_y) {
        split4(b, out);
        return 4;
    }
    if (split_x) {
        const double mx = (b.sx0 + b.sx1) / 2;
        out[0] = ScreenBox{b.sx0, b.sy0, mx, b.sy1};
        out[1] = ScreenBox{mx, b.sy0, b.sx1, b.sy1};
        return 2;
    }
    if (split_y) {
        const double my = (b.sy0 + b.sy1) / 2;
        out[0] = ScreenBox{b.sx0, b.sy0, b.sx1, my};
        out[1] = ScreenBox{b.sx0, my, b.sx1, b.sy1};
        return 2;
    }
    return 0;
}

inline void emit_rect(graph_rect_t* out, size_t cap, size_t index, const ScreenBox& b) {
    if (out && index < cap) {
        out[index] = graph_rect_t{b.sx0, b.sy0, b.sx1 - b.sx0, b.sy1 - b.sy0};
    }
}

// MS 在该格无输出的判定：任一角未定义（MS 直接跳格），或四角同号
// （0 视作正，与 graph_marching_squares 一致）。这类格必须由区间单元补画。
bool corners_sign_blind(
    const graph_viewport_t* vp, graph_eval2_fn eval, void* ctx, const ScreenBox& b) {
    const double xs[2] = {graph_to_math_x(vp, b.sx0), graph_to_math_x(vp, b.sx1)};
    const double ys[2] = {graph_to_math_y(vp, b.sy1), graph_to_math_y(vp, b.sy0)};
    bool first = true;
    bool positive = false;
    for (double x : xs) {
        for (double y : ys) {
            double v = 0;
            if (!eval(ctx, x, y, &v)) return true;  // 未定义角：MS 跳过该格
            const bool p = (v == 0) ? true : (v > 0);
            if (first) {
                positive = p;
                first = false;
            } else if (p != positive) {
                return false;  // 有符号变化：MS 会画
            }
        }
    }
    return true;
}

// 隐式 F=0 的递归细分。返回本子树输出的矩形数。
size_t implicit_recurse(
    const graph_viewport_t* vp, double pixel_px,
    graph_eval2_interval_fn eval, void* ctx,
    graph_eval2_fn corner_eval, void* corner_ctx,
    const ScreenBox& box, graph_rect_t* out, size_t cap, size_t count) {
    double lo = 0, hi = 0;
    const graph_box_domain_t domain = eval_box(vp, eval, ctx, box, &lo, &hi);
    // 无解可证：全盒未定义，或 0 不在（已定义部分的）围栏内。
    if (domain == GRAPH_BOX_NOWHERE_DEFINED || lo > 0 || hi < 0) return 0;

    ScreenBox children[4];
    const int child_count = split_box(box, pixel_px, children);
    const bool is_leaf_implicit = child_count == 0;
    if (is_leaf_implicit) {
        if (corner_eval && corners_sign_blind(vp, corner_eval, corner_ctx, box) == false) {
            return 0;  // MS 已覆盖该格
        }
        emit_rect(out, cap, count, box);
        return 1;
    }
    size_t emitted = 0;
    for (int i = 0; i < child_count; ++i) {
        emitted += implicit_recurse(
            vp, pixel_px, eval, ctx, corner_eval, corner_ctx, children[i], out, cap, count + emitted);
    }
    return emitted;
}

// 关系在整个围栏上必然成立/必然不成立的判定。
bool relation_certainly_holds(graph_relation_t relation, double lo, double hi) {
    switch (relation) {
        case GRAPH_REL_LESS: return hi < 0;
        case GRAPH_REL_LESS_EQUAL: return hi <= 0;
        case GRAPH_REL_GREATER: return lo > 0;
        case GRAPH_REL_GREATER_EQUAL: return lo >= 0;
    }
    return false;
}

bool relation_certainly_fails(graph_relation_t relation, double lo, double hi) {
    switch (relation) {
        case GRAPH_REL_LESS: return lo >= 0;
        case GRAPH_REL_LESS_EQUAL: return lo > 0;
        case GRAPH_REL_GREATER: return hi <= 0;
        case GRAPH_REL_GREATER_EQUAL: return hi < 0;
    }
    return false;
}

struct InequalityCounts {
    size_t certain = 0;
    size_t uncertain = 0;
};

void inequality_recurse(
    const graph_viewport_t* vp, double pixel_px,
    graph_relation_t relation, graph_eval2_interval_fn eval, void* ctx,
    const ScreenBox& box,
    graph_rect_t* out_certain, size_t cap_certain,
    graph_rect_t* out_uncertain, size_t cap_uncertain,
    InequalityCounts& counts) {
    double lo = 0, hi = 0;
    const graph_box_domain_t domain = eval_box(vp, eval, ctx, box, &lo, &hi);
    // 未定义点不满足不等式：全盒未定义 → 丢弃；已定义部分必然不满足 → 丢弃。
    if (domain == GRAPH_BOX_NOWHERE_DEFINED || relation_certainly_fails(relation, lo, hi)) {
        return;
    }
    // 确定满足要求全盒已定义且围栏整体满足——整节点一次输出，不再细分。
    if (domain == GRAPH_BOX_DEFINED && relation_certainly_holds(relation, lo, hi)) {
        emit_rect(out_certain, cap_certain, counts.certain, box);
        ++counts.certain;
        return;
    }
    ScreenBox children[4];
    const int child_count = split_box(box, pixel_px, children);
    if (child_count == 0) {
        emit_rect(out_uncertain, cap_uncertain, counts.uncertain, box);
        ++counts.uncertain;
        return;
    }
    for (int i = 0; i < child_count; ++i) {
        inequality_recurse(
            vp, pixel_px, relation, eval, ctx, children[i],
            out_certain, cap_certain, out_uncertain, cap_uncertain, counts);
    }
}

}  // namespace

extern "C" {

size_t graph_implicit_cells(
    const graph_viewport_t* vp, double pixel_px,
    graph_eval2_interval_fn eval, void* ctx,
    graph_eval2_fn corner_eval, void* corner_ctx,
    graph_rect_t* out, size_t cap) {
    if (!vp || !eval || !(pixel_px > 0) || !(vp->width > 1) || !(vp->height > 1)) return 0;
    const ScreenBox root{0, 0, vp->width, vp->height};
    return implicit_recurse(vp, pixel_px, eval, ctx, corner_eval, corner_ctx, root, out, cap, 0);
}

size_t graph_inequality_regions(
    const graph_viewport_t* vp, double pixel_px,
    graph_relation_t relation, graph_eval2_interval_fn eval, void* ctx,
    graph_rect_t* out_certain, size_t cap_certain,
    graph_rect_t* out_uncertain, size_t cap_uncertain,
    size_t* out_uncertain_total) {
    if (out_uncertain_total) *out_uncertain_total = 0;
    if (!vp || !eval || !(pixel_px > 0) || !(vp->width > 1) || !(vp->height > 1)) return 0;
    const ScreenBox root{0, 0, vp->width, vp->height};
    InequalityCounts counts;
    inequality_recurse(
        vp, pixel_px, relation, eval, ctx, root,
        out_certain, cap_certain, out_uncertain, cap_uncertain, counts);
    if (out_uncertain_total) *out_uncertain_total = counts.uncertain;
    return counts.certain;
}

}  // extern "C"
