import 'dart:async';

/// CRDT Operation types for deterministic conflict-free merging
enum CrdtOpType {
  insertMessage,
  editMessage,
  deleteMessage,
  updateChannelTopic,
}

/// A Conflict-free Replicated Data Type (CRDT) operation timestamped with a hybrid logical clock (HLC).
class CrdtOperation {
  const CrdtOperation({
    required this.id,
    required this.conversationId,
    required this.peerId,
    required this.opType,
    required this.logicalTimestamp,
    required this.payload,
  });

  final String id;
  final String conversationId;
  final String peerId;
  final CrdtOpType opType;
  final int logicalTimestamp; // Hybrid Logical Clock (HLC)
  final String payload; // Serialized mutation
}

/// Local CRDT Synchronization Engine operating over local Drift/SQLite.
/// Handles deterministic offline-to-online merges without a central database coordinator.
class LocalCrdtSyncEngine {
  LocalCrdtSyncEngine({
    required this.localPeerId,
  });

  final String localPeerId;
  int _logicalCounter = 0;

  final List<CrdtOperation> _opLog = [];
  final _opLogController = StreamController<List<CrdtOperation>>.broadcast();
  Stream<List<CrdtOperation>> get opLogStream => _opLogController.stream;

  /// Creates a local timestamped mutation
  CrdtOperation createOperation({
    required String conversationId,
    required CrdtOpType opType,
    required String payload,
  }) {
    _logicalCounter++;
    final op = CrdtOperation(
      id: 'op_${DateTime.now().millisecondsSinceEpoch}_$_logicalCounter',
      conversationId: conversationId,
      peerId: localPeerId,
      opType: opType,
      logicalTimestamp: _logicalCounter,
      payload: payload,
    );
    _opLog.add(op);
    _opLogController.add(List.unmodifiable(_opLog));
    return op;
  }

  /// Deterministically merges a batch of operations received from another peer or relay
  List<CrdtOperation> mergeRemoteOperations(List<CrdtOperation> incoming) {
    for (final op in incoming) {
      if (!_opLog.any((existing) => existing.id == op.id)) {
        _opLog.add(op);
        if (op.logicalTimestamp > _logicalCounter) {
          _logicalCounter = op.logicalTimestamp + 1;
        }
      }
    }
    // Sort deterministically by HLC timestamp and peerId tie-breaker
    _opLog.sort((a, b) {
      final cmp = a.logicalTimestamp.compareTo(b.logicalTimestamp);
      return cmp != 0 ? cmp : a.peerId.compareTo(b.peerId);
    });

    _opLogController.add(List.unmodifiable(_opLog));
    return List.unmodifiable(_opLog);
  }

  void dispose() {
    _opLogController.close();
  }
}
