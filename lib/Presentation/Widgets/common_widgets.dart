import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
    final tagBg = highlighted
        ? (brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent)
        : (brightness == Brightness.dark ? AppColors.darkTagBg : AppColors.lightTagBg);
    final tagTx = highlighted
        ? AppColors.darkAccentTx
        : (brightness == Brightness.dark ? AppColors.darkTagTx : AppColors.lightTagTx);
    final border = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
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
            Text(label, style: AppTextStyles.body(textColor, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600)),
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
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final accent = brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent;
    final textColor = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final hintColor = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final shadow = brightness == Brightness.dark ? AppColors.darkShadowAccent : AppColors.lightShadowAccent;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style: AppTextStyles.body(textColor, fontSize: AppTextStyles.sizeSm),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: AppTextStyles.body(hintColor, fontSize: AppTextStyles.sizeSm),
        filled: true,
        fillColor: surface,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    final deco = AppDecorations.card(brightness).copyWith(
      borderRadius: borderRadius != null
          ? borderRadius
          : BorderRadius.circular(16),
    );

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

