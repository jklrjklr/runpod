class PodTemplate {
  final String id;
  final String name;
  final String imageName;

  const PodTemplate({required this.id, required this.name, required this.imageName});

  factory PodTemplate.fromJson(Map<String, dynamic> json) {
    return PodTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      imageName: json['imageName'] as String? ?? '',
    );
  }
}
