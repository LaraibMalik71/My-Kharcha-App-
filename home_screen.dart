//changee22

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_theme.dart';
import 'database/database_helper.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;
  double _income = 0, _allocated = 0, _spent = 0, _unallocated = 0;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _transactions = [];

  int _dashboardLoadVersion = 0;

  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  int? _i(dynamic v) => v is int ? v : int.tryParse('$v');

  @override
  void initState() {
    super.initState();
    _loadDashboard(showInitialLoading: true);
  }

  Future<void> _loadDashboard({bool showInitialLoading = false}) async {
    final int requestVersion = ++_dashboardLoadVersion;

    // Only show full-screen loader for first dashboard load.
    // Small updates refresh silently.
    if (showInitialLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() {
        _error = null;
      });
    }

    try {
      final db = DatabaseHelper.instance;
      final settings = await db.getAppSettings();

      final data = await Future.wait([
        db.getTotalAllocated(),
        db.getCurrentMonthTotalSpent(),
        db.getCurrentMonthCategorySpending(),
        db.getRecentTransactions(limit: 5),
      ]);

      if (!mounted) return;

      // Ignore stale DB reads if a newer refresh started.
      if (requestVersion != _dashboardLoadVersion) {
        return;
      }

      setState(() {
        _income = _n(settings['total_income']);
        _unallocated = _n(settings['unallocated_balance']);
        _allocated = data[0] as double;
        _spent = data[1] as double;
        _categories = List<Map<String, dynamic>>.from(data[2] as List);
        _transactions = List<Map<String, dynamic>>.from(data[3] as List);
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Dashboard error: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      if (requestVersion != _dashboardLoadVersion) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _money(double v) => 'Rs. ${v.toStringAsFixed(0)}';

  String _month() {
    const m = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final d = DateTime.now();
    return '${m[d.month - 1]} ${d.year}';
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'morning'
        : h < 17
        ? 'afternoon'
        : 'evening';
  }

  IconData _catIcon(String? icon) {
    const icons = <String, IconData>{
      'bolt': Icons.bolt_rounded,
      'school': Icons.school_rounded,
      'home': Icons.home_rounded,
      'credit_card': Icons.credit_card_rounded,
      'shopping_basket': Icons.shopping_basket_rounded,
      'savings': Icons.savings_rounded,
      'travel': Icons.flight_takeoff_rounded,
      'food': Icons.restaurant_rounded,
      'shopping': Icons.shopping_bag_rounded,
      'health': Icons.favorite_rounded,
      'medical': Icons.medical_services_rounded,
      'transport': Icons.directions_car_rounded,
      'business': Icons.business_center_rounded,
      'internet': Icons.wifi_rounded,
      'category': Icons.category_rounded,
    };
    return icons[icon] ?? Icons.category_rounded;
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _header() {
    final user = FirebaseAuth.instance.currentUser;
    final raw = user?.displayName?.trim();
    final name = raw == null || raw.isEmpty ? 'User' : raw.split(' ').first;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _topButton(Icons.menu_rounded, () {}),
              const Spacer(),
              _topButton(Icons.notifications_none_rounded, () {}),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Good ${_greeting()},',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            '$name 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Smart Spending. Smart Tracking.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _topButton(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(13),
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );

  Widget _incomeCard() => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(.10),
          blurRadius: 20,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Income',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _money(_income),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _month(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 11),
              OutlinedButton.icon(
                onPressed: _addIncome,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Add Income'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(.08),
            shape: BoxShape.circle,
          ),
          child: const CustomPaint(painter: _WalletCoinPainter()),
        ),
      ],
    ),
  );

  Widget _summaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) => Container(
    height: 108,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: color.withOpacity(.12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              child: Text(
                _money(amount),
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _summary() => SizedBox(
    height: 108,
    child: Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Allocated',
            _allocated,
            Icons.track_changes_rounded,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            'Unallocated',
            _unallocated,
            Icons.account_balance_rounded,
            AppColors.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            'Spent',
            _spent,
            Icons.payments_rounded,
            AppColors.danger,
          ),
        ),
      ],
    ),
  );

  Widget _category(Map<String, dynamic> c) {
    final id = _i(c['id'])!;
    final budget = _n(c['budget_amount']);
    final spent = _n(c['spent']);
    final pct = budget <= 0 ? 0.0 : spent / budget;
    final remaining = budget - spent;
    final color = pct >= 1
        ? AppColors.danger
        : pct >= .8
        ? AppColors.accent
        : AppColors.primary;
    final isDefault = (c['is_default'] as num?)?.toInt() == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(.08)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _categoryDetails(id),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _catIcon(c['icon']?.toString()),
                color: AppColors.primary,
                size: 23,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _categoryDetails(id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c['name']?.toString() ?? 'Category',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_money(spent)} / ${_money(budget)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        pct >= 1
                            ? 'Budget exceeded'
                            : '${(pct * 100).round()}% used',
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Remaining ${_money(remaining < 0 ? 0 : remaining)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _categoryDetails(id, initialAction: 'edit');
              if (value == 'manage') {
                _categoryDetails(id, initialAction: 'manage');
              }
              if (value == 'delete') {
                _categoryDetails(id, initialAction: 'delete');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      size: 19,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 10),
                    Text('Edit Category'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 19,
                      color: AppColors.accent,
                    ),
                    SizedBox(width: 10),
                    Text('Manage Expenses'),
                  ],
                ),
              ),
              if (!isDefault)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 10),
                      Text('Delete Category'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transaction(Map<String, dynamic> t) {
    final id = _i(t['id']);
    final income = t['type'] == 'income';
    final amount = _n(t['amount']);
    final color = income ? AppColors.success : AppColors.danger;
    final source = t['income_source']?.toString();

    final title = income
        ? (source?.isNotEmpty == true ? source! : 'Income')
        : (t['sub_category_name']?.toString().isNotEmpty == true
              ? t['sub_category_name'].toString()
              : (t['category_name']?.toString() ?? 'Expense'));

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                income
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: color,
                size: 19,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    income
                        ? 'Income'
                        : (t['category_name']?.toString() ?? 'Expense'),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            Text(
              '${income ? '+' : '-'}${_money(amount)}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),

            if (id != null)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit' && income) {
                    await _editIncome(t);
                  } else if (value == 'details') {
                    await _showTransactionDetails(t);
                  } else if (value == 'delete') {
                    await _deleteOne(id);
                  }
                },
                itemBuilder: (_) {
                  if (income) {
                    return const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'details', child: Text('Details')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ];
                  }

                  return const [
                    PopupMenuItem(value: 'details', child: Text('Details')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ];
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransactionDetails(Map<String, dynamic> t) async {
    final income = t['type'] == 'income';

    final amount = _n(t['amount']);
    final date = DateTime.tryParse(t['date']?.toString() ?? '');

    final category = t['category_name']?.toString();
    final subCategory = t['sub_category_name']?.toString();
    final source = t['income_source']?.toString();

    final note = t['note']?.toString().trim() ?? '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Transaction Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Type', income ? 'Income' : 'Expense'),
              const SizedBox(height: 10),

              _detailRow(
                'Name',
                income
                    ? (source?.isNotEmpty == true ? source! : 'Income')
                    : (subCategory?.isNotEmpty == true
                          ? subCategory!
                          : 'Expense'),
              ),

              if (!income && category != null) ...[
                const SizedBox(height: 10),
                _detailRow('Category', category),
              ],

              const SizedBox(height: 10),
              _detailRow('Amount', _money(amount)),

              if (date != null) ...[
                const SizedBox(height: 10),
                _detailRow('Date', _date(date)),
              ],

              const SizedBox(height: 10),
              _detailRow('Note', note.isEmpty ? 'No note added' : note),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Future<void> _deleteOne(int id) async {
    try {
      await DatabaseHelper.instance.deleteTransaction(id);
      await _loadDashboard();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction deleted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );

  Future<void> _addIncome() async {
    String source = 'Salary';
    DateTime date = DateTime.now();

    const sources = ['Salary', 'Freelance', 'Business', 'Bonus', 'Other'];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        final amountController = TextEditingController();
        final noteController = TextEditingController();

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Add Income',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        prefixText: 'Rs. ',
                        labelText: 'Amount',
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: source,
                      decoration: const InputDecoration(labelText: 'Source'),
                      items: sources
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          source = value ?? 'Other';
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date', style: TextStyle(fontSize: 12)),
                      subtitle: Text(_date(date)),
                      trailing: const Icon(Icons.calendar_month_rounded),
                      onTap: () async {
                        final picked = await _pickDate(date);

                        if (picked != null) {
                          setDialogState(() {
                            date = picked;
                          });
                        }
                      },
                    ),

                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () {
                    final enteredAmount = amountController.text.trim();

                    final enteredNote = noteController.text.trim();

                    Navigator.of(dialogContext).pop({
                      'amount': enteredAmount,
                      'source': source,
                      'date': date.toIso8601String(),
                      'note': enteredNote,
                    });
                  },
                  child: const Text('Save Income'),
                ),
              ],
            );
          },
        );
      },
    );

    // ----------------------------------------------------------
    // CANCEL
    // ----------------------------------------------------------
    // If Cancel was pressed, result is null.
    // Do absolutely nothing.
    if (result == null) {
      return;
    }

    // ----------------------------------------------------------
    // AMOUNT
    // ----------------------------------------------------------
    // Empty amount is treated as 0.
    final amountText = result['amount']?.toString().trim() ?? '';

    final value = double.tryParse(amountText) ?? 0;

    if (value <= 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero.')),
      );

      return;
    }

    // ----------------------------------------------------------
    // SAVE
    // ----------------------------------------------------------
    try {
      await DatabaseHelper.instance.addIncomeTransaction(
        amount: value,
        source: result['source']?.toString() ?? 'Other',
        note: (result['note']?.toString().trim().isEmpty ?? true)
            ? null
            : result['note'].toString().trim(),
        date: result['date']?.toString(),
      );

      if (!mounted) return;

      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editTransaction(Map<String, dynamic> t) async {
    if (t['type'] == 'income') {
      await _editIncome(t);
      return;
    }
    await _editExpense(t);
  }

  Future<void> _editIncome(Map<String, dynamic> t) async {
    String source = t['income_source']?.toString() ?? 'Other';

    DateTime date =
        DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now();

    const sources = ['Salary', 'Freelance', 'Business', 'Bonus', 'Other'];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        final amountController = TextEditingController(
          text: _n(t['amount']).toStringAsFixed(0),
        );

        final noteController = TextEditingController(
          text: t['note']?.toString() ?? '',
        );

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Income'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        prefixText: 'Rs. ',
                        labelText: 'Amount',
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: sources.contains(source) ? source : 'Other',
                      items: sources
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          source = value ?? 'Other';
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Source'),
                    ),

                    const SizedBox(height: 12),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date'),
                      subtitle: Text(_date(date)),
                      onTap: () async {
                        final picked = await _pickDate(date);

                        if (picked != null) {
                          setDialogState(() {
                            date = picked;
                          });
                        }
                      },
                    ),

                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Note'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Cancel = do absolutely nothing.
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop({
                      'amount': amountController.text.trim(),
                      'source': source,
                      'note': noteController.text.trim(),
                      'date': date.toIso8601String(),
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // ----------------------------------------------------------
    // CANCEL
    // ----------------------------------------------------------
    // Cancel returns null.
    // Do NOT validate, update, or show an error.
    if (result == null) {
      return;
    }

    // ----------------------------------------------------------
    // AMOUNT
    // ----------------------------------------------------------
    // Empty amount is treated as 0.
    final amountText = result['amount']?.toString().trim() ?? '';

    final newAmount = double.tryParse(amountText) ?? 0;

    if (newAmount <= 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero.')),
      );

      return;
    }

    // ----------------------------------------------------------
    // UPDATE
    // ----------------------------------------------------------
    try {
      await DatabaseHelper.instance.updateIncomeTransaction(
        id: _i(t['id'])!,
        newAmount: newAmount,
        newSource: result['source']?.toString() ?? 'Other',
        newNote: (result['note']?.toString().trim().isEmpty ?? true)
            ? null
            : result['note'].toString().trim(),
        newDate: result['date']?.toString(),
      );

      if (!mounted) return;

      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editExpense(Map<String, dynamic> t) async {
    final categories = await DatabaseHelper.instance.getAllCategories();

    final amount = TextEditingController(
      text: _n(t['amount']).toStringAsFixed(0),
    );

    final note = TextEditingController(text: t['note']?.toString() ?? '');

    int categoryId = _i(t['category_id']) ?? (_i(categories.first['id'])!);

    int? subId = _i(t['sub_category_id']);

    DateTime date =
        DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now();

    List<Map<String, dynamic>> subs = await DatabaseHelper.instance
        .getSubCategories(categoryId);

    if (subId != null && !subs.any((s) => _i(s['id']) == subId)) {
      subId = null;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Edit Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    prefixText: 'Rs. ',
                    labelText: 'Amount',
                  ),
                ),
                DropdownButtonFormField<int>(
                  value: categoryId,
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: _i(c['id']),
                          child: Text(c['name'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;

                    final ss = await DatabaseHelper.instance.getSubCategories(
                      v,
                    );

                    set(() {
                      categoryId = v;
                      subs = ss;
                      subId = null;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                if (subs.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: subId,
                    items: subs
                        .map(
                          (s) => DropdownMenuItem(
                            value: _i(s['id']),
                            child: Text(s['name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => subId = v),
                    decoration: const InputDecoration(labelText: 'Subcategory'),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(_date(date)),
                  onTap: () async {
                    final d = await _pickDate(date);
                    if (d != null) set(() => date = d);
                  },
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await DatabaseHelper.instance.updateExpenseTransaction(
          id: _i(t['id'])!,
          newAmount: double.parse(amount.text),
          newCategoryId: categoryId,
          newSubCategoryId: subId,
          newNote: note.text.trim().isEmpty ? null : note.text.trim(),
          newDate: date.toIso8601String(),
        );

        await _loadDashboard();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }

    amount.dispose();
    note.dispose();
  }

  Future<void> _categoryDetails(int categoryId, {String? initialAction}) async {
    final category = await DatabaseHelper.instance.getCategoryById(categoryId);

    if (category == null || !mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => _CategorySheet(
        category: category,
        onChanged: () async {
          await _loadDashboard();
        },
        onError: (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        },
        home: this,
        initialAction: initialAction,
      ),
    );

    // Final refresh when category sheet closes.
    if (!mounted) return;
    await _loadDashboard();
  }

  Future<void> _addCustomCategory() async {
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final controller = TextEditingController();

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final trimmed = controller.text.trim();
            final canCreate = trimmed.length >= 2;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Add Custom Category',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  setDialogState(() {});
                },
                onSubmitted: (_) {
                  if (controller.text.trim().length >= 2) {
                    Navigator.of(dialogContext).pop(controller.text.trim());
                  }
                },
                decoration: const InputDecoration(hintText: 'e.g. Travel'),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canCreate
                      ? () {
                          Navigator.of(dialogContext).pop(trimmed);
                        }
                      : null,
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (name == null || name.trim().length < 2) {
      return;
    }

    final cleanName = name.trim();

    try {
      await DatabaseHelper.instance.insertCustomCategory(name: cleanName);

      if (!mounted) return;

      await _loadDashboard();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$cleanName category created.')));
    } catch (e, st) {
      debugPrint('Add custom category database error: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;

      final message = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Invalid argument(s): ', '');

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _allTransactions() async {
    final all = await DatabaseHelper.instance.getAllTransactions();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * .82,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const Text(
              'Monthly Transactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: all.isEmpty
                  ? const Center(child: Text('No transactions yet.'))
                  : ListView.builder(
                      itemCount: all.length,
                      itemBuilder: (_, i) => _transaction(all[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (_error != null) {
      body = ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 50,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Unable to load Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
          Center(
            child: ElevatedButton(
              onPressed: _loadDashboard,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    } else {
      body = RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadDashboard,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _incomeCard(),
                  const SizedBox(height: 12),
                  _summary(),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_categories.length}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._categories.map(_category),
                  InkWell(
                    onTap: _addCustomCategory,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(.18),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppColors.primary,
                            size: 25,
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Add Custom Category',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      const Text(
                        'Monthly Transactions',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _allTransactions,
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  if (_transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text(
                          'No transactions yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ..._transactions.map((t) => _transaction(t)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.white,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spend smarter',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Keep an eye on your category budgets.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: const Text('Logout'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: body),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final Map<String, dynamic> category;
  final Future<void> Function() onChanged;
  final void Function(Object) onError;
  final _HomeScreenState home;
  final String? initialAction;

  const _CategorySheet({
    required this.category,
    required this.onChanged,
    required this.onError,
    required this.home,
    this.initialAction,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  List<Map<String, dynamic>> subs = [];
  bool loading = true;
  bool manageMode = false;
  final Set<int> selected = {};
  bool _initialHandled = false;

  int _loadVersion = 0;

  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  int? _i(dynamic v) => v is int ? v : int.tryParse('$v');

  int get categoryId => _i(widget.category['id'])!;

  double get budget => _n(widget.category['budget_amount']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialHandled && widget.initialAction != null) {
      _initialHandled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        switch (widget.initialAction) {
          case 'edit':
            _editCategory();
            break;
          case 'manage':
            _manageExpenses();
            break;
          case 'delete':
            _deleteCategory();
            break;
        }
      });
    }
  }

  Future<void> _load() async {
    final int requestVersion = ++_loadVersion;

    try {
      final rows = await DatabaseHelper.instance.getSubcategoryDetails(
        categoryId,
      );

      if (!mounted) return;
      if (requestVersion != _loadVersion) return;

      setState(() {
        subs = rows;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (requestVersion != _loadVersion) return;

      setState(() => loading = false);
      widget.onError(e);
    }
  }

  Future<void> _showCategoryMessage(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense() async {
    DateTime date = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        final nameController = TextEditingController();
        final amountController = TextEditingController();
        final noteController = TextEditingController();

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Expense name',
                        hintText: 'e.g. Electricity',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Spent amount',
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_rounded),
                      title: const Text('Date'),
                      subtitle: Text(
                        '${date.day.toString().padLeft(2, '0')} '
                        '${date.month.toString().padLeft(2, '0')} '
                        '${date.year}',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            date = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop({
                      'name': nameController.text.trim(),
                      'amount': amountController.text.trim(),
                      'note': noteController.text.trim(),
                      'date': date.toIso8601String(),
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // ------------------------------------------------------------
    // CANCEL
    // ------------------------------------------------------------
    if (result == null) {
      return;
    }

    // ------------------------------------------------------------
    // EXPENSE NAME
    // ------------------------------------------------------------
    final clean = result['name']?.toString().trim() ?? '';

    if (clean.length < 2) {
      if (!mounted) return;

      await _showCategoryMessage('Expense name must be at least 2 characters.');

      return;
    }

    // ------------------------------------------------------------
    // AMOUNT
    // ------------------------------------------------------------
    // Empty amount is treated as 0.
    final amountText = result['amount']?.toString().trim() ?? '';
    final value = double.tryParse(amountText) ?? 0;

    // Negative amount is invalid.
    // Zero/empty amount is valid and creates the expense name
    // without creating a transaction.
    if (value < 0) {
      if (!mounted) return;

      await _showCategoryMessage('Amount must be greater than zero.');

      return;
    }

    try {
      // ------------------------------------------------------------
      // CREATE EXPENSE / SUB-EXPENSE
      // ------------------------------------------------------------
      final subId = await _createNewSubExpense(clean);

      // ------------------------------------------------------------
      // ZERO AMOUNT
      // ------------------------------------------------------------
      // Do not create a transaction because the transactions table
      // requires amount > 0.
      //
      // The sub-expense itself now exists and its spent amount
      // remains Rs. 0.
      if (value == 0) {
        await _load();
        await widget.onChanged();
        return;
      }

      // ------------------------------------------------------------
      // BUDGET
      // ------------------------------------------------------------
      final rawRemaining = await DatabaseHelper.instance
          .getCurrentMonthCategoryRemaining(categoryId);

      final remaining = rawRemaining < 0 ? 0.0 : rawRemaining;

      bool forceOverspent = false;

      // ------------------------------------------------------------
      // BUDGET EXCEEDED
      // ------------------------------------------------------------
      if (value > remaining + 0.01) {
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final shortage = value - remaining;

            return AlertDialog(
              title: const Text('Budget Exceeded'),
              content: Text(
                'Remaining: ${widget.home._money(remaining)}\n'
                'Expense: ${widget.home._money(value)}\n\n'
                'This expense exceeds the remaining allocation by '
                '${widget.home._money(shortage)}.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'increase'),
                  child: const Text('Increase Allocation'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'overspent'),
                  child: Text(
                    'Mark as Overspent',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );

        if (action == null || action == 'cancel') {
          return;
        }

        if (action == 'overspent') {
          forceOverspent = true;
        } else if (action == 'increase') {
          final shortage = value - remaining;

          final funded = await _increaseAllocationFlow(
            requiredIncrease: shortage,
          );

          if (!funded) {
            return;
          }

          forceOverspent = false;
        }
      }

      // ------------------------------------------------------------
      // CREATE TRANSACTION
      // ------------------------------------------------------------
      await DatabaseHelper.instance.insertTransaction(
        categoryId: categoryId,
        subCategoryId: subId,
        amount: value,
        type: 'expense',
        note: (result['note']?.toString().trim().isEmpty ?? true)
            ? null
            : result['note'].toString().trim(),
        date: result['date']?.toString() ?? DateTime.now().toIso8601String(),
        isOverspent: forceOverspent,
      );

      await _load();
      await widget.onChanged();
    } catch (e) {
      widget.onError(e);
    }
  }

  Future<int> _createNewSubExpense(String name) async {
    final existing = await DatabaseHelper.instance.getSubCategories(categoryId);

    final duplicate = existing.any(
      (s) => s['name'].toString().trim().toLowerCase() == name.toLowerCase(),
    );

    if (duplicate) {
      throw ArgumentError(
        'This sub-expense already exists. Enter a new sub-expense name.',
      );
    }

    return DatabaseHelper.instance.insertSubCategory(
      categoryId: categoryId,
      name: name,
    );
  }

  Future<bool> _increaseAllocationFlow({
    required double requiredIncrease,
  }) async {
    if (requiredIncrease <= 0.01) return true;

    final categories = await DatabaseHelper.instance.getAllCategories();

    final unallocated = await DatabaseHelper.instance.getUnallocatedBalance();

    final other = <Map<String, dynamic>>[];

    // Only show categories that have enough remaining balance
    // to provide the COMPLETE required amount.
    for (final c in categories) {
      final id = _i(c['id'])!;

      if (id == categoryId) continue;

      final available = await DatabaseHelper.instance
          .getCurrentMonthCategoryRemaining(id);

      if (available + 0.01 >= requiredIncrease) {
        other.add({
          'id': id,
          'name': c['name'].toString(),
          'available': available,
        });
      }
    }

    final unallocatedEnough = unallocated + 0.01 >= requiredIncrease;

    // If unallocated has enough money, use it by default.
    // Otherwise, if a category is available, select category.
    String source = unallocatedEnough ? 'unallocated' : 'category';

    int? sourceId;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Increase Allocation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Need ${widget.home._money(requiredIncrease)} additional allocation.',
                  ),
                ),

                const SizedBox(height: 10),

                // ------------------------------------------------------------
                // USE UNALLOCATED INCOME
                // ------------------------------------------------------------
                RadioListTile<String>(
                  value: 'unallocated',
                  groupValue: source,

                  // Disable this option when unallocated is insufficient.
                  onChanged: unallocatedEnough
                      ? (v) {
                          set(() {
                            source = v!;
                            sourceId = null;
                          });
                        }
                      : null,

                  title: const Text('Use Unallocated Income'),

                  subtitle: Text(
                    unallocatedEnough
                        ? 'Available ${widget.home._money(unallocated)}'
                        : 'Insufficient • Available ${widget.home._money(unallocated)}',
                  ),

                  contentPadding: EdgeInsets.zero,
                ),

                // ------------------------------------------------------------
                // USE ANOTHER CATEGORY
                // ------------------------------------------------------------
                if (other.isNotEmpty)
                  RadioListTile<String>(
                    value: 'category',
                    groupValue: source,
                    onChanged: (v) {
                      set(() {
                        source = v!;
                        sourceId = null;
                      });
                    },
                    title: const Text('Use Another Category'),
                    subtitle: Text(
                      '${other.length} eligible source '
                      '${other.length == 1 ? 'category' : 'categories'}',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),

                // ------------------------------------------------------------
                // SOURCE CATEGORY DROPDOWN
                // ------------------------------------------------------------
                if (source == 'category' && other.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: sourceId,
                    items: other
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(
                              '${c['name']} • '
                              '${widget.home._money(c['available'] as double)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      set(() {
                        sourceId = v;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Source category',
                    ),
                  ),

                // ------------------------------------------------------------
                // NO CATEGORY HAS ENOUGH MONEY
                // ------------------------------------------------------------
                if (other.isEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No category has enough remaining balance to '
                      'transfer ${widget.home._money(requiredIncrease)}.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                // Unallocated selected but insufficient.
                if (source == 'unallocated' && !unallocatedEnough) {
                  return;
                }

                // Category selected but no category chosen.
                if (source == 'category' && sourceId == null) {
                  return;
                }

                Navigator.pop(ctx, 'continue');
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );

    if (result != 'continue') return false;

    // ------------------------------------------------------------------------
    // TRANSFER FROM UNALLOCATED INCOME
    // ------------------------------------------------------------------------
    if (source == 'unallocated') {
      final ok = await DatabaseHelper.instance.increaseCategoryFromUnallocated(
        categoryId: categoryId,
        amount: requiredIncrease,
      );

      if (!ok) {
        widget.onError(
          StateError('Not enough unallocated income for this increase.'),
        );
      }

      return ok;
    }

    // ------------------------------------------------------------------------
    // TRANSFER FROM ANOTHER CATEGORY
    // ------------------------------------------------------------------------
    if (sourceId == null) {
      widget.onError(StateError('Select a source category.'));
      return false;
    }

    final ok = await DatabaseHelper.instance.increaseCategoryFromCategory(
      sourceCategoryId: sourceId!,
      destinationCategoryId: categoryId,
      amount: requiredIncrease,
    );

    if (!ok) {
      widget.onError(
        StateError(
          'The selected category does not have enough remaining allocation.',
        ),
      );
    }

    return ok;
  }

  Future<void> _editSub(Map<String, dynamic> sub) async {
    final id = _i(sub['id'])!;

    final existingAmount = _n(sub['spent']);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    final transactions = await DatabaseHelper.instance.getAllTransactions(
      subCategoryId: id,
      startDate: monthStart,
      endDate: monthEnd,
    );

    final existingTransaction = transactions.isEmpty
        ? null
        : transactions.first;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        final name = TextEditingController(text: sub['name']?.toString() ?? '');

        final amount = TextEditingController(
          text: existingAmount > 0 ? existingAmount.toStringAsFixed(0) : '',
        );

        final note = TextEditingController(
          text: existingTransaction?['note']?.toString() ?? '',
        );

        return AlertDialog(
          title: const Text('Edit Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Expense name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Spent amount',
                    prefixText: 'Rs. ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                });
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop({
                  'name': name.text.trim(),
                  'amount': amount.text.trim(),
                  'note': note.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    // ------------------------------------------------------------
    // CANCEL
    // ------------------------------------------------------------
    // Cancel returns null and absolutely nothing is changed.
    if (result == null) {
      return;
    }

    // ------------------------------------------------------------
    // VALIDATE EXPENSE NAME
    // ------------------------------------------------------------
    final cleanName = result['name']?.toString().trim() ?? '';

    if (cleanName.length < 2) {
      if (!mounted) return;

      await _showCategoryMessage('Expense name must be at least 2 characters.');
      return;
    }

    // ------------------------------------------------------------
    // VALIDATE AMOUNT
    // ------------------------------------------------------------
    final amountText = result['amount']?.toString().trim() ?? '';

    // Empty amount = 0.
    final value = double.tryParse(amountText) ?? 0;

    // Negative amount is invalid.
    // Zero is valid for a name-only expense.
    if (value < 0) {
      if (!mounted) return;

      await _showCategoryMessage('Amount must be greater than zero.');
      return;
    }

    // ------------------------------------------------------------
    // CHECK DUPLICATE EXPENSE NAME
    // ------------------------------------------------------------
    final allSubs = await DatabaseHelper.instance.getSubcategoryDetails(
      categoryId,
    );

    final duplicate = allSubs.any((item) {
      final itemId = _i(item['id']);

      return itemId != id &&
          item['name']?.toString().trim().toLowerCase() ==
              cleanName.toLowerCase();
    });

    if (duplicate) {
      if (!mounted) return;

      await _showCategoryMessage('An expense with this name already exists.');
      return;
    }

    // ------------------------------------------------------------
    // ZERO AMOUNT
    // ------------------------------------------------------------
    // The sub-expense remains.
    //
    // If a real transaction exists:
    //   deleteTransaction()
    //       -> reverses category spent
    //       -> reverses monthly spent
    //       -> deletes the transaction
    //
    // Therefore the expense remains visible as Rs. 0,
    // but there is NO transaction for it.
    // ------------------------------------------------------------
    if (value == 0) {
      if (existingTransaction != null) {
        final transactionId = _i(existingTransaction['id'])!;

        await DatabaseHelper.instance.deleteTransaction(transactionId);
      }

      await DatabaseHelper.instance.updateSubCategory(id: id, name: cleanName);

      await _load();
      await widget.onChanged();
      return;
    }

    // ------------------------------------------------------------
    // NO EXISTING TRANSACTION + POSITIVE AMOUNT
    // ------------------------------------------------------------
    if (existingTransaction == null) {
      await DatabaseHelper.instance.insertTransaction(
        categoryId: categoryId,
        subCategoryId: id,
        amount: value,
        type: 'expense',
        note: result['note']?.toString().trim().isEmpty ?? true
            ? null
            : result['note'].toString().trim(),
        date: DateTime.now().toIso8601String(),
        isOverspent: false,
      );

      await DatabaseHelper.instance.updateSubCategory(id: id, name: cleanName);

      await _load();
      await widget.onChanged();
      return;
    }

    final transactionId = _i(existingTransaction['id'])!;
    final oldAmount = _n(existingTransaction['amount']);

    // ------------------------------------------------------------
    // OLD TRANSACTION MUST NOT COUNT AGAINST NEW AMOUNT
    // ------------------------------------------------------------
    final currentRemaining = await DatabaseHelper.instance
        .getCurrentMonthCategoryRemaining(categoryId);

    final availableForEdit = (currentRemaining + oldAmount).clamp(
      0.0,
      double.infinity,
    );

    bool forceOverspent = false;

    // ------------------------------------------------------------
    // BUDGET EXCEEDED
    // ------------------------------------------------------------
    if (value > availableForEdit + 0.01) {
      final shortage = value - availableForEdit;

      final action = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Budget Exceeded'),
            content: Text(
              'Remaining: ${widget.home._money(availableForEdit)}\n'
              'Expense: ${widget.home._money(value)}\n\n'
              'This expense exceeds the remaining allocation by '
              '${widget.home._money(shortage)}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'increase'),
                child: const Text('Increase Allocation'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'overspent'),
                child: Text(
                  'Mark as Overspent',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (action == null || action == 'cancel') {
        return;
      }

      if (action == 'overspent') {
        forceOverspent = true;
      } else if (action == 'increase') {
        final funded = await _increaseAllocationFlow(
          requiredIncrease: shortage,
        );

        if (!funded) {
          return;
        }

        forceOverspent = false;
      }
    } else {
      // If an old overspent expense is edited back within budget,
      // clear its overspent status.
      forceOverspent = false;
    }

    // ------------------------------------------------------------
    // UPDATE EXISTING POSITIVE TRANSACTION
    // ------------------------------------------------------------
    await DatabaseHelper.instance.updateExpenseTransaction(
      id: transactionId,
      newAmount: value,
      newCategoryId: categoryId,
      newSubCategoryId: id,
      newNote: result['note']?.toString().trim().isEmpty ?? true
          ? null
          : result['note'].toString().trim(),
      newDate: existingTransaction['date']?.toString(),
      forceOverspent: forceOverspent,
    );

    await DatabaseHelper.instance.updateSubCategory(id: id, name: cleanName);

    await _load();
    await widget.onChanged();
  }

  Future<void> _manageExpenses() async {
    setState(() {
      manageMode = true;
      selected.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (selected.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected sub-expenses?'),
        content: Text(
          'This permanently deletes ${selected.length} selected sub-expense(s) and their expense records. The category will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await DatabaseHelper.instance.deleteTransactionsBySubCategories(
        selected.toList(),
      );

      selected.clear();

      setState(() => manageMode = false);

      await _load();
      await widget.onChanged();
    } catch (e) {
      widget.onError(e);
    }
  }

  Future<void> _editCategory() async {
    final name = TextEditingController(
      text: widget.category['name'].toString(),
    );

    final allocation = TextEditingController(text: budget.toStringAsFixed(0));

    final currentSpent = subs.fold<double>(0, (sum, s) => sum + _n(s['spent']));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Category name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: allocation,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: 'Rs. ',
                labelText: 'Allocated amount',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Current spent: Rs. ${currentSpent.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final enteredName = name.text.trim();
    final enteredAllocation = allocation.text.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      allocation.dispose();
    });

    if (result != true) {
      return;
    }

    try {
      final newBudget = double.tryParse(enteredAllocation);

      if (enteredName.length < 2) {
        throw ArgumentError('Category name is too short.');
      }

      if (newBudget == null || newBudget < 0) {
        throw ArgumentError('Enter a valid allocation.');
      }

      if (newBudget + 0.01 < currentSpent) {
        throw StateError(
          'Allocation cannot be lower than money already spent.',
        );
      }

      final diff = newBudget - budget;

      if (diff > 0.01) {
        final ok = await _increaseAllocationFlow(requiredIncrease: diff);

        if (!ok) return;
      } else if (diff < -0.01) {
        final ok = await DatabaseHelper.instance.reduceCategoryAllocation(
          categoryId: categoryId,
          amount: -diff,
        );

        if (!ok) {
          throw StateError(
            'The allocation cannot be reduced below the amount already spent.',
          );
        }
      }

      await DatabaseHelper.instance.renameCategory(
        categoryId: categoryId,
        name: enteredName,
      );

      final fresh = await DatabaseHelper.instance.getCategoryById(categoryId);

      if (fresh != null) {
        widget.category.addAll(fresh);
      }

      await _load();
      await widget.onChanged();
    } catch (e) {
      widget.onError(e);
    }
  }

  Future<void> _deleteCategory() async {
    final isDefault = (widget.category['is_default'] as num?)?.toInt() == 1;

    if (isDefault) {
      widget.onError(StateError('Default categories cannot be deleted.'));
      return;
    }

    final tx = await DatabaseHelper.instance.getAllTransactions(
      categoryId: categoryId,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          tx.isEmpty ? 'Delete this custom category?' : 'This will permanently delete this category, its sub-expenses, and all expense records inside it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await DatabaseHelper.instance.deleteCustomCategoryWithTransactions(
        categoryId,
      );

      if (mounted) Navigator.pop(context);

      await widget.onChanged();
    } catch (e) {
      widget.onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spent = subs.fold<double>(0, (sum, s) => sum + _n(s['spent']));

    final remaining = budget - spent;

    final isDefault = (widget.category['is_default'] as num?)?.toInt() == 1;

    return Container(
      height: MediaQuery.of(context).size.height * .82,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category['name'].toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Allocated ${budget.toStringAsFixed(0)} • Spent ${spent.toStringAsFixed(0)} • Remaining ${remaining < 0 ? 0 : remaining.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (manageMode)
                      IconButton(
                        onPressed: () => setState(() {
                          manageMode = false;
                          selected.clear();
                        }),
                        icon: const Icon(Icons.close_rounded),
                      )
                    else
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _editCategory();
                          if (v == 'manage') _manageExpenses();
                          if (v == 'delete') _deleteCategory();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 19,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 10),
                                Text('Edit Category'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'manage',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 19,
                                  color: AppColors.accent,
                                ),
                                SizedBox(width: 10),
                                Text('Manage Expenses'),
                              ],
                            ),
                          ),
                          if (!isDefault)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                    color: AppColors.danger,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Delete Category'),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (manageMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          '${selected.length} selected',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: selected.isEmpty ? null : _deleteSelected,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                          child: const Text('Delete Selected'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: subs.isEmpty
                      ? const Center(child: Text('No sub-expenses yet.'))
                      : ListView.builder(
                          itemCount: subs.length,
                          itemBuilder: (_, index) {
                            final s = subs[index];
                            final id = _i(s['id'])!;
                            final value = _n(s['spent']);
                            // final isOverspent = s['_is_overspent'] == true;
                            final isOverspent =
                                (s['is_overspent'] as num?)?.toInt() == 1;

                            final expenseColor = isOverspent
                                ? AppColors.danger
                                : AppColors.textPrimary;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                children: [
                                  if (manageMode)
                                    Checkbox(
                                      value: selected.contains(id),
                                      onChanged: (_) => setState(() {
                                        selected.contains(id)
                                            ? selected.remove(id)
                                            : selected.add(id);
                                      }),
                                      activeColor: AppColors.primary,
                                      visualDensity: VisualDensity.compact,
                                    )
                                  else
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          .08,
                                        ),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        color: AppColors.primary,
                                        size: 19,
                                      ),
                                    ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: InkWell(
                                      onTap: manageMode
                                          ? null
                                          : () => _editSub(s),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s['name'].toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (isOverspent)
                                            Text(
                                              'Overspent',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.danger,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${value.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: expenseColor,
                                    ),
                                  ),
                                  if (!manageMode)
                                    PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') {
                                          _editSub(s);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: manageMode ? null : _addExpense,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Expense'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _WalletCoinPainter extends CustomPainter {
  const _WalletCoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadow = Paint()..color = Colors.black.withOpacity(.10);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .16, h * .38, w * .64, h * .39),
        Radius.circular(w * .1),
      ),
      shadow,
    );

    final wallet = Paint()..color = const Color(0xFF3E7CB1);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .13, h * .32, w * .68, h * .42),
        Radius.circular(w * .1),
      ),
      wallet,
    );

    final p = Path()
      ..moveTo(w * .13, h * .43)
      ..lineTo(w * .13, h * .29)
      ..quadraticBezierTo(w * .13, h * .21, w * .23, h * .21)
      ..lineTo(w * .68, h * .21)
      ..quadraticBezierTo(w * .78, h * .21, w * .81, h * .31)
      ..lineTo(w * .81, h * .42)
      ..close();

    canvas.drawPath(p, Paint()..color = const Color(0xFF4B8CC1));

    canvas.drawLine(
      Offset(w * .19, h * .48),
      Offset(w * .72, h * .48),
      Paint()
        ..color = Colors.white.withOpacity(.25)
        ..strokeWidth = 1.4,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .60, h * .48, w * .20, h * .13),
        Radius.circular(w * .035),
      ),
      Paint()..color = const Color(0xFF2E6696),
    );

    canvas.drawCircle(
      Offset(w * .69, h * .25),
      w * .18,
      Paint()..color = Colors.black.withOpacity(.13),
    );

    canvas.drawCircle(
      Offset(w * .67, h * .23),
      w * .17,
      Paint()..color = const Color(0xFFF5A623),
    );

    canvas.drawCircle(
      Offset(w * .64, h * .20),
      w * .11,
      Paint()..color = const Color(0xFFFFC85A),
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'Rs',
        style: TextStyle(
          color: Color(0xFF9A6410),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(w * .67 - tp.width / 2, h * .23 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
