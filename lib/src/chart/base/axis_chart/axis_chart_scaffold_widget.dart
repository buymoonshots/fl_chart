import 'dart:math';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/base/axis_chart/axis_chart_data.dart';
import 'package:fl_chart/src/chart/base/axis_chart/scale_axis.dart';
import 'package:fl_chart/src/chart/base/axis_chart/side_titles/side_titles_widget.dart';
import 'package:fl_chart/src/chart/base/axis_chart/transformation_config.dart';
import 'package:fl_chart/src/chart/base/custom_interactive_viewer.dart';
import 'package:fl_chart/src/extensions/fl_titles_data_extension.dart';
import 'package:fl_chart/src/extensions/path_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A builder to build a chart.
///
/// The [chartVirtualRect] is the virtual chart virtual rect to be used when
/// laying out the chart's content. It is transformed based on users'
/// interactions like scaling and panning.
typedef ChartBuilder = Widget Function(
  BuildContext context,
  Rect? chartVirtualRect,
);

/// A scaffold to show a scalable axis-based chart
///
/// It contains some placeholders to represent an axis-based chart.
///
/// It's something like the below graph:
/// |----------------------|
/// |      |  top  |       |
/// |------|-------|-------|
/// | left | chart | right |
/// |------|-------|-------|
/// |      | bottom|       |
/// |----------------------|
///
/// `left`, `top`, `right`, `bottom` are some place holders to show titles
/// provided by [AxisChartData.titlesData] around the chart
/// `chart` is a centered place holder to show a raw chart. The chart is
/// built using [chartBuilder].
class AxisChartScaffoldWidget extends StatefulWidget {
  const AxisChartScaffoldWidget({
    super.key,
    required this.chartBuilder,
    required this.data,
    this.animatedData,
    this.transformationConfig = const FlTransformationConfig(),
  });

  /// The builder to build the chart.
  final ChartBuilder chartBuilder;

  /// The data to build the chart (target data).
  final AxisChartData data;

  /// Animated/interpolated data during chart animations.
  /// When provided, widgets will use this for positioning to animate smoothly with lines.
  /// If null, widgets will use [data] (static positioning).
  final AxisChartData? animatedData;

  /// {@template fl_chart.AxisChartScaffoldWidget.transformationConfig}
  /// The transformation configuration of the chart.
  ///
  /// Used to configure scaling and panning of the chart.
  /// {@endtemplate}
  final FlTransformationConfig transformationConfig;

  @override
  State<AxisChartScaffoldWidget> createState() =>
      _AxisChartScaffoldWidgetState();
}

class _AxisChartScaffoldWidgetState extends State<AxisChartScaffoldWidget> {
  late TransformationController _transformationController;

  final GlobalKey _chartKey = GlobalKey();

  // Offset to position clamped horizontal lines beyond vertical line labels
  // Vertical labels with showOnTopOfTheChartBoxArea are positioned outside chart bounds
  // This offset ensures clamped lines are clearly above/below those labels
  // but not so far that they're outside the visible container
  static const double _clampLabelOffset = 25.0;

  // Map to store widget sizes and positions for horizontal line right widgets
  final Map<int, Size> _rightWidgetSizes = {};
  final Map<int, GlobalKey> _rightWidgetKeys = {};

  // Map to store widget sizes and positions for line chart trailing widgets
  final Map<int, Size> _trailingWidgetSizes = {};
  final Map<int, GlobalKey> _trailingWidgetKeys = {};

  FlTransformationConfig get _transformationConfig =>
      widget.transformationConfig;

  bool get _canScaleHorizontally =>
      _transformationConfig.scaleAxis == FlScaleAxis.horizontal ||
      _transformationConfig.scaleAxis == FlScaleAxis.free;

  bool get _canScaleVertically =>
      _transformationConfig.scaleAxis == FlScaleAxis.vertical ||
      _transformationConfig.scaleAxis == FlScaleAxis.free;

