// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class MirageFile {
  String id, name;
  String url;
  int size;
  MirageType type;
  DateTime created, expiry;
  Map<dynamic, dynamic> metadata;

  MirageFile({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.type,
    required this.created,
    required this.expiry,
    required this.metadata,
  });

  factory MirageFile.fromJson(Map<String, dynamic> json) {
    MirageType getType(String mimeType) {
      switch (mimeType) {
        case "image":
          return MirageType.photo;
        case "video":
          return MirageType.video;
        default:
          return MirageType.error;
      }
    }

    try {
      return MirageFile(
        id: json['id'] ?? "",
        name: json['name'] ?? "",
        url: json['url'] ?? "",
        size: json['size'] ?? 0,
        type: getType(
            (json['metadata']['MIMEType'] ?? "application/*").split("/").first),
        created:
            DateFormat('y:M:d H:m:s').parse(json['metadata']['CreateDate']),
        expiry: json['expiry'] == null
            ? DateTime.now()
            : DateFormat('y-M-d H:m:s').parse(json['expiry']),
        metadata: json['metadata'] ?? {},
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      throw const FormatException('Failed to load MirageFile');
    }
  }
}

enum MirageType { photo, video, error }
