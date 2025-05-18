import 'package:flutter/material.dart';

class CartProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => _items;

  // Tambahkan produk ke keranjang
  void addToCart(Map<String, dynamic> product) {
    final index = _items.indexWhere((item) => item['name'] == product['name']);

    if (index != -1) {
      _items[index]['quantity'] += 1;
    } else {
      _items.add({
        ...product,
        'quantity': 1,
        'isSelected': false, // default belum dicentang
      });
    }

    notifyListeners();
  }

  // Toggle checkbox item
  void toggleSelection(int index) {
    _items[index]['isSelected'] = !_items[index]['isSelected'];
    notifyListeners();
  }

  // Ambil hanya item yang dicentang
  List<Map<String, dynamic>> get selectedItems =>
      _items.where((item) => item['isSelected'] == true).toList();

  // Hitung total harga dari item yang dicentang saja
  double get selectedTotalPrice {
    double total = 0;
    for (var item in selectedItems) {
      total += item['price'] * item['quantity'];
    }
    return total;
  }

  // Hapus item berdasarkan index
  void removeFromCart(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  // Kosongkan semua item
  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
