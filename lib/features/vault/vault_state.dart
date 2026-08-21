import 'package:days_together/models/vault_item_model.dart';

/// State for `VaultController` (Phase 6a of the architecture migration) --
/// a direct Riverpod port of `VaultProvider`'s `_items`/`_isUnlocked`/
/// `_hasPin`/`_wrongAttempts`/`_isLoading` fields.
///
/// [photos]/[letters] are, faithfully, **not** gated by [isUnlocked] --
/// neither was the original `VaultProvider.photos`/`.letters`. The only
/// call site (`vault_screen.dart`) never reaches them without its own
/// top-level `if (!vault.isUnlocked)` early return first, so this has never
/// been a live leak, but it's a real gap in the model's own self-gating
/// worth knowing about rather than silently carrying forward unremarked --
/// see `vault_controller.dart`'s doc comment.
class VaultState {
  final List<VaultItem> items;
  final bool isUnlocked;
  final bool hasPin;
  final int wrongAttempts;
  final bool isLoading;

  const VaultState({
    this.items = const [],
    this.isUnlocked = false,
    this.hasPin = false,
    this.wrongAttempts = 0,
    this.isLoading = true,
  });

  VaultState copyWith({
    List<VaultItem>? items,
    bool? isUnlocked,
    bool? hasPin,
    int? wrongAttempts,
    bool? isLoading,
  }) {
    return VaultState(
      items: items ?? this.items,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      hasPin: hasPin ?? this.hasPin,
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<VaultItem> get visibleItems => isUnlocked ? List.unmodifiable(items) : const [];
  List<VaultItem> get photos => items.where((i) => i.type == VaultItemType.photo).toList();
  List<VaultItem> get letters => items.where((i) => i.type == VaultItemType.letter).toList();
  bool get isDecoyMode => wrongAttempts >= 3;
}