  @override
  void initState() {
    super.initState();
    _transformationController =
        _transformationConfig.transformationController ??
            TransformationController();
    _transformationController.addListener(_transformationControllerListener);

    // Measure right widgets after first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureRightWidgets();
      _measureTrailingWidgets();
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_transformationControllerListener);
    if (_transformationConfig.transformationController == null) {
      _transformationController.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(AxisChartScaffoldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    switch ((
      oldWidget.transformationConfig.transformationController,
      widget.transformationConfig.transformationController
    )) {
      case (null, null):
        break;
      case (null, TransformationController()):
        _transformationController.dispose();
        _transformationController =
            widget.transformationConfig.transformationController!;
        _transformationController
            .addListener(_transformationControllerListener);
      case (TransformationController(), null):
        _transformationController
            .removeListener(_transformationControllerListener);
        _transformationController = TransformationController();
        _transformationController
            .addListener(_transformationControllerListener);
      case (TransformationController(), TransformationController()):
        if (oldWidget.transformationConfig.transformationController !=
            widget.transformationConfig.transformationController) {
          _transformationController
              .removeListener(_transformationControllerListener);
          _transformationController =
              widget.transformationConfig.transformationController!;
          _transformationController
              .addListener(_transformationControllerListener);
        }
    }

    // Measure right widgets after update
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureRightWidgets();
      _measureTrailingWidgets();
    });
  }

  void _transformationControllerListener() {
    setState(() {});
  }

  /// Collects horizontal lines that have rightWidget set
  /// Uses animatedData if available for smooth animation, otherwise uses target data
  List<({HorizontalLine line, int index})> _getHorizontalLinesWithWidgets() {
    final lines = <({HorizontalLine line, int index})>[];
    // Use animated data for positioning if available, otherwise use target data
    final dataToUse = widget.animatedData ?? widget.data;
    final extraLines = dataToUse.extraLinesData.horizontalLines;
    for (int i = 0; i < extraLines.length; i++) {
      if (extraLines[i].rightWidget != null) {
        lines.add((line: extraLines[i], index: i));
      }
    }
    return lines;
  }

  /// Measures widget sizes and updates state
  void _measureRightWidgets() {
    bool hasChanges = false;
    for (final entry in _rightWidgetKeys.entries) {
      final context = entry.value.currentContext;
      if (context != null) {
        final size = context.size;
        if (size != null && _rightWidgetSizes[entry.key] != size) {
          _rightWidgetSizes[entry.key] = size;
          hasChanges = true;
        }
      }
    }
    if (hasChanges) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Measures trailing widget sizes and updates state
  void _measureTrailingWidgets() {
    bool hasChanges = false;
    for (final entry in _trailingWidgetKeys.entries) {
      final context = entry.value.currentContext;
      if (context != null) {
        final size = context.size;
        if (size != null && _trailingWidgetSizes[entry.key] != size) {
          _trailingWidgetSizes[entry.key] = size;
          hasChanges = true;
        }
      }
    }
    if (hasChanges) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Calculates required right padding for right widgets
  /// Uses the standardized maximum width (all widgets have uniform width)
  /// Uses target data (not animated) for consistent padding during animations
  double _calculateRightWidgetPadding(double chartHeight) {
    final linesWithWidgets = _getHorizontalLinesWithWidgets();
    if (linesWithWidgets.isEmpty) return 0;

    // Calculate maximum width from all measured widgets (standardized width)
    double maxWidgetWidth = 0;
    for (final size in _rightWidgetSizes.values) {
      if (size.width > maxWidgetWidth) {
        maxWidgetWidth = size.width;
      }
    }

    // If no widgets measured yet, we need to estimate
    // But we should use the max width once widgets are measured
    if (maxWidgetWidth == 0) {
      // Fallback: estimate based on typical widget size
      // This will be recalculated once widgets are measured
      maxWidgetWidth = 120.0;
    }

    // Get maximum padding from all lines (use target data for consistent padding)
    // This ensures padding doesn't change during animation
    double maxPadding = 0;
    final targetLines = widget.data.extraLinesData.horizontalLines;
    for (final lineData in linesWithWidgets) {
      // Find corresponding line in target data to get padding
      if (lineData.index < targetLines.length) {
        final padding = targetLines[lineData.index].rightWidgetPadding;
        if (padding > maxPadding) {
          maxPadding = padding;
        }
      }
    }

    // Return standardized width + padding
    return maxWidgetWidth + maxPadding;
  }

  /// Calculates stacking positions for overlapping widgets
  /// Includes lines with widgets that are within the visible chart bounds,
  /// and optionally clamped widgets for lines outside bounds when clampToBounds is true
  List<
      ({
        int index,
        double y,
        double verticalOffset,
        bool isClamped,
        bool isClampedToTop
      })> _calculateWidgetPositions(
    double chartHeight,
    Size viewSize,
    Rect? chartVirtualRect,
  ) {
    final linesWithWidgets = _getHorizontalLinesWithWidgets();
    if (linesWithWidgets.isEmpty) return [];

    final positions = <({
      int index,
      double y,
      double verticalOffset,
      bool isClamped,
      bool isClampedToTop
    })>[];
    // Use animated data for positioning if available, otherwise use target data
    final data = widget.animatedData ?? widget.data;

    // Separate clamped and non-clamped widgets
    final nonClampedPositions = <({int index, double y, double originalY})>[];
    final topClampedPositions = <({int index, double originalY})>[];
    final bottomClampedPositions = <({int index, double originalY})>[];

    // Calculate Y position for each line
    for (int i = 0; i < linesWithWidgets.length; i++) {
      final lineData = linesWithWidgets[i];
      final line = lineData.line;
      final index = lineData.index;

      // Check if line Y is within chart bounds
      final lineWithinYBounds = line.y >= data.minY && line.y <= data.maxY;

      if (lineWithinYBounds) {
        // Calculate pixel Y position without clamping (since we've already filtered for bounds)
        final pixelY = _getPixelY(
          line.y,
          viewSize,
          chartVirtualRect,
          shouldClamp: false,
        );
        nonClampedPositions.add((index: index, y: pixelY, originalY: line.y));
      } else if (line.clampToBounds) {
        // Widget should be clamped to nearest edge
        // In chart coordinates: higher Y = higher on chart (top), lower Y = lower on chart (bottom)
        if (line.y > data.maxY) {
          // Line is above visible area (higher value) → clamp to top edge
          topClampedPositions.add((index: index, originalY: line.y));
        } else if (line.y < data.minY) {
          // Line is below visible area (lower value) → clamp to bottom edge
          bottomClampedPositions.add((index: index, originalY: line.y));
        }
        // If line.y == data.minY or data.maxY, it's within bounds, so this shouldn't happen
      }
      // If not within bounds and clampToBounds is false, skip this widget
    }

    // Sort non-clamped positions by Y (top to bottom)
    nonClampedPositions.sort((a, b) => a.y.compareTo(b.y));

    // Sort top-clamped positions by original Y descending (highest Y first, so they stack downward)
    topClampedPositions.sort((a, b) => b.originalY.compareTo(a.originalY));

    // Sort bottom-clamped positions by original Y ascending (lowest Y first, so they stack upward)
    bottomClampedPositions.sort((a, b) => a.originalY.compareTo(b.originalY));

    // Get maximum stacking spacing from all lines
    double maxStackingSpacing = 0;
    for (final lineData in linesWithWidgets) {
      final spacing = lineData.line.rightWidgetStackingSpacing;
      if (spacing > maxStackingSpacing) {
        maxStackingSpacing = spacing;
      }
    }

    // Calculate relative tolerance based on Y-axis range (0.5% like candlestick chart)
    // This ensures duplicate detection works correctly for charts with different value ranges
    final yRange = data.maxY - data.minY;
    // Use 0.5% of Y-axis range as tolerance, or minimum 1 pixel worth of value
    final tolerance = yRange > 0
        ? max(yRange * 0.005, yRange / 1000)
        : 0.0001; // Fallback for edge case where range is 0

    // Helper function to check if two widgets should stack based on their data Y values
    // and whether they're clamped or not
    bool shouldStackWidgets({
      required int currentIndex,
      required double currentDataY,
      required bool currentIsClamped,
      required bool currentIsClampedToTop,
      required int prevIndex,
      required double prevDataY,
      required bool prevIsClamped,
      required bool prevIsClampedToTop,
    }) {
      // Clamped and non-clamped widgets should never stack (they're at different data Y positions)
      if (currentIsClamped != prevIsClamped) {
        return false;
      }

      // Both are clamped: only stack if they're at the same edge
      if (currentIsClamped && prevIsClamped) {
        return currentIsClampedToTop == prevIsClampedToTop;
      }

      // Both are non-clamped: only stack if they're at the same/similar data Y value
      if (!currentIsClamped && !prevIsClamped) {
        final dataYDiff = (currentDataY - prevDataY).abs();
        return dataYDiff < tolerance || currentDataY == prevDataY;
      }

      return false;
    }

    // Process top-clamped widgets: use collision detection for proper stacking
    // Account for label offset to position beyond vertical line labels
    // Vertical labels with showOnTopOfTheChartBoxArea are positioned outside chart bounds
    const baseClampedY = -_clampLabelOffset; // Base position above chart edge
    for (final clampedData in topClampedPositions) {
      final widgetSize = _rightWidgetSizes[clampedData.index];
      final widgetHeight = widgetSize?.height ?? 30.0;
      final line =
          linesWithWidgets.firstWhere((l) => l.index == clampedData.index).line;
      final stackingSpacing = line.rightWidgetStackingSpacing +
          data.extraLinesData.rightWidgetAdditionalStackingPadding;

      // Start from base clamped position
      double currentY = baseClampedY;
      double maxVerticalOffset = 0;

      // Check for collisions with previously positioned widgets
      // Only stack with other top-clamped widgets (same edge)
      for (int j = 0; j < positions.length; j++) {
        final prevPos = positions[j];

        // Get previous widget's data Y value
        final prevLineData = linesWithWidgets.firstWhere(
          (l) => l.index == prevPos.index,
        );
        final prevDataY = prevLineData.line.y;

        // Check if widgets should stack based on data Y values and clamp status
        if (!shouldStackWidgets(
          currentIndex: clampedData.index,
          currentDataY: clampedData.originalY,
          currentIsClamped: true,
          currentIsClampedToTop: true,
          prevIndex: prevPos.index,
          prevDataY: prevDataY,
          prevIsClamped: prevPos.isClamped,
          prevIsClampedToTop: prevPos.isClampedToTop,
        )) {
          continue; // Skip collision check if they shouldn't stack
        }

        final prevWidgetSize = _rightWidgetSizes[prevPos.index];
        final prevHeight = prevWidgetSize?.height ?? 30.0;
        final prevY = prevPos.y + prevPos.verticalOffset;

        // Check if widgets overlap
        final currentTop = currentY - widgetHeight / 2;
        final currentBottom = currentY + widgetHeight / 2;
        final prevTop = prevY - prevHeight / 2;
        final prevBottom = prevY + prevHeight / 2;

        if (currentTop < prevBottom + stackingSpacing &&
            currentBottom > prevTop - stackingSpacing) {
          // Collision detected - stack below previous widget
          final offset = prevBottom - currentY + stackingSpacing;
          if (offset > maxVerticalOffset) {
            maxVerticalOffset = offset;
          }
        }
      }

      positions.add((
        index: clampedData.index,
        y: currentY,
        verticalOffset: maxVerticalOffset,
        isClamped: true,
        isClampedToTop: true,
      ));
    }

    // Process non-clamped widgets: use existing collision detection
    for (int i = 0; i < nonClampedPositions.length; i++) {
      final posData = nonClampedPositions[i];
      final currentWidgetSize = _rightWidgetSizes[posData.index];
      final currentHeight = currentWidgetSize?.height ?? 30.0;
      final currentY = posData.y;
      final currentLine =
          linesWithWidgets.firstWhere((l) => l.index == posData.index).line;
      final currentStackingSpacing = currentLine.rightWidgetStackingSpacing;
      final additionalStackingPadding =
          data.extraLinesData.rightWidgetAdditionalStackingPadding;
      double maxVerticalOffset = 0;

      // Check for collisions with previous widgets
      // Only stack with other non-clamped widgets at the same/similar data Y value
      for (int j = 0; j < positions.length; j++) {
        final prevPos = positions[j];

        // Get previous widget's data Y value
        final prevLineData = linesWithWidgets.firstWhere(
          (l) => l.index == prevPos.index,
        );
        final prevDataY = prevLineData.line.y;

        // Check if widgets should stack based on data Y values and clamp status
        if (!shouldStackWidgets(
          currentIndex: posData.index,
          currentDataY: posData.originalY,
          currentIsClamped: false,
          currentIsClampedToTop: false,
          prevIndex: prevPos.index,
          prevDataY: prevDataY,
          prevIsClamped: prevPos.isClamped,
          prevIsClampedToTop: prevPos.isClampedToTop,
        )) {
          continue; // Skip collision check if they shouldn't stack
        }

        final prevWidgetSize = _rightWidgetSizes[prevPos.index];
        final prevHeight = prevWidgetSize?.height ?? 30.0;
        final prevY = prevPos.y + prevPos.verticalOffset;

        // Check if widgets overlap
        final currentTop = currentY - currentHeight / 2;
        final currentBottom = currentY + currentHeight / 2;
        final prevTop = prevY - prevHeight / 2;
        final prevBottom = prevY + prevHeight / 2;

        // Use the current widget's stacking spacing + additional configurable padding
        final stackingSpacing =
            currentStackingSpacing + additionalStackingPadding;
        if (currentTop < prevBottom + stackingSpacing &&
            currentBottom > prevTop - stackingSpacing) {
          // Collision detected - stack below previous widget
          final offset = prevBottom - currentY + stackingSpacing;
          if (offset > maxVerticalOffset) {
            maxVerticalOffset = offset;
          }
        }
      }

      positions.add((
        index: posData.index,
        y: currentY,
        verticalOffset: maxVerticalOffset,
        isClamped: false,
        isClampedToTop: false,
      ));
    }

    // Process bottom-clamped widgets: use collision detection for proper stacking
    // Account for label offset to position beyond vertical line labels
    // Use the same labelOffset as top-clamped widgets
    final baseBottomClampedY =
        chartHeight + _clampLabelOffset; // Base position below chart edge
    for (final clampedData in bottomClampedPositions) {
      final widgetSize = _rightWidgetSizes[clampedData.index];
      final widgetHeight = widgetSize?.height ?? 30.0;
      final line =
          linesWithWidgets.firstWhere((l) => l.index == clampedData.index).line;
      final stackingSpacing = line.rightWidgetStackingSpacing +
          data.extraLinesData.rightWidgetAdditionalStackingPadding;

      // Start from base clamped position
      double currentY = baseBottomClampedY;
      double maxVerticalOffset = 0;

      // Check for collisions with previously positioned widgets
      // Only stack with other bottom-clamped widgets (same edge)
      for (int j = 0; j < positions.length; j++) {
        final prevPos = positions[j];

        // Get previous widget's data Y value
        final prevLineData = linesWithWidgets.firstWhere(
          (l) => l.index == prevPos.index,
        );
        final prevDataY = prevLineData.line.y;

        // Check if widgets should stack based on data Y values and clamp status
        if (!shouldStackWidgets(
          currentIndex: clampedData.index,
          currentDataY: clampedData.originalY,
          currentIsClamped: true,
          currentIsClampedToTop: false,
          prevIndex: prevPos.index,
          prevDataY: prevDataY,
          prevIsClamped: prevPos.isClamped,
          prevIsClampedToTop: prevPos.isClampedToTop,
        )) {
          continue; // Skip collision check if they shouldn't stack
        }

        final prevWidgetSize = _rightWidgetSizes[prevPos.index];
        final prevHeight = prevWidgetSize?.height ?? 30.0;
        final prevY = prevPos.y + prevPos.verticalOffset;

        // Check if widgets overlap
        final currentTop = currentY - widgetHeight / 2;
        final currentBottom = currentY + widgetHeight / 2;
        final prevTop = prevY - prevHeight / 2;
        final prevBottom = prevY + prevHeight / 2;

        if (currentTop < prevBottom + stackingSpacing &&
            currentBottom > prevTop - stackingSpacing) {
          // Collision detected - stack above previous widget (for bottom-clamped, we stack upward)
          final offset = prevTop - currentY - stackingSpacing;
          if (offset < maxVerticalOffset) {
            maxVerticalOffset = offset;
          }
        }
      }

      positions.add((
        index: clampedData.index,
        y: currentY,
        verticalOffset: maxVerticalOffset,
        isClamped: true,
        isClampedToTop: false,
      ));
    }

    // Final sort by Y position (top to bottom) to ensure proper rendering order
    positions.sort((a, b) => a.y.compareTo(b.y));

    return positions;
  }

  /// Helper to get pixel Y from chart Y coordinate
  /// This matches the calculation used in AxisChartPainter.getPixelY
  /// Uses animatedData if available for smooth animation
  /// When shouldClamp is true, clamps Y values to chart bounds
  double _getPixelY(
    double chartY,
    Size viewSize,
    Rect? chartVirtualRect, {
    bool shouldClamp = false,
  }) {
    // Use animated data for positioning if available, otherwise use target data
    final data = widget.animatedData ?? widget.data;

    // Clamp Y value to chart bounds when requested
    final clampedY = shouldClamp ? chartY.clamp(data.minY, data.maxY) : chartY;

    // Use chartVirtualRect size if available (for scaling), otherwise use viewSize
    final usableSize = chartVirtualRect?.size ?? viewSize;

    final chartHeight = usableSize.height;
    final minY = data.minY;
    final maxY = data.maxY;
    final yDiff = maxY - minY;

    if (yDiff == 0) return chartHeight / 2;

    // Calculate normalized position (0 to 1 from bottom to top in chart coordinates)
    final normalizedY = (clampedY - minY) / yDiff;

    // Convert to pixel Y (top is 0 in Flutter, but bottom is 0 in chart coordinates)
    // So we flip: pixelY = chartHeight - (normalizedY * chartHeight)
    final pixelY = chartHeight - (normalizedY * chartHeight);

    // Note: chartVirtualRect offsets are for canvas coordinates in painters
    // In widget overlay coordinates, we're already positioned relative to chartRect
    return pixelY;
  }

  /// Helper to get pixel X from chart X coordinate
  /// This matches the calculation used in AxisChartPainter.getPixelX
  /// Uses animatedData if available for smooth animation
  double _getPixelX(
    double chartX,
    Size viewSize,
    Rect? chartVirtualRect,
  ) {
    // Use animated data for positioning if available, otherwise use target data
    final data = widget.animatedData ?? widget.data;

    // Use chartVirtualRect size if available (for scaling), otherwise use viewSize
    final usableSize = chartVirtualRect?.size ?? viewSize;

    // Account for internal padding between chart content and right widgets
    final hasRightWidgets = data.extraLinesData.horizontalLines
        .any((line) => line.rightWidget != null);
    final internalPadding =
        hasRightWidgets ? data.extraLinesData.rightWidgetInternalPadding : 0.0;

    // Create adjusted usable size for X calculations (reduce width by internal padding)
    final adjustedUsableSize = Size(
      usableSize.width - internalPadding,
      usableSize.height,
    );

    final chartWidth = adjustedUsableSize.width;
    final minX = data.minX;
    final maxX = data.maxX;
    final xDiff = maxX - minX;

    if (xDiff == 0) return chartWidth / 2;

    // Calculate normalized position (0 to 1 from left to right)
    final normalizedX = (chartX - minX) / xDiff;

    // Convert to pixel X (left is 0 in Flutter, same as chart coordinates)
    final pixelX = normalizedX * chartWidth;

    // Note: chartVirtualRect offsets are for canvas coordinates in painters
    // In widget overlay coordinates, we're already positioned relative to chartRect
    return pixelX;
  }

  /// Collects line chart bars that have trailingWidget set
  /// Uses animatedData if available for smooth animation, otherwise uses target data
  List<({LineChartBarData barData, int index, FlSpot lastSpot})>
      _getLineBarsWithTrailingWidgets() {
    final bars = <({LineChartBarData barData, int index, FlSpot lastSpot})>[];

    // Check if this is LineChartData
    final data = widget.animatedData ?? widget.data;
    if (data is! LineChartData) {
      return bars;
    }

    for (int i = 0; i < data.lineBarsData.length; i++) {
      final barData = data.lineBarsData[i];
      if (barData.trailingWidget != null && barData.show) {
        // Find the last visible spot (handle null spots that split lines)
        final lastSpot = _findLastVisibleSpot(barData, data);
        if (lastSpot != null) {
          bars.add((barData: barData, index: i, lastSpot: lastSpot));
        }
      }
    }
    return bars;
  }

  /// Finds the last visible spot in a line chart bar data
  /// Handles null spots that create line segments - finds last spot in last segment
  FlSpot? _findLastVisibleSpot(
      LineChartBarData barData, LineChartData chartData) {
    if (barData.spots.isEmpty) return null;

    // Find the last valid (non-null) spot
    FlSpot? lastSpot;
    for (var i = barData.spots.length - 1; i >= 0; i--) {
      final spot = barData.spots[i];
      if (!spot.isNull()) {
        lastSpot = spot;
        break;
      }
    }

    if (lastSpot == null) return null;

    // Check if the last spot is within chart bounds
    final spotWithinBounds = lastSpot.x >= chartData.minX &&
        lastSpot.x <= chartData.maxX &&
        lastSpot.y >= chartData.minY &&
        lastSpot.y <= chartData.maxY;

    return spotWithinBounds ? lastSpot : null;
  }

  // Applies the inverse transformation to the chart to get the zoomed
  // bounding box.
  //
  // The transformation matrix is inverted because the bounding box needs to
  // grow beyond the chart's boundaries when the chart is scaled in order
  // for its content to be laid out on the larger area. This leads to the
  // scaling effect.
  Rect? _calculateAdjustedRect(Rect rect) {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale == 1.0) {
      return null;
    }
    final inverseMatrix = Matrix4.inverted(_transformationController.value);

    final chartVirtualQuad = CustomInteractiveViewer.transformViewport(
      inverseMatrix,
      rect,
    );

    final chartVirtualRect = CustomInteractiveViewer.axisAlignedBoundingBox(
      chartVirtualQuad,
    );

    return Rect.fromLTWH(
      _canScaleHorizontally ? chartVirtualRect.left : rect.left,
      _canScaleVertically ? chartVirtualRect.top : rect.top,
      _canScaleHorizontally ? chartVirtualRect.width : rect.width,
      _canScaleVertically ? chartVirtualRect.height : rect.height,
    );
  }

  bool get showLeftTitles {
    if (!widget.data.titlesData.show) {
      return false;
    }
    final showAxisTitles = widget.data.titlesData.leftTitles.showAxisTitles;
    final showSideTitles = widget.data.titlesData.leftTitles.showSideTitles;
    return showAxisTitles || showSideTitles;
  }

  bool get showRightTitles {
    if (!widget.data.titlesData.show) {
      return false;
    }
    final showAxisTitles = widget.data.titlesData.rightTitles.showAxisTitles;
    final showSideTitles = widget.data.titlesData.rightTitles.showSideTitles;
    return showAxisTitles || showSideTitles;
  }

  bool get showTopTitles {
    if (!widget.data.titlesData.show) {
      return false;
    }
    final showAxisTitles = widget.data.titlesData.topTitles.showAxisTitles;
    final showSideTitles = widget.data.titlesData.topTitles.showSideTitles;
    return showAxisTitles || showSideTitles;
  }

  bool get showBottomTitles {
    if (!widget.data.titlesData.show) {
      return false;
    }
    final showAxisTitles = widget.data.titlesData.bottomTitles.showAxisTitles;
    final showSideTitles = widget.data.titlesData.bottomTitles.showSideTitles;
    return showAxisTitles || showSideTitles;
  }

  List<Widget> _stackWidgets(BoxConstraints constraints) {
    final baseMargin = widget.data.titlesData.allSidesPadding;
    final borderData = widget.data.borderData.isVisible()
        ? widget.data.borderData.border
        : null;

    final borderWidth =
        borderData == null ? 0 : borderData.dimensions.horizontal;
    final borderHeight =
        borderData == null ? 0 : borderData.dimensions.vertical;

    // Calculate right widget padding
    final rectForRightPadding = Rect.fromLTRB(
      0,
      0,
      constraints.maxWidth - baseMargin.horizontal - borderWidth,
      constraints.maxHeight - baseMargin.vertical - borderHeight,
    );
    final adjustedRectForRightPadding =
        _calculateAdjustedRect(rectForRightPadding);
    final rightWidgetPadding = _calculateRightWidgetPadding(
      adjustedRectForRightPadding?.height ?? rectForRightPadding.height,
    );

    // Adjust margin to include right widget padding
    final margin = EdgeInsets.only(
      left: baseMargin.left,
      top: baseMargin.top,
      right: baseMargin.right + rightWidgetPadding,
      bottom: baseMargin.bottom,
    );

    final rect = Rect.fromLTRB(
      0,
      0,
      constraints.maxWidth - margin.horizontal - borderWidth,
      constraints.maxHeight - margin.vertical - borderHeight,
    );

    final adjustedRect = _calculateAdjustedRect(rect);

    final virtualRect = switch (_transformationConfig.scaleAxis) {
      FlScaleAxis.none => null,
      FlScaleAxis() => adjustedRect,
    };

    final chart = KeyedSubtree(
      key: _chartKey,
      child: widget.chartBuilder(context, virtualRect),
    );

    final child = switch (_transformationConfig.scaleAxis) {
      FlScaleAxis.none => chart,
      FlScaleAxis() => CustomInteractiveViewer(
          transformationController: _transformationController,
          clipBehavior: Clip.none,
          trackpadScrollCausesScale:
              _transformationConfig.trackpadScrollCausesScale,
          maxScale: _transformationConfig.maxScale,
          minScale: _transformationConfig.minScale,
          panEnabled: _transformationConfig.panEnabled,
          scaleEnabled: _transformationConfig.scaleEnabled,
          child: SizedBox(
            width: rect.width,
            height: rect.height,
            child: chart,
          ),
        ),
    };

    final widgets = <Widget>[
      Container(
        margin: margin,
        decoration: BoxDecoration(border: borderData),
        child: child,
      ),
    ];

    int insertIndex(bool drawBelow) => drawBelow ? 0 : widgets.length;

    if (showLeftTitles) {
      widgets.insert(
        insertIndex(widget.data.titlesData.leftTitles.drawBelowEverything),
        SideTitlesWidget(
          side: AxisSide.left,
          axisChartData: widget.data,
          parentSize: constraints.biggest,
          chartVirtualRect: adjustedRect,
        ),
      );
    }

    if (showTopTitles) {
      widgets.insert(
        insertIndex(widget.data.titlesData.topTitles.drawBelowEverything),
        SideTitlesWidget(
          side: AxisSide.top,
          axisChartData: widget.data,
          parentSize: constraints.biggest,
          chartVirtualRect: adjustedRect,
        ),
      );
    }

    if (showRightTitles) {
      widgets.insert(
        insertIndex(widget.data.titlesData.rightTitles.drawBelowEverything),
        SideTitlesWidget(
          side: AxisSide.right,
          axisChartData: widget.data,
          parentSize: constraints.biggest,
          chartVirtualRect: adjustedRect,
        ),
      );
    }

    if (showBottomTitles) {
      widgets.insert(
        insertIndex(widget.data.titlesData.bottomTitles.drawBelowEverything),
        SideTitlesWidget(
          side: AxisSide.bottom,
          axisChartData: widget.data,
          parentSize: constraints.biggest,
          chartVirtualRect: adjustedRect,
        ),
      );
    }

    // Add right widget overlay layer
    final linesWithWidgets = _getHorizontalLinesWithWidgets();
    if (linesWithWidgets.isNotEmpty) {
      // Initialize keys for widgets that don't have them
      for (final lineData in linesWithWidgets) {
        if (!_rightWidgetKeys.containsKey(lineData.index)) {
          _rightWidgetKeys[lineData.index] = GlobalKey();
        }
      }

      // Remove keys for widgets that no longer exist
      _rightWidgetKeys.removeWhere((index, _) {
        return !linesWithWidgets.any((lineData) => lineData.index == index);
      });
      _rightWidgetSizes.removeWhere((index, _) {
        return !linesWithWidgets.any((lineData) => lineData.index == index);
      });

      widgets.add(
        _RightWidgetOverlay(
          linesWithWidgets: linesWithWidgets,
          chartVirtualRect: adjustedRect,
          parentSize: constraints.biggest,
          margin: margin,
          borderData: borderData,
          widgetKeys: _rightWidgetKeys,
          widgetSizes: _rightWidgetSizes,
          data: widget.animatedData ?? widget.data,
          onMeasure: _measureRightWidgets,
          calculatePositions: _calculateWidgetPositions,
          getPixelY: _getPixelY,
        ),
      );
    }

    // Add trailing widget overlay for line charts
    final barsWithTrailingWidgets = _getLineBarsWithTrailingWidgets();
    if (barsWithTrailingWidgets.isNotEmpty) {
      // Initialize keys for widgets that don't have them
      for (final barData in barsWithTrailingWidgets) {
        if (!_trailingWidgetKeys.containsKey(barData.index)) {
          _trailingWidgetKeys[barData.index] = GlobalKey();
        }
      }

      // Remove keys for widgets that no longer exist
      _trailingWidgetKeys.removeWhere((index, _) {
        return !barsWithTrailingWidgets
            .any((barData) => barData.index == index);
      });
      _trailingWidgetSizes.removeWhere((index, _) {
        return !barsWithTrailingWidgets
            .any((barData) => barData.index == index);
      });

      widgets.add(
        _TrailingWidgetOverlay(
          barsWithWidgets: barsWithTrailingWidgets,
          chartVirtualRect: adjustedRect,
          parentSize: constraints.biggest,
          margin: margin,
          borderData: borderData,
          widgetKeys: _trailingWidgetKeys,
          widgetSizes: _trailingWidgetSizes,
          data: widget.animatedData ?? widget.data,
          onMeasure: _measureTrailingWidgets,
          getPixelX: _getPixelX,
          getPixelY: _getPixelY,
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RotatedBox(
          quarterTurns: widget.data.rotationQuarterTurns,
          child: Stack(
            children: _stackWidgets(constraints),
          ),
        );
      },
    );
  }
}

/// Widget overlay that renders right-side widgets for horizontal lines
class _RightWidgetOverlay extends StatefulWidget {
  const _RightWidgetOverlay({
    required this.linesWithWidgets,
    required this.chartVirtualRect,
    required this.parentSize,
    required this.margin,
    required this.borderData,
    required this.widgetKeys,
    required this.widgetSizes,
    required this.data,
    required this.onMeasure,
    required this.calculatePositions,
    required this.getPixelY,
  });

  final List<({HorizontalLine line, int index})> linesWithWidgets;
  final Rect? chartVirtualRect;
  final Size parentSize;
  final EdgeInsets margin;
  final BoxBorder? borderData;
  final Map<int, GlobalKey> widgetKeys;
  final Map<int, Size> widgetSizes;
  final AxisChartData data;
  final VoidCallback onMeasure;
  final List<
          ({
            int index,
            double y,
            double verticalOffset,
            bool isClamped,
            bool isClampedToTop
          })>
      Function(
    double chartHeight,
    Size viewSize,
    Rect? chartVirtualRect,
  ) calculatePositions;
  final double Function(double chartY, Size viewSize, Rect? chartVirtualRect)
      getPixelY;

  @override
  State<_RightWidgetOverlay> createState() => _RightWidgetOverlayState();
}

class _RightWidgetOverlayState extends State<_RightWidgetOverlay> {
  // Track previous vertical offsets to detect changes for animation
  final Map<int, double> _previousVerticalOffsets = {};

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      widget.onMeasure();
    });
  }

  @override
  void didUpdateWidget(_RightWidgetOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      widget.onMeasure();
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderWidth = widget.borderData == null
        ? 0
        : widget.borderData!.dimensions.horizontal;
    final chartRect = Rect.fromLTRB(
      widget.margin.left,
      widget.margin.top,
      widget.parentSize.width - widget.margin.right - borderWidth,
      widget.parentSize.height - widget.margin.bottom - borderWidth,
    );

    final viewSize = chartRect.size;
    final chartHeight = widget.chartVirtualRect?.height ?? viewSize.height;
    final positions = widget.calculatePositions(
      chartHeight,
      viewSize,
      widget.chartVirtualRect,
    );

    // Build a map from index to position data for quick lookup
    final positionMap = <int,
        ({
      double y,
      double verticalOffset,
      bool isClamped,
      bool isClampedToTop
    })>{};
    for (final pos in positions) {
      positionMap[pos.index] = (
        y: pos.y,
        verticalOffset: pos.verticalOffset,
        isClamped: pos.isClamped,
        isClampedToTop: pos.isClampedToTop,
      );
    }

    // Check if all widgets have been measured
    final allMeasured = widget.linesWithWidgets.every(
      (lineData) => widget.widgetSizes.containsKey(lineData.index),
    );

    // Calculate maximum width from all measured widgets (natural/unconstrained widths)
    double maxWidgetWidth = 0;
    for (final size in widget.widgetSizes.values) {
      if (size.width > maxWidgetWidth) {
        maxWidgetWidth = size.width;
      }
    }

    // Determine if we should measure (render unconstrained) or display (render constrained)
    // We display constrained if: all widgets measured AND maxWidth > 0
    // Otherwise, we measure (render unconstrained to get natural widths)
    final constrainedWidth =
        (allMeasured && maxWidgetWidth > 0) ? maxWidgetWidth : null;

    // Position overlay at the right edge of chart content area
    // The positions calculated are relative to viewSize (chart content area)
    return Positioned(
      left: chartRect.right,
      top: chartRect.top,
      right: 0,
      bottom: widget.parentSize.height - chartRect.bottom,
      child: SizedBox(
        width: widget.margin.right,
        height: viewSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Draw line segments from chart edge to widgets
            for (final lineData in widget.linesWithWidgets)
              Builder(
                builder: (context) {
                  final index = lineData.index;
                  final line = lineData.line;

                  // Get position for this widget
                  final position = positionMap[index];
                  if (position == null) return const SizedBox.shrink();

                  // CRITICAL: Only show line segment for base widgets (verticalOffset == 0)
                  // This follows the pill stacking logic where the first widget at a Y position
                  // has verticalOffset == 0 and aligns with the painted horizontal line
                  // Widgets that are stacked have verticalOffset != 0 and should not show their line segment
                  const offsetTolerance =
                      0.001; // Small tolerance for floating point comparison
                  if (position.verticalOffset.abs() > offsetTolerance) {
                    // This widget is stacked (not at base position), hide its line segment
                    return const SizedBox.shrink();
                  }

                  // Y position animates naturally via animatedData - use regular Positioned
                  // Only animate the verticalOffset separately when it changes
                  final baseY =
                      position.y; // This animates smoothly via animatedData
                  final currentOffset = position.verticalOffset;
                  final previousOffset =
                      _previousVerticalOffsets[index] ?? currentOffset;

                  // Update previous offset after this frame (so current frame uses old value for animation)
                  if (previousOffset != currentOffset) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _previousVerticalOffsets[index] = currentOffset;
                        });
                      }
                    });
                  }

                  // Line extends from the chart edge (where overlay starts, left: 0)
                  // to the right edge of the widget (where widget ends)
                  // Widget is positioned at right: 0, so line should extend to widget.margin.right
                  final lineLength = widget.margin.right;
                  if (lineLength <= 0) return const SizedBox.shrink();

                  // For clamped widgets, ensure line is positioned beyond chart edges to be above/below labels
                  // Top-clamped: line at y=0 - _clampLabelOffset (above top edge, beyond labels)
                  // Bottom-clamped: line at y=chartHeight + _clampLabelOffset (below bottom edge, beyond labels)
                  // For non-clamped widgets, line is at baseY (before stacking offset) so all stacked widgets share the same line
                  final lineY = position.isClamped
                      ? (position.isClampedToTop
                          ? 0.0 -
                              _AxisChartScaffoldWidgetState._clampLabelOffset
                          : chartHeight +
                              _AxisChartScaffoldWidgetState._clampLabelOffset)
                      : baseY; // Use baseY directly, not baseY + offset, so line is at base position

                  // Use this widget's own line properties
                  // When we're at base, we use our own properties
                  // When we're stacked and there's no base widget, we also use our own properties
                  final actualLineToUse = line;

                  // Use regular Positioned - Y animates via animatedData
                  // Use AnimatedContainer to animate offset changes separately
                  // For clamped widgets, line is at the edge; for non-clamped, it follows the position
                  return Positioned(
                    left: 0,
                    top: lineY - actualLineToUse.strokeWidth / 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.linear,
                      transform: position.isClamped
                          ? Matrix4.identity()
                          : Matrix4.translationValues(
                              0, currentOffset - previousOffset, 0),
                      child: CustomPaint(
                        size: Size(
                          lineLength,
                          actualLineToUse.strokeWidth,
                        ),
                        painter: _HorizontalLinePainter(
                          color: actualLineToUse.color ?? Colors.grey,
                          strokeWidth: actualLineToUse.strokeWidth,
                          dashArray: actualLineToUse.dashArray,
                          strokeCap: actualLineToUse.strokeCap,
                        ),
                      ),
                    ),
                  );
                },
              ),
            // Widgets positioned at right edge
            for (final lineData in widget.linesWithWidgets)
              Builder(
                builder: (context) {
                  final index = lineData.index;
                  final position = positionMap[index];
                  if (position == null) return const SizedBox.shrink();

                  // Position is already relative to viewSize (chart content area)
                  // Y position animates naturally via animatedData - use regular Positioned
                  // Only animate the verticalOffset separately when it changes
                  final baseY =
                      position.y; // This animates smoothly via animatedData
                  final currentOffset = position.verticalOffset;
                  final previousOffset =
                      _previousVerticalOffsets[index] ?? currentOffset;

                  // Update previous offset after this frame (so current frame uses old value for animation)
                  if (previousOffset != currentOffset) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _previousVerticalOffsets[index] = currentOffset;
                        });
                      }
                    });
                  }

                  final widgetKey = widget.widgetKeys[index]!;
                  final widgetHeight = widget.widgetSizes[index]?.height ?? 30;

                  final widgetContent = widget.linesWithWidgets
                      .firstWhere((l) => l.index == index)
                      .line
                      .rightWidget!;

                  // If measuring, use IntrinsicWidth to measure natural width
                  // Otherwise, apply uniform width constraint to ALL widgets
                  final childWidget = constrainedWidth != null
                      ? SizedBox(
                          width: constrainedWidth,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: widgetContent,
                          ),
                        )
                      : IntrinsicWidth(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: widgetContent,
                          ),
                        );

                  // Use regular Positioned - Y animates via animatedData (follows chart animation pace)
                  // Use AnimatedContainer to animate offset changes separately (only when stacking changes)
                  return Positioned(
                    right: 0,
                    top: baseY + previousOffset - widgetHeight / 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.linear,
                      transform: Matrix4.translationValues(
                          0, currentOffset - previousOffset, 0),
                      child: IgnorePointer(
                        ignoring: false,
                        child: RepaintBoundary(
                          key: widgetKey,
                          child: childWidget,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter to draw horizontal line segments in the widget overlay
class _HorizontalLinePainter extends CustomPainter {
  _HorizontalLinePainter({
    required this.color,
    required this.strokeWidth,
    this.dashArray,
    this.strokeCap = StrokeCap.butt,
  });

  final Color color;
  final double strokeWidth;
  final List<int>? dashArray;
  final StrokeCap strokeCap;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = strokeCap;

    final from = Offset(0, size.height / 2);
    final to = Offset(size.width, size.height / 2);

    var path = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(to.dx, to.dy);

    if (dashArray != null) {
      path = path.toDashedPath(dashArray);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HorizontalLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashArray != dashArray ||
        oldDelegate.strokeCap != strokeCap;
  }
}

/// Widget overlay that renders trailing widgets at the last point of line chart bars
class _TrailingWidgetOverlay extends StatefulWidget {
  const _TrailingWidgetOverlay({
    required this.barsWithWidgets,
    required this.chartVirtualRect,
    required this.parentSize,
    required this.margin,
    required this.borderData,
    required this.widgetKeys,
    required this.widgetSizes,
    required this.data,
    required this.onMeasure,
    required this.getPixelX,
    required this.getPixelY,
  });

  final List<({LineChartBarData barData, int index, FlSpot lastSpot})>
      barsWithWidgets;
  final Rect? chartVirtualRect;
  final Size parentSize;
  final EdgeInsets margin;
  final BoxBorder? borderData;
  final Map<int, GlobalKey> widgetKeys;
  final Map<int, Size> widgetSizes;
  final AxisChartData data;
  final VoidCallback onMeasure;
  final double Function(double chartX, Size viewSize, Rect? chartVirtualRect)
      getPixelX;
  final double Function(double chartY, Size viewSize, Rect? chartVirtualRect)
      getPixelY;

  @override
  State<_TrailingWidgetOverlay> createState() => _TrailingWidgetOverlayState();
}

class _TrailingWidgetOverlayState extends State<_TrailingWidgetOverlay> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      widget.onMeasure();
    });
  }

  @override
  void didUpdateWidget(_TrailingWidgetOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      widget.onMeasure();
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderWidth = widget.borderData == null
        ? 0
        : widget.borderData!.dimensions.horizontal;
    final chartRect = Rect.fromLTRB(
      widget.margin.left,
      widget.margin.top,
      widget.parentSize.width - widget.margin.right - borderWidth,
      widget.parentSize.height - widget.margin.bottom - borderWidth,
    );

    final viewSize = chartRect.size;

    // Position overlay over the entire chart area
    return Positioned(
      left: chartRect.left,
      top: chartRect.top,
      right: widget.parentSize.width - chartRect.right,
      bottom: widget.parentSize.height - chartRect.bottom,
      child: SizedBox(
        width: viewSize.width,
        height: viewSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final barData in widget.barsWithWidgets)
              Builder(
                builder: (context) {
                  final index = barData.index;
                  final spot = barData.lastSpot;
                  final trailingWidget = barData.barData.trailingWidget;
                  final padding = barData.barData.trailingWidgetPadding;

                  if (trailingWidget == null) {
                    return const SizedBox.shrink();
                  }

                  // Calculate pixel coordinates for the last spot
                  final pixelX = widget.getPixelX(
                    spot.x,
                    viewSize,
                    widget.chartVirtualRect,
                  );
                  final pixelY = widget.getPixelY(
                    spot.y,
                    viewSize,
                    widget.chartVirtualRect,
                  );

                  final widgetKey = widget.widgetKeys[index]!;
                  final widgetSize = widget.widgetSizes[index];

                  // If widget hasn't been measured yet, render it unconstrained to measure it
                  // Otherwise, position it centered on the point
                  if (widgetSize == null) {
                    // Measure phase: render unconstrained to get natural size
                    // Use UnconstrainedBox to allow intrinsic size measurement
                    return Positioned(
                      left: pixelX,
                      top: pixelY,
                      child: IgnorePointer(
                        ignoring: true,
                        child: RepaintBoundary(
                          key: widgetKey,
                          child: UnconstrainedBox(
                            child: trailingWidget,
                          ),
                        ),
                      ),
                    );
                  }

                  // Display phase: position centered on the point with measured size
                  final widgetX = pixelX -
                      widgetSize.width / 2 +
                      padding.left -
                      padding.right;
                  final widgetY = pixelY -
                      widgetSize.height / 2 +
                      padding.top -
                      padding.bottom;

                  return Positioned(
                    left: widgetX,
                    top: widgetY,
                    child: IgnorePointer(
                      ignoring: false,
                      child: RepaintBoundary(
                        key: widgetKey,
                        child: trailingWidget,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
