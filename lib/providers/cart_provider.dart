import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CartProvider with ChangeNotifier {
  List<Map<String, dynamic>> _items = [];
  PocketBase? _pb;
  String? _userId;
  bool _isLoading = false;
  bool _isSyncing = false;

  CartProvider([this._pb]);

  List<Map<String, dynamic>> get items => _items;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  List<Map<String, dynamic>> get selectedItems {
    return _items.where((item) => item['isSelected'] == true).toList();
  }

  double get selectedTotalPrice {
    return selectedItems.fold(0.0, (total, item) {
      final price = (item['price'] is String) 
        ? double.tryParse(item['price']) ?? 0.0 
        : (item['price'] ?? 0).toDouble();
      final quantity = (item['quantity'] ?? 0).toInt();
      return total + (price * quantity);
    });
  }

  void updateAuthState(PocketBase pb, String? userId) {
    debugPrint('=== UPDATE AUTH STATE ===');
    debugPrint('Previous userId: $_userId');
    debugPrint('New userId: $userId');
    
    _pb = pb;
    
    if (_userId != userId) {
      _userId = userId;
      debugPrint('UserId changed, reinitializing cart...');
      Future.microtask(() => initializeCart(userId));
    }
  }

  Future<void> initializeCart(String? userId) async {
    debugPrint('=== INITIALIZE CART ===');
    debugPrint('UserId: $userId');
    debugPrint('PocketBase available: ${_pb != null}');
    
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      if (_userId != null && _userId!.isNotEmpty && _pb != null) {
        debugPrint('Loading from PocketBase...');
        await _loadCartFromPocketBase();
      } else {
        debugPrint('Loading from local storage...');
        await _loadCartFromLocal();
      }
      
      debugPrint('Cart initialization completed with ${_items.length} items');
    } catch (e) {
      debugPrint('Error initializing cart: $e');
      await _loadCartFromLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCartFromPocketBase() async {
    if (_pb == null || _userId == null) {
      debugPrint('Cannot load from PocketBase: pb=${_pb != null}, userId=$_userId');
      return;
    }
    
    try {
      debugPrint('=== LOADING FROM POCKETBASE ===');
      debugPrint('User ID: $_userId');
      
      final filter = 'user = "$_userId"';
      debugPrint('Using filter: $filter');
      
      final records = await _pb!.collection('cart_items').getFullList(
        filter: filter,
      );

      debugPrint('Found ${records.length} cart records');

      List<Map<String, dynamic>> cartItems = [];

      for (var record in records) {
        try {
          // Handle product_id - it might be a string or array
          dynamic productIdField = record.data['product_id'];
          String? productId;
          
          if (productIdField is List && productIdField.isNotEmpty) {
            productId = productIdField.first.toString();
            debugPrint('Product ID from array: $productId');
          } else if (productIdField is String) {
            productId = productIdField;
            debugPrint('Product ID from string: $productId');
          } else {
            debugPrint('Invalid product_id format: $productIdField');
            continue;
          }

          final quantity = record.data['quantity'] ?? 1;

          debugPrint('Processing record ${record.id}:');
          debugPrint('  Product ID: $productId');
          debugPrint('  Quantity: $quantity');

          if (productId == null || productId.isEmpty) {
            debugPrint('  Skipping record with null/empty product_id');
            continue;
          }

          // Get product details
          debugPrint('  Fetching product details for: $productId');
          try {
            final product = await _pb!.collection('products').getOne(productId);
            debugPrint('  Product found: ${product.data['name']}');
            
            final cartItem = {
              'id': product.id,
              'name': product.data['name'] ?? 'Unknown Product',
              'price': _parsePrice(product.data['price']),
              'image_url': product.data['image_url'] ?? '',
              'description': product.data['description'] ?? '',
              'quantity': quantity,
              'isSelected': false,
              'cart_record_id': record.id,
            };

            cartItems.add(cartItem);
            debugPrint('  Successfully added: ${cartItem['name']} - Rp${cartItem['price']}');
          } catch (productError) {
            debugPrint('  Error fetching product $productId: $productError');
            // Continue with next record instead of failing completely
            continue;
          }
        } catch (e) {
          debugPrint('  Error processing record ${record.id}: $e');
          continue;
        }
      }

      _items = cartItems;
      debugPrint('=== CART LOADED ===');
      debugPrint('Total items: ${_items.length}');
      for (var item in _items) {
        debugPrint('  - ${item['name']} x${item['quantity']} = Rp${item['price']}');
      }
      
      // Save to local storage as backup
      await _saveCartToLocal();
    } catch (e) {
      debugPrint('Error loading cart from PocketBase: $e');
      rethrow;
    }
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is num) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  Future<void> _saveCartToPocketBase() async {
    if (_userId == null || _userId!.isEmpty || _pb == null) {
      debugPrint('Cannot save to PocketBase: userId=$_userId, pb=${_pb != null}');
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('=== SYNCING TO POCKETBASE ===');
      debugPrint('Syncing ${_items.length} items...');
      
      final existingRecords = await _pb!.collection('cart_items').getFullList(
        filter: 'user = "$_userId"',
      );

      debugPrint('Found ${existingRecords.length} existing records');

      // Create map of existing records by product_id (handle both string and array formats)
      Map<String, String> existingRecordIds = {};
      for (var record in existingRecords) {
        dynamic productIdField = record.data['product_id'];
        String? productId;
        
        if (productIdField is List && productIdField.isNotEmpty) {
          productId = productIdField.first.toString();
        } else if (productIdField is String) {
          productId = productIdField;
        }
        
        if (productId != null) {
          existingRecordIds[productId] = record.id;
        }
      }

      for (var item in _items) {
        final productId = item['id'];
        final quantity = item['quantity'];

        debugPrint('Processing item: $productId (qty: $quantity)');

        if (existingRecordIds.containsKey(productId)) {
          // Update existing record
          final recordId = existingRecordIds[productId]!;
          await _pb!.collection('cart_items').update(recordId, body: {
            'quantity': quantity,
          });
          debugPrint('  Updated existing record: $recordId');
          existingRecordIds.remove(productId);
        } else {
          // Create new record - store as string, not array
          final newRecord = await _pb!.collection('cart_items').create(body: {
            'user': _userId,
            'product_id': productId, // Store as string
            'quantity': quantity,
          });
          item['cart_record_id'] = newRecord.id;
          debugPrint('  Created new record: ${newRecord.id}');
        }
      }

      // Delete orphaned records
      for (var recordId in existingRecordIds.values) {
        await _pb!.collection('cart_items').delete(recordId);
        debugPrint('  Deleted orphaned record: $recordId');
      }

      debugPrint('Cart sync completed successfully');
    } catch (e) {
      debugPrint('Error syncing cart to PocketBase: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _loadCartFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartDataString = prefs.getString('cart_items');
      
      if (cartDataString != null && cartDataString.isNotEmpty) {
        final List<dynamic> cartData = json.decode(cartDataString);
        _items = cartData.map((item) => Map<String, dynamic>.from(item)).toList();
        debugPrint('Loaded ${_items.length} items from local storage');
        
        // Print loaded items for debugging
        for (var item in _items) {
          debugPrint('  Local item: ${item['name']} x${item['quantity']}');
        }
      } else {
        _items = [];
        debugPrint('No items found in local storage');
      }
    } catch (e) {
      debugPrint('Error loading cart from local storage: $e');
      _items = [];
    }
  }

  Future<void> _saveCartToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove cart_record_id before saving to local storage
      final itemsToSave = _items.map((item) {
        final itemCopy = Map<String, dynamic>.from(item);
        itemCopy.remove('cart_record_id');
        return itemCopy;
      }).toList();
      
      final cartDataString = json.encode(itemsToSave);
      await prefs.setString('cart_items', cartDataString);
      debugPrint('Saved ${itemsToSave.length} items to local storage');
    } catch (e) {
      debugPrint('Error saving cart to local storage: $e');
    }
  }

  Future<void> addToCart(Map<String, dynamic> product) async {
    debugPrint('=== ADD TO CART ===');
    debugPrint('Product: ${product['name']} (${product['id']})');
    debugPrint('Current cart size: ${_items.length}');

    final existingIndex = _items.indexWhere((item) => item['id'] == product['id']);
    
    if (existingIndex >= 0) {
      _items[existingIndex]['quantity'] += 1;
      debugPrint('Updated quantity for existing item: ${_items[existingIndex]['quantity']}');
    } else {
      final cartItem = {
        'id': product['id'],
        'name': product['name'] ?? 'Unknown Product',
        'price': _parsePrice(product['price']),
        'image_url': product['image_url'] ?? '',
        'description': product['description'] ?? '',
        'quantity': 1,
        'isSelected': false,
      };
      _items.add(cartItem);
      debugPrint('Added new item to cart: ${cartItem['name']}');
    }

    debugPrint('New cart size: ${_items.length}');
    notifyListeners();

    // Sync to storage
    try {
      if (_userId != null && _userId!.isNotEmpty && _pb != null) {
        debugPrint('Syncing to PocketBase...');
        await _saveCartToPocketBase();
      } else {
        debugPrint('Saving to local storage...');
        await _saveCartToLocal();
      }
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
    
    debugPrint('Cart add operation completed');
  }

  Future<void> removeFromCart(int index) async {
    if (index < 0 || index >= _items.length) return;

    final item = _items[index];
    debugPrint('Removing from cart: ${item['name']}');

    if (item.containsKey('cart_record_id') && _userId != null && _pb != null) {
      try {
        await _pb!.collection('cart_items').delete(item['cart_record_id']);
        debugPrint('Deleted from PocketBase: ${item['cart_record_id']}');
      } catch (e) {
        debugPrint('Error deleting from PocketBase: $e');
      }
    }

    _items.removeAt(index);
    notifyListeners();
    
    // Update both storages
    await _saveCartToLocal();
    if (_userId != null && _pb != null) {
      // No need to sync to PocketBase since we already deleted the record
    }
  }

  // PERBAIKAN: Method baru untuk menghapus item berdasarkan product ID
  Future<void> removeItemByProductId(String productId) async {
    debugPrint('=== REMOVE ITEM BY PRODUCT ID ===');
    debugPrint('Looking for product ID: $productId');
    
    for (int i = _items.length - 1; i >= 0; i--) {
      if (_items[i]['id'] == productId) {
        debugPrint('Found item to remove: ${_items[i]['name']}');
        await removeFromCart(i);
        break; // Only remove the first match
      }
    }
  }

  // PERBAIKAN: Method baru untuk menghapus multiple items berdasarkan list product IDs
  Future<void> removeCheckedOutItems(List<Map<String, dynamic>> checkedOutItems) async {
    debugPrint('=== REMOVE CHECKED OUT ITEMS ===');
    debugPrint('Items to remove: ${checkedOutItems.length}');
    
    for (var checkedOutItem in checkedOutItems) {
      final productId = checkedOutItem['id'];
      final quantityToRemove = checkedOutItem['quantity'] ?? 1;
      
      debugPrint('Processing: $productId (qty: $quantityToRemove)');
      
      // Find item in cart
      for (int i = _items.length - 1; i >= 0; i--) {
        if (_items[i]['id'] == productId) {
          final currentQuantity = _items[i]['quantity'] ?? 1;
          
          if (currentQuantity <= quantityToRemove) {
            // Remove entire item if quantity is less than or equal to checked out quantity
            debugPrint('Removing entire item: ${_items[i]['name']}');
            await removeFromCart(i);
          } else {
            // Reduce quantity
            _items[i]['quantity'] = currentQuantity - quantityToRemove;
            debugPrint('Reduced quantity: ${_items[i]['name']} from $currentQuantity to ${_items[i]['quantity']}');
            notifyListeners();
            
            // Sync to storage
            if (_userId != null && _userId!.isNotEmpty && _pb != null) {
              await _saveCartToPocketBase();
            } else {
              await _saveCartToLocal();
            }
          }
          break; // Only process the first match
        }
      }
    }
    
    debugPrint('Finished removing checked out items. Remaining cart size: ${_items.length}');
  }

  void toggleSelection(int index) {
    if (index < 0 || index >= _items.length) return;
    
    _items[index]['isSelected'] = !(_items[index]['isSelected'] ?? false);
    notifyListeners();
  }

  Future<void> clearCart() async {
    debugPrint('=== CLEARING CART ===');

    if (_userId != null && _userId!.isNotEmpty && _pb != null) {
      try {
        final records = await _pb!.collection('cart_items').getFullList(
          filter: 'user = "$_userId"',
        );

        for (var record in records) {
          await _pb!.collection('cart_items').delete(record.id);
        }
        debugPrint('Cleared cart from PocketBase');
      } catch (e) {
        debugPrint('Error clearing cart from PocketBase: $e');
      }
    }

    _items.clear();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cart_items');
  }

  // Handle user login - merge local cart with PocketBase cart
  Future<void> onUserLogin(String userId) async {
    debugPrint('=== USER LOGGED IN: $userId ===');
    
    // Save current local items
    final localItems = List<Map<String, dynamic>>.from(_items);
    debugPrint('Local items before login: ${localItems.length}');
    
    _userId = userId;
    
    // Load cart from PocketBase
    await _loadCartFromPocketBase();
    debugPrint('PocketBase items after load: ${_items.length}');
    
    // Merge local items that aren't already in PocketBase
    for (var localItem in localItems) {
      final existingIndex = _items.indexWhere((item) => item['id'] == localItem['id']);
      if (existingIndex >= 0) {
        // Item exists in PocketBase, update quantity
        _items[existingIndex]['quantity'] += localItem['quantity'];
        debugPrint('Merged quantities for ${localItem['name']}: ${_items[existingIndex]['quantity']}');
      } else {
        // Item doesn't exist in PocketBase, add it
        await addToCart(localItem);
        debugPrint('Added local item to PocketBase: ${localItem['name']}');
      }
    }
    
    debugPrint('Final cart size after login: ${_items.length}');
  }

  // Handle user logout - save to local storage
  Future<void> onUserLogout() async {
    debugPrint('=== USER LOGGED OUT ===');
    
    // Save current cart to local storage
    await _saveCartToLocal();
    
    _userId = null;
    
    // Remove PocketBase record IDs but keep items in memory
    for (var item in _items) {
      item.remove('cart_record_id');
    }
    
    notifyListeners();
    debugPrint('Cart saved to local storage, ${_items.length} items preserved');
  }

  Future<void> syncWithPocketBase() async {
    if (_userId != null && _userId!.isNotEmpty && _pb != null) {
      await _saveCartToPocketBase();
    }
  }

  Future<void> refreshCart() async {
    debugPrint('=== REFRESH CART ===');
    await initializeCart(_userId);
  }

  Future<Map<String, dynamic>> testPocketBaseConnection() async {
    final result = <String, dynamic>{};
    
    try {
      result['pb_available'] = _pb != null;
      result['user_id'] = _userId;
      
      if (_pb != null) {
        result['base_url'] = _pb!.baseUrl;
        result['auth_valid'] = _pb!.authStore.isValid;
        result['auth_model'] = _pb!.authStore.model?.toString();
        
        // Test cart_items collection access
        try {
          final records = await _pb!.collection('cart_items').getFullList(
            filter: 'user = "$_userId"',
          );
          result['cart_records'] = records.length;
          result['cart_data'] = records.map((r) => r.data).toList();
        } catch (e) {
          result['cart_error'] = e.toString();
        }

        // Test products collection access - fixed method call
        try {
          final products = await _pb!.collection('products').getList(
            page: 1,
            perPage: 1,
          );
          result['products_available'] = products.items.length > 0;
          if (products.items.isNotEmpty) {
            result['sample_product'] = products.items.first.data;
          }
        } catch (e) {
          result['products_error'] = e.toString();
        }
      }
    } catch (e) {
      result['error'] = e.toString();
    }
    
    return result;
  }
}
