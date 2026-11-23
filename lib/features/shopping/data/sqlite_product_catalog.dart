import '../../../core/storage/openetra_database.dart';
import '../domain/shopping_assistant_service.dart';

/// Offline SQLite product catalog lookup backed by `local_products` table.
class SqliteProductCatalogLookup implements ProductCatalogLookup {
  const SqliteProductCatalogLookup(this.database);

  final OpenetraDatabase database;

  @override
  Future<LocalProductMatch?> lookupBarcode(String barcodeValue) {
    return database.lookupLocalProduct(barcodeValue);
  }
}
