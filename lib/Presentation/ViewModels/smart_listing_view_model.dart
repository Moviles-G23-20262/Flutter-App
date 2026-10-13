import 'package:flutter/foundation.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/use_cases/price_estimator_use_case.dart';

/// MVVM: the ViewModel of the Smart Listing screen.
///
/// Holds everything the screen shows (the chosen category and condition, the price estimate,
/// the loading and error state) and the only code that talks to [PriceEstimatorUseCase].
/// The View just renders these properties and forwards taps to the methods below.
class SmartListingViewModel extends ChangeNotifier {
  final PriceEstimatorUseCase estimator;

  SmartListingViewModel({required this.estimator});

  String? _selectedCategory;
  String? _selectedCondition;
  PriceEstimate? _estimate;
  bool _isLoading = false;
  String? _errorMessage;

  int _request = 0; // lets an answer that arrives late be ignored
  bool _disposed = false;

  /// Enum name of the chosen category (e.g. `BOOKS`), or null before choosing.
  String? get selectedCategory => _selectedCategory;

  /// Enum name of the chosen condition (e.g. `GOOD`), or null before choosing.
  String? get selectedCondition => _selectedCondition;

  /// Median of comparable sales, or the heuristic price. Null until estimated.
  double? get suggestedPrice => _estimate?.suggestedPrice;
  double? get p25 => _estimate?.p25;
  double? get p75 => _estimate?.p75;

  /// Completed sales behind the estimate; 0 for a heuristic one.
  int get sampleSize => _estimate?.sampleSize ?? 0;

  /// True when the estimate comes from the local formula, not from real sales.
  bool get isFallback => _estimate?.isHeuristic ?? false;

  /// Why the estimate is a fallback (no connection vs. too few sales); null if not.
  PriceEstimateSource? get source => _estimate?.source;

  bool get hasEstimate => _estimate != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Both choices are made, so a price can be estimated.
  bool get canEstimate => _selectedCategory != null && _selectedCondition != null && !_isLoading;

  void setCategory(String category) {
    if (!MaterialCategoryEnum.values.any((c) => c.name == category)) return;
    if (category == _selectedCategory) return;
    _selectedCategory = category;
    _discardEstimate();
  }

  void setCondition(String condition) {
    if (!MaterialConditionEnum.values.any((c) => c.name == condition)) return;
    if (condition == _selectedCondition) return;
    _selectedCondition = condition;
    _discardEstimate();
  }

  /// Estimates a fair price for the chosen category and condition. Never throws: whatever
  /// goes wrong ends up in [errorMessage] or as a heuristic estimate ([isFallback]).
  Future<void> estimatePrice() async {
    if (!canEstimate) return;
    final category = MaterialCategoryEnum.values.byName(_selectedCategory!);
    final condition = MaterialConditionEnum.values.byName(_selectedCondition!);
    final request = ++_request;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    PriceEstimate? estimate;
    String? error;
    try {
      estimate = await estimator.execute(category: category, condition: condition);
    } catch (_) {
      error = 'Could not estimate a price. Please try again.';
    }

    if (_disposed || request != _request) return;
    _estimate = estimate;
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  /// Back to the initial state: nothing chosen, nothing estimated.
  void reset() {
    _request++; // drop any answer still on its way
    _selectedCategory = null;
    _selectedCondition = null;
    _estimate = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// A new choice makes the current estimate (and any pending one) stale.
  void _discardEstimate() {
    _request++;
    _estimate = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
