import 'package:flutter/material.dart';
import '../../../app/openetra_coordinator.dart';
import '../../../app/theme.dart';
import '../../../core/storage/openetra_database.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../../shared/widgets/openetra_components.dart';
import '../domain/shopping_assistant_service.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({
    super.key,
    required this.coordinator,
    required this.database,
  });

  final OpenetraCoordinator coordinator;
  final OpenetraDatabase database;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  List<LocalProductMatch> _catalog = const [];
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final rows = await widget.database.listLocalProducts();
    if (mounted) {
      setState(() => _catalog = rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Product & Shopping')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_status != null) ...[
            SpokenStatusBanner(
              statusText: _status!,
              isDegraded: false,
              isBusy: false,
            ),
            const SizedBox(height: 16),
          ],
          AccessibleActionTile(
            title: 'Scan Product Barcode & Label',
            subtitle:
                'Runs offline ML Kit barcode + SQLite catalog + Mirage OCR fallback',
            semanticHint: 'Double tap to scan a packaged item',
            icon: Icons.qr_code_scanner,
            filledAccent: true,
            onPressed: () {
              Navigator.of(context).pop();
              widget.coordinator.runScanProduct();
            },
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              'Add Product to Offline Catalog',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 10),
          OpenetraTextField(
            controller: _barcodeController,
            labelText: 'Barcode digits (e.g., 8901058851234)',
          ),
          const SizedBox(height: OpenetraSpacing.sm + 2),
          OpenetraTextField(
            controller: _nameController,
            labelText: 'Product name',
          ),
          const SizedBox(height: OpenetraSpacing.sm + 2),
          OpenetraTextField(
            controller: _brandController,
            labelText: 'Brand (optional)',
          ),
          const SizedBox(height: 12),
          AccessibleActionTile(
            title: 'Save Product Offline',
            subtitle: 'Stores barcode mapping in local SQLite',
            semanticHint: 'Double tap to save custom product entry',
            icon: Icons.save_alt,
            onPressed: () async {
              final code = _barcodeController.text.trim();
              final name = _nameController.text.trim();
              if (code.isEmpty || name.isEmpty) return;
              await widget.database.upsertLocalProduct(
                product: LocalProductMatch(
                  barcode: code,
                  productName: name,
                  brand: _brandController.text.trim().isEmpty
                      ? null
                      : _brandController.text.trim(),
                ),
              );
              _barcodeController.clear();
              _nameController.clear();
              _brandController.clear();
              await _loadCatalog();
              if (mounted) {
                setState(() => _status = 'Saved "$name" ($code) locally.');
              }
            },
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              'Offline Product Catalog (${_catalog.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 10),
          ..._catalog.map((p) {
            final brand = p.brand != null ? '${p.brand} ' : '';
            final qty = p.netQuantity != null ? ' (${p.netQuantity})' : '';
            return OpenetraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$brand${p.productName}$qty',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Barcode: ${p.barcode}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
