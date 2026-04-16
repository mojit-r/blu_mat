import 'package:flutter/material.dart';

class GenericTextField extends StatefulWidget {
  final String label;
  final String? hintText;
  final String initialValue;
  final Function(String)? onChanged;
  final IconData? icon;

  const GenericTextField({
    super.key,
    required this.label,
    this.hintText,
    this.initialValue = '',
    this.onChanged,
    this.icon,
  });

  @override
  State<GenericTextField> createState() => _GenericTextFieldState();
}

class _GenericTextFieldState extends State<GenericTextField> {
  // The widget handles its own controller internally
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    // Always dispose of the controller to free resources
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
