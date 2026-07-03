import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A labeled -/value/+ row whose value is also directly editable via the
/// numeric keypad. Keyed by [id] so tests can find and drive it:
/// `${id}_decrement`, `${id}` (the value field), `${id}_increment`.
class NumberStepper extends StatefulWidget {
  final String label;
  final String id;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  const NumberStepper({
    super.key,
    required this.label,
    required this.id,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only overwrite the field when the value changed from outside (e.g. the
    // +/- buttons or another screen); don't clobber in-progress typing.
    if (int.tryParse(_controller.text) != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final parsed = int.tryParse(text);
    final resolved = parsed == null ? widget.value : (parsed < widget.min ? widget.min : parsed);
    if (resolved != widget.value) widget.onChanged(resolved);
    _controller.text = '$resolved';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(widget.label)),
          IconButton(
            key: Key('${widget.id}_decrement'),
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.value > widget.min ? () => widget.onChanged(widget.value - 1) : null,
          ),
          SizedBox(
            width: 56,
            child: TextField(
              key: Key(widget.id),
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              onSubmitted: _commit,
              onTapOutside: (_) => _commit(_controller.text),
            ),
          ),
          IconButton(
            key: Key('${widget.id}_increment'),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => widget.onChanged(widget.value + 1),
          ),
        ],
      ),
    );
  }
}
