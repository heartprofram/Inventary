import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/product.dart';
import '../providers/inventory_provider.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _costController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();

  bool _isLoading = false;

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final newProduct = Product(
          id: _idController.text,
          name: _nameController.text,
          description: _descController.text,
          costPriceUSD: double.parse(_costController.text),
          salePriceUSD: double.parse(_priceController.text),
          stockQuantity: int.parse(_stockController.text),
          barCode: _barcodeController.text,
        );

        await ref.read(inventoryProvider.notifier).addProduct(newProduct);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto agregado con éxito', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Regresar al inventario
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Nuevo Producto'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(labelText: 'ID (Ej: PRD-001)'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          decoration: const InputDecoration(labelText: 'Costo USD'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(labelText: 'P. Venta USD'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(labelText: 'Stock Inicial'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          decoration: const InputDecoration(labelText: 'Código de Barras'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Producto'),
                      onPressed: _saveProduct,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
