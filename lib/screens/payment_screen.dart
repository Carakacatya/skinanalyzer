import 'package:flutter/material.dart';
import '../constants/colors.dart';

class PaymentScreen extends StatefulWidget {
  final double totalPrice;

  const PaymentScreen({super.key, required this.totalPrice});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedPayment;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'label': 'Transfer Bank', 'icon': Icons.account_balance},
    {'label': 'E-Wallet (OVO, GoPay, Dana)', 'icon': Icons.account_balance_wallet},
    {'label': 'Kartu Kredit/Debit', 'icon': Icons.credit_card},
    {'label': 'COD (Bayar di Tempat)', 'icon': Icons.delivery_dining},
  ];

  void _confirmPayment() {
    if (_selectedPayment != null) {
      Navigator.pushNamed(context, '/payment_success');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih metode pembayaran terlebih dahulu'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalPrice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Metode Pembayaran:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            ..._paymentMethods.map((method) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: RadioListTile<String>(
                  value: method['label'],
                  groupValue: _selectedPayment,
                  onChanged: (value) {
                    setState(() {
                      _selectedPayment = value;
                    });
                  },
                  title: Text(method['label']),
                  secondary: Icon(method['icon'], color: AppColors.primary),
                  activeColor: AppColors.primary,
                ),
              );
            }).toList(),
            const Spacer(),
            Text(
              'Total: Rp ${total.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _confirmPayment,
              icon: const Icon(Icons.check_circle),
              label: const Text('Konfirmasi Pembayaran'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
