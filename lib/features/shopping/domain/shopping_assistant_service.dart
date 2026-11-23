import 'package:equatable/equatable.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/model_provider.dart';

/// Replaceable local product catalog lookup contract (Section 7.2).
abstract class ProductCatalogLookup {
  Future<LocalProductMatch?> lookupBarcode(String barcodeValue);
}

class LocalProductMatch extends Equatable {
  const LocalProductMatch({
    required this.barcode,
    required this.productName,
    this.brand,
    this.netQuantity,
    this.category,
  });

  final String barcode;
  final String productName;
  final String? brand;
  final String? netQuantity;
  final String? category;

  @override
  List<Object?> get props => [barcode, productName, brand, netQuantity, category];
}

/// Layered offline product identification: Barcode + local DB -> OCR -> Mirage.
class ShoppingAssistantService {
  const ShoppingAssistantService({this.catalogLookup});

  final ProductCatalogLookup? catalogLookup;

  Future<String> identifyProduct({
    required VisionObservation observation,
    String? detectedBarcode,
  }) async {
    if (detectedBarcode != null && catalogLookup != null) {
      final hit = await catalogLookup!.lookupBarcode(detectedBarcode);
      if (hit != null) {
        final brand = hit.brand != null ? '${hit.brand} ' : '';
        final qty = hit.netQuantity != null ? ', ${hit.netQuantity}' : '';
        return 'Product matched locally: $brand${hit.productName}$qty.';
      }
      return 'Barcode $detectedBarcode detected, but no offline catalog entry exists locally. Reading visible packaging text next.';
    }

    if (observation.textSpans.isNotEmpty) {
      final text = observation.textSpans.map((t) => t.text).join(' ');
      return 'Package text observed: $text.';
    }

    if (observation.objects.isNotEmpty) {
      final top = observation.objects.first;
      return 'Visual item looks like ${top.name} (confidence ${(top.confidence * 100).round()}%). No barcode matched locally.';
    }

    return 'Could not identify a product clearly. Hold the label steady about 30 centimeters from the camera.';
  }
}

/// Empty offline catalog implementation until user imports an offline pack.
class EmptyLocalProductCatalog implements ProductCatalogLookup {
  const EmptyLocalProductCatalog();

  @override
  Future<LocalProductMatch?> lookupBarcode(String barcodeValue) async => null;
}

/// Optional barcode scanner contract (ML Kit bundled or ZXing offline).
abstract class BarcodeScannerProvider {
  Future<String?> scanFirstBarcode(CapturedFrame frame);
}
