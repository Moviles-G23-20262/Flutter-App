import '../Entities/material_entity.dart';

/// Estimated price band for a listing.
class PriceEstimate {
  /// 25th percentile of historical prices.
  final double p25;

  /// 75th percentile of historical prices.
  final double p75;

  /// Recommended asking price (between [p25] and [p75]).
  final double suggestedPrice;

  const PriceEstimate({
    required this.p25,
    required this.p75,
    required this.suggestedPrice,
  });
}

/// Simulated fair-price estimator based on category and condition.
///
/// Uses fixed base prices and condition multipliers; it does not query real
/// sales history. Replace the internals with a repository call when a backend
/// endpoint exists, keeping the same [execute] signature.
class PriceEstimatorUseCase {
  const PriceEstimatorUseCase();

  static const Map<MaterialCategoryEnum, double> _basePrice = {
    MaterialCategoryEnum.BOOKS: 40,
    MaterialCategoryEnum.CALCULATORS: 90,
    MaterialCategoryEnum.LAB_EQUIPMENT: 60,
    MaterialCategoryEnum.FURNITURE: 75,
    MaterialCategoryEnum.OTHER: 30,
  };

  static const Map<MaterialConditionEnum, double> _conditionFactor = {
    MaterialConditionEnum.NEW: 1.0,
    MaterialConditionEnum.LIKE_NEW: 0.85,
    MaterialConditionEnum.GOOD: 0.65,
    MaterialConditionEnum.FAIR: 0.45,
  };

// We built a Smart Price Estimator to guide them. 
// This method takes the item's category and condition to calculate a baseline,
// returning a suggested price along with a p25 to p75 fair-market range
// ->>>>>>> line 61
  PriceEstimate execute({
    required MaterialCategoryEnum category,
    required MaterialConditionEnum condition,
  }) {
    final base = (_basePrice[category] ?? 30) * (_conditionFactor[condition] ?? 0.65);
    return PriceEstimate(
      p25: base * 0.85,
      p75: base * 1.15,
      suggestedPrice: base,
    );
  }
}

// IMPORTANT: Currently, this acts as a simulated algorithmic baseline to establish our domain logic.
// In a production environment, this would be replaced with a call to a backend service that analyzes
// historical sales data to provide accurate pricing recommendations.
// ->>>>>>>  new_listing_smart_screen.dart, at line 53