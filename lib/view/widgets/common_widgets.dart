import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextEditingValue, TextInputFormatter;
import '../../model/rules/input_rules.dart';
import '../../app/theme/app_theme.dart';

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

/// Round avatar displaying user initials with accent background.
class UserAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool outlined;

  const UserAvatar({
    super.key,
    required this.initials,
    this.size = 42,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent;
    final accentHi = brightness == Brightness.dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    final elevated = brightness == Brightness.dark ? AppColors.darkElevated : AppColors.lightElevated;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;

    final bg = outlined ? elevated : accent;
    final fg = outlined ? accentHi : AppColors.darkAccentTx;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: outlined ? borderSubtle : (brightness == Brightness.dark ? AppColors.darkAccentLo : AppColors.lightAccentLo),
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.heading(fg, fontSize: size * 0.38),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Condition/course badge chip.
class AppBadge extends StatelessWidget {
  final String label;
  final bool highlighted;

  const AppBadge(this.label, {super.key, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tagTx = highlighted
        ? AppColors.darkAccentTx
        : (brightness == Brightness.dark ? AppColors.darkTagTx : AppColors.lightTagTx);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: AppDecorations.badge(brightness, highlighted: highlighted),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.label(tagTx, fontSize: AppTextStyles.size2xs),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Scrollable pill/chip filter row.
class PillChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const PillChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final deco = AppDecorations.pill(brightness, active: active);
    final textColor = active
        ? AppColors.darkAccentTx
        : (brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: deco,
        child: Text(label, style: AppTextStyles.body(textColor, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Icon button in a rounded box (used in headers).
class AppIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final bool active;

  const AppIconButton({super.key, required this.icon, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = active
        ? (brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent)
        : (brightness == Brightness.dark ? AppColors.darkElevated : AppColors.lightElevated);
    final border = active
        ? (brightness == Brightness.dark ? AppColors.darkAccentLo : AppColors.lightAccentLo)
        : (brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Center(child: icon),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Primary accent button.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool isLoading;
  final bool fullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent;
    final accentLo = brightness == Brightness.dark ? AppColors.darkAccentLo : AppColors.lightAccentLo;
    final shadow = brightness == Brightness.dark ? AppColors.darkShadowAccent : AppColors.lightShadowAccent;

    final child = isLoading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[leadingIcon!, const SizedBox(width: 6)],
              Text(label, style: AppTextStyles.body(AppColors.darkAccentTx, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600)),
              if (trailingIcon != null) ...[const SizedBox(width: 6), trailingIcon!],
            ],
          );

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentLo),
            boxShadow: [BoxShadow(color: shadow, blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Secondary outlined button.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;
  final bool fullWidth;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leadingIcon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final elevated = brightness == Brightness.dark ? AppColors.darkElevated : AppColors.lightElevated;
    final border = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final textColor = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[leadingIcon!, const SizedBox(width: 6)],
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(textColor, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Rounded text input field.
class AppTextField extends StatelessWidget {
  final String placeholder;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final String? errorText;
  final TextInputAction textInputAction;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  /// Space between the text and the border. More at the bottom leaves room for something drawn
  /// over the field, like a character counter.
  final EdgeInsetsGeometry contentPadding;

  const AppTextField({
    super.key,
    required this.placeholder,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onSubmitted,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final accent = brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent;
    final textColor = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final hintColor = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      onTap: onTap,
      readOnly: readOnly,
      maxLines: maxLines,
      textInputAction: textInputAction,
      enabled: enabled,
      textCapitalization: textCapitalization,
      style: AppTextStyles.body(textColor, fontSize: AppTextStyles.sizeSm),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: AppTextStyles.body(hintColor, fontSize: AppTextStyles.sizeSm),
        filled: true,
        fillColor: surface,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        errorText: errorText,
        contentPadding: contentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.darkError, width: 1.5),
        ),
      ),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Star rating row widget.
class StarRating extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double iconSize;

  const StarRating({
    super.key,
    required this.rating,
    this.reviewCount = 0,
    this.iconSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accentHi = brightness == Brightness.dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    final muted = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: accentHi, size: iconSize),
        const SizedBox(width: 3),
        Text(
          reviewCount > 0 ? '$rating ($reviewCount)' : '$rating',
          style: AppTextStyles.mono(muted, fontSize: AppTextStyles.sizeXs),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Simple card container.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final baseDeco = AppDecorations.card(brightness);
    final deco = borderRadius == null ? baseDeco : baseDeco.copyWith(borderRadius: borderRadius);

    final container = Container(
      padding: padding,
      decoration: deco,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Section heading with optional icon prefix.
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? icon;

  const SectionTitle(this.title, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textColor = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Row(
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 6)],
        Text(title, style: AppTextStyles.heading(textColor, fontSize: AppTextStyles.sizeMd)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// App logo icon in a coloured square.
class CampusSwapLogo extends StatelessWidget {
  final double size;
  final bool small;

  const CampusSwapLogo({super.key, this.size = 72, this.small = false});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent;
    final accentLo = brightness == Brightness.dark ? AppColors.darkAccentLo : AppColors.lightAccentLo;
    final shadow = brightness == Brightness.dark ? AppColors.darkShadowAccent : AppColors.lightShadowAccent;
    final iconSize = size * 0.5;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(small ? 10 : 20),
        border: Border.all(color: accentLo),
        boxShadow: [BoxShadow(color: shadow, blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: Icon(Icons.swap_horiz_rounded, color: Colors.white, size: iconSize),
      ),
    );
  }
}


/// "12/50", drawn grey, amber from 85 % of the limit and red once it is full, so the user is
/// warned before trying to send. Hidden below [showFrom] (a share of [max], e.g. 0.8) when the
/// counter should only appear near the limit.
class CounterLabel extends StatelessWidget {
  final int length;
  final int max;
  final double showFrom;

  const CounterLabel({super.key, required this.length, required this.max, this.showFrom = 0});

  @override
  Widget build(BuildContext context) {
    if (length < max * showFrom) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (InputRules.counterLevel(length, max)) {
      CounterLevel.normal => dark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      CounterLevel.warning => dark ? AppColors.darkWarning : AppColors.lightWarning,
      CounterLevel.full => dark ? AppColors.darkError : AppColors.lightError,
    };
    return Text(
      '$length/$max',
      semanticsLabel: '$length of $max characters',
      style: AppTextStyles.mono(
        color,
        fontSize: AppTextStyles.sizeXs,
        fontWeight: length >= max * InputRules.counterWarningRatio ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}

/// A [CounterLabel] that follows [controller] by itself.
class CharacterCounter extends StatelessWidget {
  final TextEditingController controller;
  final int max;
  final double showFrom;

  const CharacterCounter({super.key, required this.controller, required this.max, this.showFrom = 0});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) =>
          CounterLabel(length: value.text.characters.length, max: max, showFrom: showFrom),
    );
  }
}

/// Removes emojis (typed or pasted) from a field and remembers whether the last edit had any,
/// so [FieldFeedback] can say why they vanished. A plain edit clears the notice.
class EmojiBlocker extends TextInputFormatter {
  final ValueNotifier<bool> found = ValueNotifier<bool>(false);

  static final _deny = FilteringTextInputFormatter.deny(InputRules.emoji);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final hasEmoji = InputRules.containsEmoji(newValue.text);
    found.value = hasEmoji;
    return hasEmoji ? _deny.formatEditUpdate(oldValue, newValue) : newValue;
  }

  void dispose() => found.dispose();
}

/// What sits under a text field while it is being typed in: the warning for an emoji that was
/// removed, a live hint ([validate] says what is wrong with the text so far, shown once the
/// field has been edited) and the `n/max` counter. Nothing waits for the Send button.
class FieldFeedback extends StatefulWidget {
  final TextEditingController controller;

  /// The limit of the field, or null for no counter.
  final int? max;

  /// A counter that only shows from this share of [max] (0.8 = 80 %).
  final double counterShowFrom;

  /// The problem with the text, or null when it is fine. Not asked while the field is untouched.
  final String? Function(String text)? validate;

  final EmojiBlocker? emojiBlocker;
  final String emojiMessage;

  /// Hide the hint, e.g. because the field already shows an error of its own.
  final bool suppressHint;

  final Key? hintKey;
  final Key? emojiNoticeKey;
  final Key? counterKey;

  const FieldFeedback({
    super.key,
    required this.controller,
    this.max,
    this.counterShowFrom = 0,
    this.validate,
    this.emojiBlocker,
    this.emojiMessage = "Emojis aren't allowed here, so we removed them.",
    this.suppressHint = false,
    this.hintKey,
    this.emojiNoticeKey,
    this.counterKey,
  });

  @override
  State<FieldFeedback> createState() => _FieldFeedbackState();
}

class _FieldFeedbackState extends State<FieldFeedback> {
  bool _touched = false;
  late String _lastText = widget.controller.text;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(FieldFeedback old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    // Focusing or moving the cursor also notifies; only a change in the text counts as typing.
    final text = widget.controller.text;
    if (text != _lastText) {
      _lastText = text;
      _touched = true;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final warning = dark ? AppColors.darkWarning : AppColors.lightWarning;
    final error = dark ? AppColors.darkError : AppColors.lightError;
    final hint = (_touched && !widget.suppressHint) ? widget.validate?.call(widget.controller.text) : null;
    final blocker = widget.emojiBlocker;

    final messages = <Widget>[
      if (blocker != null)
        ValueListenableBuilder<bool>(
          valueListenable: blocker.found,
          builder: (context, found, _) => found
              ? Text(widget.emojiMessage,
                  key: widget.emojiNoticeKey,
                  style: AppTextStyles.body(error, fontSize: AppTextStyles.sizeXs))
              : const SizedBox.shrink(),
        ),
      if (hint != null)
        Text(hint, key: widget.hintKey, style: AppTextStyles.body(warning, fontSize: AppTextStyles.sizeXs)),
    ];
    final max = widget.max;
    if (messages.isEmpty && max == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: messages)),
          if (max != null) ...[
            const SizedBox(width: 8),
            CharacterCounter(
              key: widget.counterKey,
              controller: widget.controller,
              max: max,
              showFrom: widget.counterShowFrom,
            ),
          ],
        ],
      ),
    );
  }
}
