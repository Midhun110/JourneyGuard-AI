import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class SearchField extends StatefulWidget {
  final String hint;
  final IconData leadingIcon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final String? initialValue;

  const SearchField({
    super.key,
    required this.hint,
    this.leadingIcon = Icons.search_rounded,
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.initialValue,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused ? AppColors.accentIndigo : AppColors.border,
          width: _isFocused ? 1.5 : 1,
        ),
        color: AppColors.surfaceElevated,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.accentIndigo.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Focus(
        onFocusChange: (v) => setState(() => _isFocused = v),
        child: TextField(
          controller: _controller,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                AppTypography.bodyLarge.copyWith(color: AppColors.textMuted),
            prefixIcon: Icon(
              widget.leadingIcon,
              color: _isFocused ? AppColors.accentIndigo : AppColors.textMuted,
              size: 20,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}
