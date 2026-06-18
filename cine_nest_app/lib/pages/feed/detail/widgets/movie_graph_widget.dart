import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cine_nest/models/movie_graph.dart';

class MovieGraphWidget extends StatelessWidget {
  final MovieGraphResponse graph;
  const MovieGraphWidget({super.key, required this.graph});

  @override
  Widget build(BuildContext context) {
    if (graph.nodes.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final html = _buildGraphHtml(
      graph: graph,
      primaryHex: _colorToHex(cs.primary),
      bgHex: _colorToHex(cs.surface),
      textHex: _colorToHex(cs.onSurface),
      isDark: isDark,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: double.infinity,
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
  final r = (c.r * 255).toInt().toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).toInt().toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).toInt().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

const _kTypeColors = {
  'movie': '#6750A4',
  'person': '#F57C00',
  'genre': '#0097A7',
  'keyword': '#7B1FA2',
};

const _kTypeLabels = {
  'movie': '影视',
  'person': '人物',
  'genre': '类型',
  'keyword': '关键词',
};

const _kTypeSymbols = {
  'movie': 'roundRect',
  'person': 'circle',
  'genre': 'diamond',
  'keyword': 'triangle',
};

String _buildGraphHtml({
  required MovieGraphResponse graph,
  required String primaryHex,
  required String bgHex,
  required String textHex,
  required bool isDark,
}) {
  final centerNodeId = graph.nodes.first.id;

  final echartsNodes = graph.nodes.map((n) {
    final isCenter = n.id == centerNodeId;
    return {
      'name': n.label,
      'id': n.id,
      'symbolSize': isCenter ? 42 : 28,
      'itemStyle': {'color': _kTypeColors[n.type] ?? primaryHex},
      'symbol': _kTypeSymbols[n.type] ?? 'circle',
      'category': n.type,
      'label': {
        'show': true,
        'fontSize': isCenter ? 13 : 11,
        'color': textHex,
        'fontWeight': isCenter ? 'bold' : 'normal',
      },
      if (isCenter) 'fixed': true,
      if (isCenter) 'x': 0,
      if (isCenter) 'y': 0,
    };
  }).toList();

  final nameById = <String, String>{};
  for (final n in graph.nodes) {
    nameById[n.id] = n.label;
  }

  final echartsLinks = graph.links.map((l) {
    return {
      'source': nameById[l.source] ?? l.source,
      'target': nameById[l.target] ?? l.target,
      'label': {
        'show': true,
        'formatter': l.relation,
        'fontSize': 9,
        'color': isDark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.4)',
      },
      'lineStyle': {
        'width': 1.2,
        'curveness': 0.15,
      },
    };
  }).toList();

  final categories =
      _kTypeColors.entries.map((e) => {'name': e.key}).toList();

  final nodesJson = jsonEncode(echartsNodes);
  final linksJson = jsonEncode(echartsLinks);
  final categoriesJson = jsonEncode(categories);

  final legendData = _kTypeLabels.entries
      .map((e) => {'name': e.key, 'icon': 'circle'})
      .toList();
  final legendJson = jsonEncode(legendData);

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<script src="https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js"></script>
<style>
  *{margin:0;padding:0}
  html,body,#c{width:100%;height:100%;background:transparent}
</style>
</head>
<body>
<div id="c"></div>
<script>
var c=echarts.init(document.getElementById('c'),${isDark ? "'dark'" : "null"});
c.setOption({
  backgroundColor:'transparent',
  animationDurationUpdate:600,
  tooltip:{
    show:true,
    formatter:function(p){
      if(p.dataType==='edge') return p.data.label?p.data.label.formatter:'';
      return p.data.name||'';
    }
  },
  legend:[{
    data:$legendJson,
    orient:'horizontal',
    bottom:8,
    textStyle:{color:'$textHex',fontSize:11},
    formatter:function(name){
      var m=${jsonEncode(_kTypeLabels)};
      return m[name]||name;
    }
  }],
  series:[{
    type:'graph',
    layout:'force',
    roam:true,
    draggable:true,
    force:{
      repulsion:220,
      edgeLength:[60,140],
      gravity:0.06,
      layoutAnimation:true
    },
    data:$nodesJson,
    links:$linksJson,
    categories:$categoriesJson,
    emphasis:{
      focus:'adjacency',
      blurScope:'coordinateSystem',
      itemStyle:{borderWidth:2,borderColor:'#fff'}
    },
    lineStyle:{color:'source',opacity:0.35},
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
