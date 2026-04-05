class Quote {
  final String id;
  final String text;
  final String author;

  Quote({required this.id, required this.text, required this.author});

  factory Quote.fromMap(Map<String, dynamic> map) => Quote(
    id: map['id']?.toString() ?? '',
    text: map['text'] ?? map['texto'] ?? '',
    author: map['author'] ?? map['autor'] ?? '',
  );
}
