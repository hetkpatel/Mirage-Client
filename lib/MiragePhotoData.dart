// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class MiragePhotoData {
  String id, name;
  String url;
  int width, height;
  MirageType type;
  DateTime created, expiry;
  Map<dynamic, dynamic> metadata;

  MiragePhotoData({
    required this.id,
    required this.name,
    required this.url,
    required this.width,
    required this.height,
    required this.type,
    required this.created,
    required this.expiry,
    required this.metadata,
  });

  factory MiragePhotoData.fromJson(Map<String, dynamic> json) {
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
      return MiragePhotoData(
        id: json['id'] ?? "",
        name: json['name'] ?? "",
        url: json['url'] ?? "",
        width: json['width'] ?? 0,
        height: json['height'] ?? 0,
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

  double get aspectRatio => width / height;
}

enum MirageType { photo, video, error }
