class Group {
  final String id;
  final String name;
  final String? photoUrl;
  final String inviteCode;

  Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.photoUrl,
  });

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      photoUrl: map['photo_url'] as String?,
      inviteCode: map['invite_code'] as String,
    );
  }
}
