enum DownloadStatus {
  idle,
  preparing,
  downloading,
  processing, // FFmpeg audio extraction or stream merging
  completed,
  cancelled,
  failed,
}

class DownloadProgress {
  const DownloadProgress({
    required this.status,
    this.progress = 0.0,
    this.percentage = '0%',
    this.speed,
    this.eta,
    this.totalSize,
    this.title,
    this.outputFilePath,
    this.errorMessage,
    this.rawLog = '',
  });

  final DownloadStatus status;
  final double progress; // Range: 0.0 to 1.0
  final String percentage; // e.g. "45.2%"
  final String? speed; // e.g. "2.4MiB/s"
  final String? eta; // e.g. "00:14"
  final String? totalSize; // e.g. "24.5MiB"
  final String? title; // Media title
  final String? outputFilePath; // Full destination file path
  final String? errorMessage;
  final String rawLog;

  bool get isActive =>
      status == DownloadStatus.preparing ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.processing;

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isCancelled => status == DownloadStatus.cancelled;
  bool get isFailed => status == DownloadStatus.failed;

  DownloadProgress copyWith({
    DownloadStatus? status,
    double? progress,
    String? percentage,
    String? speed,
    String? eta,
    String? totalSize,
    String? title,
    String? outputFilePath,
    String? errorMessage,
    String? rawLog,
  }) {
    return DownloadProgress(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      percentage: percentage ?? this.percentage,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      totalSize: totalSize ?? this.totalSize,
      title: title ?? this.title,
      outputFilePath: outputFilePath ?? this.outputFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
      rawLog: rawLog ?? this.rawLog,
    );
  }

  static DownloadProgress idle() =>
      const DownloadProgress(status: DownloadStatus.idle);

  static DownloadProgress preparing({String? title}) => DownloadProgress(
        status: DownloadStatus.preparing,
        title: title,
        rawLog: 'Preparing download stream...',
      );

  static DownloadProgress completed({
    required String outputFilePath,
    String? title,
  }) =>
      DownloadProgress(
        status: DownloadStatus.completed,
        progress: 1.0,
        percentage: '100%',
        outputFilePath: outputFilePath,
        title: title,
      );

  static DownloadProgress cancelled({String? title}) => DownloadProgress(
        status: DownloadStatus.cancelled,
        title: title,
        errorMessage: 'Download was cancelled by user',
      );

  static DownloadProgress failed(String errorMessage, {String? title, String? rawLog}) =>
      DownloadProgress(
        status: DownloadStatus.failed,
        errorMessage: errorMessage,
        title: title,
        rawLog: rawLog ?? '',
      );
}
