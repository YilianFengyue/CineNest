import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ProfileGraphWebView extends StatelessWidget {
  const ProfileGraphWebView({
    super.key,
    required this.nodes,
    required this.edges,
    this.height = 340,
  });

  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('暂无图谱数据，先同步画像')),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final html = _buildHtml(
      nodes: nodes,
      edges: edges,
      primaryHex: _colorToHex(cs.primary),
      bgHex: _colorToHex(cs.surface),
      textHex: _colorToHex(cs.onSurface),
      isDark: isDark,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: InAppWebView(
          initialData: InAppWebViewInitialData(data: html),
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            disableHorizontalScroll: false,
            disableVerticalScroll: false,
            supportZoom: false,
            javaScriptEnabled: true,
          ),
        ),
      ),
    );
  }
}

String _colorToHex(Color c) {
  final r = c.r * 255;
  final g = c.g * 255;
  final b = c.b * 255;
  return '#${r.toInt().toRadixString(16).padLeft(2, '0')}'
      '${g.toInt().toRadixString(16).padLeft(2, '0')}'
      '${b.toInt().toRadixString(16).padLeft(2, '0')}';
}

const _kTypeColors = {
  'user': '#6750A4',
  'genre': '#0097A7',
  'source': '#1976D2',
  'movie': '#F57C00',
  'trait': '#388E3C',
  'risk': '#D32F2F',
};

const _kTypeSymbols = {
  'user': 'circle',
  'genre': 'diamond',
  'source': 'rect',
  'movie': 'roundRect',
  'trait': 'triangle',
  'risk': 'triangle',
};

String _buildHtml({
  required List<Map<String, dynamic>> nodes,
  required List<Map<String, dynamic>> edges,
  required String primaryHex,
  required String bgHex,
  required String textHex,
  required bool isDark,
}) {
  final echartsNodes = nodes.map((n) {
    final type = n['type']?.toString() ?? 'genre';
    final value = (n['value'] is num) ? (n['value'] as num).toDouble() : 1.0;
    final isUser = type == 'user';
    return {
      'name': n['label']?.toString() ?? n['id']?.toString() ?? '',
      'symbolSize': isUser ? 38 : (14 + value * 3).clamp(14, 36),
      'itemStyle': {'color': _kTypeColors[type] ?? primaryHex},
      'symbol': _kTypeSymbols[type] ?? 'circle',
      'category': type,
      'label': {
        'show': isUser || value > 2,
        'fontSize': isUser ? 12 : 10,
        'color': textHex,
      },
    };
  }).toList();

  final echartsEdges = edges.map((e) {
    final w = (e['weight'] is num) ? (e['weight'] as num).toDouble() : 1.0;
    return {
      'source': e['source']?.toString() ?? '',
      'target': e['target']?.toString() ?? '',
      'lineStyle': {
        'width': (0.5 + w * 0.4).clamp(0.5, 3.0),
        'curveness': 0.15,
      },
      'label': {'show': false},
    };
  }).toList();

  // 用 source/target 字段匹配 node.name 的映射
  // ECharts graph 使用 name 做关联
  final nameById = <String, String>{};
  for (final n in nodes) {
    nameById[n['id']?.toString() ?? ''] =
        n['label']?.toString() ?? n['id']?.toString() ?? '';
  }
  for (final e in echartsEdges) {
    final src = e['source']?.toString() ?? '';
    final tgt = e['target']?.toString() ?? '';
    e['source'] = nameById[src] ?? src;
    e['target'] = nameById[tgt] ?? tgt;
  }

  final categories = _kTypeColors.keys.map((t) => {'name': t}).toList();

  final nodesJson = jsonEncode(echartsNodes);
  final edgesJson = jsonEncode(echartsEdges);
  final categoriesJson = jsonEncode(categories);

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<script src="https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js"></script>
<style>
  *{margin:0;padding:0}
  html,body,#c{width:100%;height:100%;background:$bgHex}
</style>
</head>
<body>
<div id="c"></div>
<script>
var c=echarts.init(document.getElementById('c'),${isDark ? "'dark'" : "null"});
c.setOption({
  animationDurationUpdate:800,
  tooltip:{show:true,formatter:function(p){return p.data.name||''}},
  legend:[{data:${categoriesJson.replaceAll('"name"', '"name"')},orient:'horizontal',bottom:4,textStyle:{color:'$textHex',fontSize:10}}],
  series:[{
    type:'graph',
    layout:'force',
    roam:true,
    draggable:true,
    force:{repulsion:180,edgeLength:[40,120],gravity:0.08},
    data:$nodesJson,
    links:$edgesJson,
    categories:$categoriesJson,
    emphasis:{focus:'adjacency',blurScope:'coordinateSystem'},
    lineStyle:{color:'source',opacity:0.45},
    label:{position:'bottom'},
    edgeLabel:{show:false},
  }]
});
window.addEventListener('resize',function(){c.resize()});
</script>
</body>
</html>
''';
}
