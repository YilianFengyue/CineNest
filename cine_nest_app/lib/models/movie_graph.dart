class GraphNode {
  final String id;
  final String label;
  final String type; // movie | person | genre | keyword
  final int? movieId;

  GraphNode({
    required this.id,
    required this.label,
    required this.type,
    this.movieId,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) => GraphNode(
        id: json['id'] as String,
        label: json['label'] as String,
        type: json['type'] as String,
        movieId: json['movie_id'] as int?,
      );
}

class GraphLink {
  final String source;
  final String target;
  final String relation;

  GraphLink({
    required this.source,
    required this.target,
    required this.relation,
  });

  factory GraphLink.fromJson(Map<String, dynamic> json) => GraphLink(
        source: json['source'] as String,
        target: json['target'] as String,
        relation: json['relation'] as String,
      );
}

class MovieGraphResponse {
  final List<GraphNode> nodes;
  final List<GraphLink> links;

  MovieGraphResponse({
    required this.nodes,
    required this.links,
  });

  factory MovieGraphResponse.fromJson(Map<String, dynamic> json) => MovieGraphResponse(
        nodes: (json['nodes'] as List).map((e) => GraphNode.fromJson(e)).toList(),
        links: (json['links'] as List).map((e) => GraphLink.fromJson(e)).toList(),
      );
}
