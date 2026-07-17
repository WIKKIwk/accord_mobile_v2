class SavedBackupFile {
  const SavedBackupFile({required this.filename, required this.path});

  final String filename;
  final String path;
}

typedef BackupProgressCallback = void Function(int received, int total);
