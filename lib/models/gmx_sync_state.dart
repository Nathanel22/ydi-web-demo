class GmxSyncState {
  const GmxSyncState({
    required this.uidValidity,
    required this.lastProcessedUid,
  });

  final int uidValidity;
  final int lastProcessedUid;

  Map<String, Object> toJson() => {
    'uidValidity': uidValidity,
    'lastProcessedUid': lastProcessedUid,
  };

  factory GmxSyncState.fromJson(Map<String, dynamic> json) {
    final uidValidity = json['uidValidity'];
    final lastProcessedUid = json['lastProcessedUid'];
    if (uidValidity is! int ||
        uidValidity <= 0 ||
        lastProcessedUid is! int ||
        lastProcessedUid < 0) {
      throw const FormatException('Invalid GMX sync state.');
    }
    return GmxSyncState(
      uidValidity: uidValidity,
      lastProcessedUid: lastProcessedUid,
    );
  }
}
