import 'package:flutter/material.dart';
import 'locale_controller.dart';
import 'message_catalog.dart';

// Keeps const widget trees, while depending on the selected locale at render time.
// Only app-owned messages in MessageCatalog are translated. Unknown server content is kept.
class LText extends StatelessWidget {
  const LText(this.data,
      {super.key,
      this.translate = true,
      this.style,
      this.strutStyle,
      this.textAlign,
      this.textDirection,
      this.locale,
      this.softWrap,
      this.overflow,
      this.textScaler,
      this.maxLines,
      this.semanticsLabel,
      this.semanticsIdentifier,
      this.textWidthBasis,
      this.textHeightBehavior,
      this.selectionColor});
  final String data;
  final bool translate;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Text(
      translate ? MessageCatalog.translate(data, language) : data,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null
          ? null
          : MessageCatalog.translate(semanticsLabel!, language),
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

// InputDecoration is copied by Flutter using its getters, including localized validation errors.
class LDecoration extends InputDecoration {
  const LDecoration(
      {super.icon,
      super.iconColor,
      super.label,
      super.labelText,
      super.labelStyle,
      super.floatingLabelStyle,
      super.helper,
      super.helperText,
      super.helperStyle,
      super.helperMaxLines,
      super.hintText,
      super.hintStyle,
      super.hintTextDirection,
      super.hintMaxLines,
      super.error,
      super.errorText,
      super.errorStyle,
      super.errorMaxLines,
      super.floatingLabelBehavior,
      super.floatingLabelAlignment,
      super.isCollapsed,
      super.isDense,
      super.contentPadding,
      super.prefixIcon,
      super.prefixIconConstraints,
      super.prefix,
      super.prefixText,
      super.prefixStyle,
      super.prefixIconColor,
      super.suffixIcon,
      super.suffix,
      super.suffixText,
      super.suffixStyle,
      super.suffixIconColor,
      super.suffixIconConstraints,
      super.counter,
      super.counterText,
      super.counterStyle,
      super.filled,
      super.fillColor,
      super.focusColor,
      super.hoverColor,
      super.errorBorder,
      super.focusedBorder,
      super.focusedErrorBorder,
      super.disabledBorder,
      super.enabledBorder,
      super.border,
      super.enabled,
      super.semanticCounterText,
      super.alignLabelWithHint,
      super.constraints});
  @override
  String? get labelText =>
      super.labelText == null ? null : tr(super.labelText!);
  @override
  String? get helperText =>
      super.helperText == null ? null : tr(super.helperText!);
  @override
  String? get hintText => super.hintText == null ? null : tr(super.hintText!);
  @override
  String? get errorText =>
      super.errorText == null ? null : tr(super.errorText!);
  @override
  String? get prefixText =>
      super.prefixText == null ? null : tr(super.prefixText!);
  @override
  String? get suffixText =>
      super.suffixText == null ? null : tr(super.suffixText!);
  @override
  String? get counterText =>
      super.counterText == null ? null : tr(super.counterText!);
  @override
  String? get semanticCounterText =>
      super.semanticCounterText == null ? null : tr(super.semanticCounterText!);
}

class LNavigationDestination extends NavigationDestination {
  const LNavigationDestination(
      {super.key,
      required super.icon,
      super.selectedIcon,
      required super.label,
      super.tooltip,
      super.enabled});
  @override
  String get label => tr(super.label);
  @override
  String? get tooltip => super.tooltip == null ? null : tr(super.tooltip!);
}
