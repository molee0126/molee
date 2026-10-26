import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../data/local_repository.dart';

Future<LocalRepository> openLocalRepository() async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}/faceai_private');
  await directory.create(recursive: true);
  if (Platform.isIOS) {
    // Fail closed if backup exclusion cannot be applied before any photos exist.
    await const MethodChannel(
      'faceai/privacy',
    ).invokeMethod<void>('excludeFromBackup', {'path': directory.path});
  }
  return LocalRepository(directory);
}
