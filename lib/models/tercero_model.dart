class TerceroModel {
  final String id;
  final String name;
  final String type;

  TerceroModel({
    required this.id,
    required this.name,
    required this.type,
  });

  factory TerceroModel.fromJson(Map<String, dynamic> json) {
    return TerceroModel(
      id: json['id'].toString(),
      name: json['nombre'] as String,
      type: json['tipo'] as String,
    );
  }
}