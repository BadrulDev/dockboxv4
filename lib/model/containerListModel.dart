class DockerContainer {
  final String id;
  final String name;
  final String image;
  final String status;
  final String? webUrl;

  DockerContainer({
    required this.id,
    required this.name,
    required this.image,
    required this.status,
    this.webUrl,
  });

  bool get isRunning => status.toLowerCase().contains('up');
}