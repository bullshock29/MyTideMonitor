import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';

/// Asks the user for a new name for a favorite location, and saves it.
///
/// Saving a blank name, or tapping Reset, goes back to the station's own name.
Future<void> showRenameDialog(BuildContext context, Station station) async {
  final newName = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(station: station),
  );

  // null means Cancel. An empty string means "back to the station's name".
  if (newName != null) {
    await favoritesService.rename(station, newName);
  }
}

class _RenameDialog extends StatefulWidget {
  final Station station;

  const _RenameDialog({required this.station});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: favoritesService.displayName(widget.station),
    );
    // Start with the whole name selected, so typing replaces it.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    final isRenamed = favoritesService.customName(widget.station.id) != null;

    return AlertDialog(
      title: const Text('Rename location'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: FavoritesService.maxNameLength,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Name',
          helperText: 'Station: ${widget.station.name}',
          helperMaxLines: 2,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        if (isRenamed)
          TextButton(
            // An empty name puts the station's own name back.
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Reset'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
