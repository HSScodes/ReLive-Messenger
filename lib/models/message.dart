class Message {
  const Message({
    required this.from,
    required this.to,
    required this.body,
    required this.timestamp,
    this.isNudge = false,
    this.isTyping = false,
    this.isFileTransfer = false,
    this.fileTransferId,
    this.fileName,
    this.fileSize,
    this.filePath,
    this.fileTransferState = FileTransferState.none,
  });

  final String from;
  final String to;
  final String body;
  final DateTime timestamp;
  final bool isNudge;
  final bool isTyping;
  final bool isFileTransfer;
  final String? fileTransferId;
  final String? fileName;
  final int? fileSize;
  final String? filePath;
  final FileTransferState fileTransferState;

  Message copyWith({
    String? from,
    String? to,
    String? body,
    DateTime? timestamp,
    bool? isNudge,
    bool? isTyping,
    bool? isFileTransfer,
    String? fileTransferId,
    String? fileName,
    int? fileSize,
    String? filePath,
    FileTransferState? fileTransferState,
  }) {
    return Message(
      from: from ?? this.from,
      to: to ?? this.to,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isNudge: isNudge ?? this.isNudge,
      isTyping: isTyping ?? this.isTyping,
      isFileTransfer: isFileTransfer ?? this.isFileTransfer,
      fileTransferId: fileTransferId ?? this.fileTransferId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      fileTransferState: fileTransferState ?? this.fileTransferState,
    );
  }
}

enum FileTransferState {
  none,
  offered,
  accepted,
  transferring,
  completed,
  declined,
  failed,
}
