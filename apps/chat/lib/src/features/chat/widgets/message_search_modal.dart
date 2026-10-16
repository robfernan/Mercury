import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models.dart';
import '../../../theme/mercury_theme.dart';
import 'message_tile.dart';

/// Modal dialog providing zero-knowledge client-side full-text search over SQLite FTS5.
class MessageSearchModal extends ConsumerStatefulWidget {
  const MessageSearchModal({super.key, required this.channelId, required this.channelName});

  final String channelId;
  final String channelName;

  @override
  ConsumerState<MessageSearchModal> createState() => _MessageSearchModalState();
}

class _MessageSearchModalState extends ConsumerState<MessageSearchModal> {
  final _searchController = TextEditingController();
  List<ChatMessage> _results = [];
  bool _isSearching = false;
  bool _scopeAllChannels = false;

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final repo = ref.read(localStorageRepositoryProvider);
    final results = await repo.search(
      trimmed,
      channelId: _scopeAllChannels ? null : widget.channelId,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MercuryColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MercuryColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 680,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.search_rounded, color: MercuryColors.accent, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Encrypted FTS5 Search',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MercuryColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search input field
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: MercuryColors.textPrimary),
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: _scopeAllChannels
                    ? 'Search all decrypted channels...'
                    : 'Search in #${widget.channelName}...',
                hintStyle: const TextStyle(color: MercuryColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: MercuryColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: MercuryColors.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MercuryColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MercuryColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MercuryColors.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Scope filter & Badge
            Row(
              children: [
                FilterChip(
                  label: Text('In #${widget.channelName}'),
                  selected: !_scopeAllChannels,
                  onSelected: (val) {
                    setState(() => _scopeAllChannels = !val);
                    _performSearch(_searchController.text);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('All Channels'),
                  selected: _scopeAllChannels,
                  onSelected: (val) {
                    setState(() => _scopeAllChannels = val);
                    _performSearch(_searchController.text);
                  },
                ),
                const Spacer(),
                const Text(
                  'Zero-knowledge · Local SQLite',
                  style: TextStyle(color: MercuryColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Results List
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _searchController.text.trim().isEmpty
                                    ? Icons.manage_search_rounded
                                    : Icons.search_off_rounded,
                                size: 48,
                                color: MercuryColors.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.trim().isEmpty
                                    ? 'Type keywords to search local encrypted history'
                                    : 'No matching messages found in FTS5 index',
                                style: const TextStyle(color: MercuryColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final m = _results[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: MercuryColors.surfaceRaised,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: MercuryColors.border),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Row(
                                  children: [
                                    Text(
                                      'Message in #${m.channelId}',
                                      style: const TextStyle(
                                        color: MercuryColors.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      formatMessageTime(m.sentAt),
                                      style: const TextStyle(
                                        color: MercuryColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    m.body,
                                    style: const TextStyle(
                                      color: MercuryColors.textPrimary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                onTap: () => Navigator.pop(context),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
