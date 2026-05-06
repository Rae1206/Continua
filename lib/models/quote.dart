class Quote {
  final String id;
  final String text;
  final String author;
  final List<String> tags;

  Quote({
    required this.id,
    required this.text,
    required this.author,
    this.tags = const [],
  });

  factory Quote.fromMap(Map<String, dynamic> map) => Quote(
    id: map['id']?.toString() ?? map['_id']?.toString() ?? '',
    text: map['text'] ?? map['texto'] ?? '',
    author: map['author'] ?? map['autor'] ?? '',
    tags: List<String>.from(map['tags'] ?? []),
  );

  Quote copyWith({
    String? id,
    String? text,
    String? author,
    List<String>? tags,
  }) =>
      Quote(
        id: id ?? this.id,
        text: text ?? this.text,
        author: author ?? this.author,
        tags: tags ?? this.tags,
      );
}
