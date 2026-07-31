// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// graph_geometry.h — shared graphing geometry, C ABI (S7).
//
// Everything in GraphingView that is math rather than drawing lives here:
// viewport transforms, 1-2-5 tick steps, per-column curve sampling with
// discontinuity breaks, marching squares, inequality region runs, trace
// snapping and viewport pan/zoom/auto-fit. Rendering backends (CoreGraphics /
// Canvas / OH_Drawing / Compose) only turn the returned primitives into paths.
//
// Contract:
//   - Pure math, no engine dependency, no allocation: callers own all buffers.
//   - Functions returning size_t report the TOTAL primitive count (snprintf
//     style); at most `cap` items are written to `out`. Worst-case caps are
//     documented per function.
//   - Expression evaluators are passed as callbacks returning false where the
//     function is undefined. Callbacks must not throw across this boundary.
//   - Screen space: origin top-left, y down. Math space: y up.

#ifndef GRAPH_GEOMETRY_H
#define GRAPH_GEOMETRY_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Math window [x_min,x_max]×[y_min,y_max] mapped onto a width×height canvas.
typedef struct graph_viewport {
    double x_min;
    double x_max;
    double y_min;
    double y_max;
    double width;
    double height;
} graph_viewport_t;

/// y = f(x). Return false when undefined at x (out_y then ignored).
typedef bool (*graph_eval_fn)(void* ctx, double x, double* out_y);

/// F(x, y). Return false when undefined (out_f then ignored).
typedef bool (*graph_eval2_fn)(void* ctx, double x, double y, double* out_f);

// MARK: - Transforms

double graph_to_screen_x(const graph_viewport_t* vp, double x);
double graph_to_screen_y(const graph_viewport_t* vp, double y);
double graph_to_math_x(const graph_viewport_t* vp, double sx);
double graph_to_math_y(const graph_viewport_t* vp, double sy);

// MARK: - Grid ticks (1-2-5)

/// Nice step covering span/target_ticks, snapped to {1,2,5}×10^n.
/// Returns 0 for non-positive/non-finite span or target_ticks <= 0.
double graph_nice_step(double span, int target_ticks);

/// Tick positions k*step within [range_min, range_max]
/// (first = ceil(range_min/step)*step). Total count is returned; at most cap
/// values are written. (Names avoid the Windows min/max macros.)
size_t graph_ticks(double range_min, double range_max, double step, double* out, size_t cap);

// MARK: - Viewport operations

void graph_pan(graph_viewport_t* vp, double dx_math, double dy_math);

/// Zoom about the viewport center. factor < 1 zooms in, > 1 zooms out.
void graph_zoom(graph_viewport_t* vp, double factor);

/// Zoom about an anchor point in math coordinates (wheel / pinch).
void graph_zoom_at(graph_viewport_t* vp, double factor, double anchor_x, double anchor_y);

/// Manual range entry; rejects min >= max or non-finite values.
bool graph_apply_range(graph_viewport_t* vp, double x_min, double x_max, double y_min, double y_max);

/// Best-fit y range from sampled curve values: 5%–95% percentile window,
/// ±1 when degenerate, then 10% margin. Returns false when count == 0.
bool graph_auto_fit_y(const double* ys, size_t count, double* out_y_min, double* out_y_max);

// MARK: - Explicit curve sampling

/// One sampled screen point; move == true starts a new subpath (pen was up:
/// first point, undefined gap, or discontinuity jump > 1.5 canvas heights).
typedef struct graph_sample {
    double sx;
    double sy;
    bool move;
} graph_sample_t;

/// Per-pixel-column sampling of y = f(x) over the viewport.
/// Worst-case count = floor(vp->width) + 1. Returns 0 when width <= 1.
size_t graph_sample_curve(
    const graph_viewport_t* vp, graph_eval_fn eval, void* ctx,
    graph_sample_t* out, size_t cap);

// MARK: - Implicit curves (marching squares)

/// Line segment in math coordinates.
typedef struct graph_segment {
    double x1;
    double y1;
    double x2;
    double y2;
} graph_segment_t;

/// Grid resolution for implicit/inequality rendering: max(8, extent/cell_px).
int graph_cell_count(double extent_px, double cell_px);

/// Leaf-cell count per axis of the interval quadtree (S4): repeated halving of
/// extent_px until <= pixel_px gives 2^k cells. Use this as the marching
/// squares cols/rows so MS cells and quadtree leaves align node-for-node —
/// required for graph_implicit_cells' corner_eval suppression to be sound.
int graph_pow2_cell_count(double extent_px, double pixel_px);

