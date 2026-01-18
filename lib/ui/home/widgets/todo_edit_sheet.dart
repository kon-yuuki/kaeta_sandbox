import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/home_provider.dart';

class TodoEditSheet extends ConsumerStatefulWidget {
  final TodoItem item;
  const TodoEditSheet({super.key, required this.item});

  @override
  ConsumerState<TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends ConsumerState<TodoEditSheet> {
  late TextEditingController editNameController;
  late int selectedPriority;

  @override
  void initState() {
    super.initState();
    editNameController = TextEditingController(text: widget.item.name);
    selectedPriority = widget.item.priority;
  }

  @override
  void dispose() {
    editNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editNameController,
              decoration: const InputDecoration(labelText: '名前を編集'),
              autofocus: true,
            ),

            const SizedBox(height: 20),

            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('普通')),
                ButtonSegment(value: 1, label: Text('重要')),
              ],
              selected: {selectedPriority},
              onSelectionChanged: (newSelection) {
                setState(() {
                  selectedPriority = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(homeViewModelProvider)
                    .updateTodo(
                      widget.item,
                      editNameController.text,
                      selectedPriority,
                    );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
