import 'package:flutter/material.dart';

class CustomTextfield extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType keyboard;
  final Function? validator;

  const CustomTextfield({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboard = TextInputType.text,
    this.validator,
  });

  @override
  State<CustomTextfield> createState() => _CustomTextfieldState();
}

class _CustomTextfieldState extends State<CustomTextfield> {
  late bool obscured;
  String? errorText;
  @override
  void initState() {
    obscured = widget.obscureText ? true : false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          25, errorText != null ? 0 : 10, 25, errorText != null ? 2 : 5),
      // padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextFormField(
        controller: widget.controller,
        obscureText: obscured,
        validator: (value) {
          if (widget.validator != null) {
            setState(() {
              errorText = widget.validator!(value);
            });
            return errorText;
          }
          return null;
        },
        onTapOutside: (event) {
          FocusScope.of(context).unfocus();
        },
        keyboardType: widget.keyboard,
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.white),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red.shade200),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          suffixIcon: widget.obscureText
              ? IconButton(
                  tooltip: obscured ? 'Show Password' : 'Hide Password',
                  highlightColor: Colors.transparent,
                  onPressed: () {
                    setState(
                      () => obscured = !obscured,
                    );
                  },
                  icon: Icon(
                    obscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                  ),
                )
              : null,
          fillColor: Colors.grey.shade200,
          filled: true,
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