/// F(x,y) = 0 contour on a cols×rows grid via marching squares with linear
/// interpolation and center-sample saddle disambiguation.
/// Worst-case count = 2 * cols * rows. Returns 0 on invalid bounds/grid.
size_t graph_marching_squares(
    double x_min, double x_max, double y_min, double y_max,
    int cols, int rows, graph_eval2_fn eval, void* ctx,
    graph_segment_t* out, size_t cap);

// MARK: - Inequality regions

/// Relation of F(x,y) to 0 (F = LHS - RHS).
typedef enum graph_relation {
    GRAPH_REL_LESS = 0,
    GRAPH_REL_LESS_EQUAL = 1,
    GRAPH_REL_GREATER = 2,
    GRAPH_REL_GREATER_EQUAL = 3,
} graph_relation_t;

bool graph_relation_satisfied(graph_relation_t relation, double f);

/// Strict inequalities draw their F = 0 boundary dashed.
bool graph_relation_is_strict(graph_relation_t relation);

/// Screen-space rectangle (origin top-left).
typedef struct graph_rect {
    double x;
    double y;
    double w;
    double h;
} graph_rect_t;

/// Region where F rel 0 holds, sampled at cell centers on a max(8, size/cell_px)
/// grid, merging consecutive satisfied cells per row into single rects.
/// Worst-case count = rows * ceil((cols + 1) / 2). Returns 0 when size <= 1.
size_t graph_inequality_runs(
    const graph_viewport_t* vp, double cell_px,
    graph_relation_t relation, graph_eval2_fn eval, void* ctx,
    graph_rect_t* out, size_t cap);

// MARK: - Interval arithmetic (Tupper, S4)

/// Definedness of F over a whole box (three-valued).
typedef enum graph_box_domain {
    GRAPH_BOX_NOWHERE_DEFINED = 0,  ///< F undefined on the entire box
    GRAPH_BOX_DEFINED = 1,          ///< F defined on the entire box
    GRAPH_BOX_MAYBE_DEFINED = 2,    ///< F possibly undefined somewhere in the box
} graph_box_domain_t;

/// Interval enclosure of F over the box [x_lo,x_hi]×[y_lo,y_hi].
/// Contract: [*out_lo, *out_hi] must contain F(x,y) for every point of the box
/// where F is defined (outward rounding is the callback's responsibility).
/// Bounds may be ±infinity; when the return value is NOWHERE_DEFINED the
/// bounds are ignored. Must not throw across this boundary.
typedef graph_box_domain_t (*graph_eval2_interval_fn)(
    void* ctx, double x_lo, double x_hi, double y_lo, double y_hi,
    double* out_lo, double* out_hi);

/// Tupper implicit rendering: quadtree subdivision of the viewport, discarding
/// boxes where 0 is excluded from the F-enclosure, emitting screen rects for
/// surviving leaves (<= pixel_px on both sides). Guarantees no false negatives:
/// every solution pixel is covered by some emitted rect.
///
/// When corner_eval is non-NULL, leaves whose four corners are all defined and
/// show a sign change are suppressed — marching squares already draws those;
/// only the cells it would miss (same-sign corners: self-intersections,
/// sub-cell features) are emitted. Corner zero values count as positive,
/// matching graph_marching_squares.
///
/// Total count returned (snprintf style); worst case ceil(w/px)*ceil(h/px).
/// On overflow callers should coarsen pixel_px (stays conservative) rather
/// than drop rects.
size_t graph_implicit_cells(
    const graph_viewport_t* vp, double pixel_px,
    graph_eval2_interval_fn eval, void* ctx,
    graph_eval2_fn corner_eval, void* corner_ctx,
    graph_rect_t* out, size_t cap);

/// Tupper inequality rendering, three-valued:
///   certain   — F rel 0 provably holds on the whole box (requires DEFINED);
///               emitted unsubdivided, so large areas collapse to few rects.
///   discarded — F rel 0 provably fails everywhere it is defined.
///   uncertain — neither; subdivided down to pixel_px then emitted separately
///               so the UI can render "uncertain" distinctly (M4).
/// Returns the total certain count; *out_uncertain_total (optional) receives
/// the total uncertain count. Caps are snprintf style as above.
size_t graph_inequality_regions(
    const graph_viewport_t* vp, double pixel_px,
    graph_relation_t relation, graph_eval2_interval_fn eval, void* ctx,
    graph_rect_t* out_certain, size_t cap_certain,
    graph_rect_t* out_uncertain, size_t cap_uncertain,
    size_t* out_uncertain_total);

// MARK: - Trace snapping

/// Pick the candidate curve nearest to math_y, distance normalized by y_span.
/// ys[i] is curve i's value at the cursor's math x (NaN = undefined there).
/// Returns the winning index, or -1 when no candidate is defined.
int32_t graph_trace_snap(const double* ys, size_t count, double math_y, double y_span);

#ifdef __cplusplus
}
#endif

#endif  // GRAPH_GEOMETRY_H
