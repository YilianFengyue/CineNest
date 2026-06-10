import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cine_nest/models/movie_graph.dart';
import 'package:get/get.dart';
import 'package:cine_nest/router/app_pages.dart';

class MovieGraphWidget extends StatelessWidget {
  final MovieGraphResponse graph;
  const MovieGraphWidget({super.key, required this.graph});

  @override
  Widget build(BuildContext context) {
    if (graph.nodes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "电影关系图谱",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 320,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
              final nodes = graph.nodes;
              final links = graph.links;

              // 查找中心节点
              final centerNode = nodes.first;
              final outerNodes = nodes.skip(1).toList();

              return Stack(
                children: [
                  // 1. 绘制连线
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: GraphLinePainter(
                      center: center,
                      nodeCount: outerNodes.length,
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  ),

                  // 2. 中心节点
                  _PositionedNode(
                    offset: center,
                    node: centerNode,
                    isCenter: true,
                  ),

                  // 3. 环绕节点
                  ...List.generate(outerNodes.length, (index) {
                    final angle = (2 * pi / outerNodes.length) * index;
                    final radius = min(constraints.maxWidth, constraints.maxHeight) * 0.35;
                    final nodeOffset = Offset(
                      center.dx + radius * cos(angle),
                      center.dy + radius * sin(angle),
                    );

                    return _PositionedNode(
                      offset: nodeOffset,
                      node: outerNodes[index],
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PositionedNode extends StatelessWidget {
  final Offset offset;
  final GraphNode node;
  final bool isCenter;

  const _PositionedNode({
    required this.offset,
    required this.node,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color bgColor;
    IconData icon;

    switch (node.type) {
      case 'movie':
        bgColor = colorScheme.primary;
        icon = Icons.movie_outlined;
        break;
      case 'person':
        bgColor = Colors.orange;
        icon = Icons.person_outline;
        break;
      case 'genre':
        bgColor = Colors.teal;
        icon = Icons.category_outlined;
        break;
      case 'keyword':
        bgColor = Colors.purple;
        icon = Icons.tag;
        break;
      default:
        bgColor = colorScheme.secondary;
        icon = Icons.bubble_chart_outlined;
    }

    final size = isCenter ? 70.0 : 60.0;

    return Positioned(
      left: offset.dx - size / 2,
      top: offset.dy - size / 2,
      child: GestureDetector(
        onTap: () {
          if (node.type == 'movie' && node.movieId != null) {
            Get.toNamed(Routes.movieDetail, arguments: {'movieId': node.movieId}, preventDuplicates: false);
          } else {
            Get.snackbar("节点信息", "这是：${node.label} (${node.type})", snackPosition: SnackPosition.BOTTOM);
          }
        },
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isCenter ? bgColor : bgColor.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icon, color: Colors.white, size: isCenter ? 30 : 24),
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxWidth: 80),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                node.label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GraphLinePainter extends CustomPainter {
  final Offset center;
  final int nodeCount;
  final Color color;

  GraphLinePainter({required this.center, required this.nodeCount, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final radius = min(size.width, size.height) * 0.35;

    for (int i = 0; i < nodeCount; i++) {
      final angle = (2 * pi / nodeCount) * i;
      final target = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, target, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
