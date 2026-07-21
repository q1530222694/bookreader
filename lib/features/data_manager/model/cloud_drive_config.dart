/// 个人云盘/NAS 配置模型。
///
/// 支持的类型：
/// - [typeWebdav]：WebDAV 协议（覆盖多数 NAS 与私有云盘），同步走 HTTP PUT；
/// - [typeOther]：仅保存配置、暂未接入同步通道（如百度网盘/Dropbox 等需专属 API）。
class CloudDriveConfig {
  final String id;
  final String name;
  final String type; // typeWebdav / typeOther
  final String url; // 服务器地址（WebDAV 根，如 https://nas.example.com/remote.php/webdav）
  final String username;
  final String password;
  final String remotePath; // 远程目录（可为空，默认根）

  const CloudDriveConfig({
    required this.id,
    required this.name,
    required this.type,
    this.url = '',
    this.username = '',
    this.password = '',
    this.remotePath = '',
  });

  /// WebDAV 类型：当前唯一实现真实上传同步的通道。
  static const String typeWebdav = 'webdav';

  /// 其他类型：仅保存配置，同步通道待接入。
  static const String typeOther = 'other';

  /// 是否为「支持同步」的类型（当前仅 WebDAV）。
  bool get supportsSync => type == typeWebdav;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'url': url,
        'username': username,
        'password': password,
        'remotePath': remotePath,
      };

  factory CloudDriveConfig.fromJson(Map<String, dynamic> json) => CloudDriveConfig(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? typeOther,
        url: json['url'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        remotePath: json['remotePath'] as String? ?? '',
      );

  CloudDriveConfig copyWith({
    String? name,
    String? type,
    String? url,
    String? username,
    String? password,
    String? remotePath,
  }) =>
      CloudDriveConfig(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        url: url ?? this.url,
        username: username ?? this.username,
        password: password ?? this.password,
        remotePath: remotePath ?? this.remotePath,
      );
}
