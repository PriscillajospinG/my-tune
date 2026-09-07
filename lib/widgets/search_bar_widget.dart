import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';

/// Reusable search bar with a clear button
class SearchBarWidget extends ConsumerStatefulWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const SearchBarWidget({
    super.key,
    this.hint = 'Search songs, artists, albums…',
    this.onChanged,
    this.onClear,
  });

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      setState(() => _hasText = _ctrl.text.isNotEmpty);
      widget.onChanged?.call(_ctrl.text);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontFamily: 'Outfit',
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    const TextStyle(color: AppTheme.textMuted, fontFamily: 'Outfit'),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_hasText)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                widget.onClear?.call();
              },
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.close, color: AppTheme.textMuted, size: 18),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
