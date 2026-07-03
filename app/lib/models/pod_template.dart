class PodTemplate {
  final String id;
  final String name;
  final String imageName;
  final bool isPublic;
  final bool isServerless;

  const PodTemplate({
    required this.id,
    required this.name,
    required this.imageName,
    this.isPublic = false,
    this.isServerless = false,
  });

  factory PodTemplate.fromJson(Map<String, dynamic> json) {
    return PodTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      imageName: json['imageName'] as String? ?? '',
      isPublic: json['isPublic'] as bool? ?? false,
      isServerless: json['isServerless'] as bool? ?? false,
    );
  }
}
