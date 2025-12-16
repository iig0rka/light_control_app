// lib/data/device_model.dart
class Device {
  final String id;
  final String title;
  final String name;
  final String password;
  final bool isConnected;

  const Device({
    required this.id,
    required this.title,
    required this.name,
    required this.password,
    required this.isConnected,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'name': name,
    'password': password,
    'isConnected': isConnected,
  };

  factory Device.fromMap(Map map) {
    return Device(
      id: map['id'] as String,
      title: map['title'] as String,
      name: map['name'] as String? ?? '',
      password: map['password'] as String? ?? '',
      isConnected: map['isConnected'] as bool? ?? false,
    );
  }
}
