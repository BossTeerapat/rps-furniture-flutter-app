import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';

/// Reusable search field used in AppBar across the app.
/// - If [controller] is not provided the widget will manage an internal controller.
class SearchField extends StatefulWidget {
  final TextEditingController? controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String? hint;

  const SearchField({
    super.key,
    this.controller,
    this.readOnly = false,
    this.onTap,
    this.onSubmitted,
  this.onChanged,
    this.autofocus = false,
    this.hint,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _internalController;
  bool _ownsController = false;
  void _onTextChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
      _ownsController = true;
    } else {
      _internalController = widget.controller!;
      _ownsController = false;
    }
  _internalController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _internalController.removeListener(_onTextChanged);
    if (_ownsController) {
      _internalController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _internalController,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        onTap: widget.onTap,
  onChanged: widget.onChanged,
  onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hint ?? 'ค้นหาสินค้า',
          hintStyle: TextStyle(color: AppTheme.textHintColor),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.textSecondaryColor,
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          // show clear button when there is text and the field is not readOnly
          suffixIcon: (!widget.readOnly && _internalController.text.isNotEmpty)
              ? IconButton(
                  icon: Icon(Icons.close, size: 20, color: AppTheme.textSecondaryColor),
                  onPressed: () {
                    _internalController.clear();
                    // notify change
                    if (widget.onChanged != null) widget.onChanged!('');
                    // also notify submit as empty? keep only onChanged
                  },
                )
              : null,
        ),
        style: TextStyle(color: AppTheme.textPrimaryColor),
      ),
    );
  }
}
