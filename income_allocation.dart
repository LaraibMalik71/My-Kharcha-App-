//Locked changes
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'database/database_helper.dart';
import 'home_screen.dart';

// ============================================================================
// CATEGORY MODEL
// ============================================================================

class CategoryItem {
  final int id;
  final String name;
  final IconData icon;
  final bool isDefault;

  bool isSelected;
  final TextEditingController amountController;

  CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.isDefault,
    this.isSelected = false,
  }) : amountController = TextEditingController();
}

// ============================================================================
// INCOME ALLOCATION SCREEN
// ============================================================================

class IncomeAllocationScreen extends StatefulWidget {
  const IncomeAllocationScreen({super.key});

  @override
  State<IncomeAllocationScreen> createState() => _IncomeAllocationScreenState();
}

class _IncomeAllocationScreenState extends State<IncomeAllocationScreen> {
  final _incomeController = TextEditingController();

  double? _totalIncome;
  String? _incomeError;

  String? _allocationMode;

  bool _isSaving = false;
  bool _isLoadingCategories = true;

  List<CategoryItem> _categories = [];

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // ==========================================================================
  // LOAD CATEGORIES FROM SQLITE
  // ==========================================================================

  Future<void> _loadCategories() async {
    try {
      final rows = await DatabaseHelper.instance.getAllCategories();

      final loadedCategories = rows.map((row) {
        return CategoryItem(
          id: row['id'] as int,
          name: row['name'] as String,
          icon: _iconFromDatabase(row['icon'] as String?),
          isDefault: (row['is_default'] as int? ?? 0) == 1,
        );
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = loadedCategories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCategories = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load categories.\n$e')));
    }
  }

  // ==========================================================================
  // DATABASE ICON → FLUTTER ICON
  // ==========================================================================

  IconData _iconFromDatabase(String? icon) {
    switch (icon) {
      case 'bolt':
        return Icons.bolt_rounded;

      case 'school':
        return Icons.school_rounded;

      case 'home':
        return Icons.home_rounded;

      case 'credit_card':
        return Icons.credit_card_rounded;

      case 'shopping_basket':
        return Icons.shopping_basket_rounded;

      case 'savings':
        return Icons.savings_rounded;

      case 'travel':
        return Icons.flight_takeoff_rounded;

      case 'food':
        return Icons.restaurant_rounded;

      case 'shopping':
        return Icons.shopping_bag_rounded;

      case 'medical':
        return Icons.medical_services_rounded;

      case 'education':
        return Icons.menu_book_rounded;

      case 'entertainment':
        return Icons.movie_rounded;

      case 'fitness':
        return Icons.fitness_center_rounded;

      case 'car':
        return Icons.directions_car_rounded;

      case 'internet':
        return Icons.wifi_rounded;

      case 'insurance':
        return Icons.security_rounded;

      case 'business':
        return Icons.business_center_rounded;

      case 'category':
      default:
        return Icons.category_rounded;
    }
  }

  // ==========================================================================
  // CALCULATIONS
  // ==========================================================================

  List<CategoryItem> get _selectedCategories {
    return _categories.where((category) => category.isSelected).toList();
  }

  double get _manualAllocated {
    double total = 0;

    for (final category in _selectedCategories) {
      final amount =
          double.tryParse(category.amountController.text.trim()) ?? 0;

      total += amount;
    }

    return total;
  }

  double get _equalShare {
    if (_totalIncome == null || _selectedCategories.isEmpty) {
      return 0;
    }

    return _totalIncome! / _selectedCategories.length;
  }

  double get _allocatedAmount {
    if (_allocationMode == 'equal') {
      if (_selectedCategories.isEmpty) {
        return 0;
      }

      return _totalIncome ?? 0;
    }

    return _manualAllocated;
  }

  double get _unallocatedAmount {
    if (_totalIncome == null) {
      return 0;
    }

    final remaining = _totalIncome! - _allocatedAmount;

    return remaining < 0 ? 0 : remaining;
  }

  bool get _isOverAllocated {
    if (_totalIncome == null) {
      return false;
    }

    return _manualAllocated > _totalIncome!;
  }

  bool get _hasInvalidManualAmount {
    if (_allocationMode != 'manual') {
      return false;
    }

    for (final category in _selectedCategories) {
      final amount = double.tryParse(category.amountController.text.trim());

      if (amount == null || amount <= 0) {
        return true;
      }
    }

    return false;
  }

  bool get _hasSelectedCategory {
    return _selectedCategories.isNotEmpty;
  }

  bool get _canContinue {
    if (_isLoadingCategories) {
      return false;
    }

    if (_totalIncome == null || _totalIncome! <= 0) {
      return false;
    }

    if (_allocationMode == null) {
      return false;
    }

    if (!_hasSelectedCategory) {
      return false;
    }

    if (_allocationMode == 'manual') {
      if (_hasInvalidManualAmount) {
        return false;
      }

      if (_isOverAllocated) {
        return false;
      }
    }

    return true;
  }

  // ==========================================================================
  // INCOME
  // ==========================================================================

  void _onIncomeChanged(String value) {
    final trimmed = value.trim();

    setState(() {
      if (trimmed.isEmpty) {
        _totalIncome = null;
        _incomeError = null;
      } else {
        final amount = double.tryParse(trimmed);

        if (amount == null) {
          _totalIncome = null;
          _incomeError = 'Enter a valid amount';
        } else if (amount <= 0) {
          _totalIncome = null;
          _incomeError = 'Income must be greater than zero';
        } else {
          _totalIncome = amount;
          _incomeError = null;
        }
      }
    });
  }

  // ==========================================================================
  // ALLOCATION MODE
  // ==========================================================================

  void _selectMode(String mode) {
    setState(() {
      _allocationMode = mode;

      if (mode == 'equal') {
        for (final category in _categories) {
          category.amountController.clear();
        }
      }
    });
  }

  // ==========================================================================
  // CATEGORY SELECTION
  // ==========================================================================

  void _toggleCategory(CategoryItem category) {
    setState(() {
      category.isSelected = !category.isSelected;

      if (!category.isSelected) {
        category.amountController.clear();
      }
    });
  }

  // ==========================================================================
  // ADD CUSTOM CATEGORY
  // ==========================================================================

  Future<void> _showAddCustomCategoryDialog() async {
    final controller = TextEditingController();
    String? errorText;
    bool isAdding = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isAdding,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> addCategory() async {
              final name = controller.text.trim();

              if (name.length < 2) {
                setDialogState(() {
                  errorText = 'Category name must be at least 2 characters.';
                });
                return;
              }

              setDialogState(() {
                isAdding = true;
                errorText = null;
              });

              try {
                final database = DatabaseHelper.instance;

                final categoryId = await database.insertCustomCategory(
                  name: name,
                );

                final category = await database.getCategoryById(categoryId);

                if (category == null) {
                  throw StateError(
                    'The new category could not be loaded from SQLite.',
                  );
                }

                final newCategory = CategoryItem(
                  id: category['id'] as int,
                  name: category['name'] as String,
                  icon: _iconFromDatabase(category['icon'] as String?),
                  isDefault: false,
                  isSelected: true,
                );

                if (!mounted) {
                  return;
                }

                setState(() {
                  _categories.add(newCategory);
                });

                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"$name" was added successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                setDialogState(() {
                  isAdding = false;

                  if (e is ArgumentError) {
                    errorText = e.message?.toString();
                  } else {
                    errorText = 'Unable to add this category.';
                  }
                });
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Add Custom Category',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create your own category and allocate money to it just like the default categories.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 30,
                    enabled: !isAdding,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Travel',
                      errorText: errorText,
                      prefixIcon: const Icon(
                        Icons.category_rounded,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!isAdding) {
                        addCategory();
                      }
                    },
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                TextButton(
                  onPressed: isAdding
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isAdding ? null : addCategory,
                  child: isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add Category'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  // ==========================================================================
  // BUILD ALLOCATIONS
  // ==========================================================================

  Map<int, double> _buildAllocations() {
    final Map<int, double> allocations = {};

    if (_allocationMode == 'equal') {
      _buildEqualAllocations(allocations);
    } else {
      for (final category in _selectedCategories) {
        final amount =
            double.tryParse(category.amountController.text.trim()) ?? 0;

        allocations[category.id] = amount;
      }
    }

    return allocations;
  }

  // ==========================================================================
  // EQUAL ALLOCATION WITH ROUNDING
  // ==========================================================================

  void _buildEqualAllocations(Map<int, double> result) {
    if (_totalIncome == null || _selectedCategories.isEmpty) {
      return;
    }

    final count = _selectedCategories.length;

    final totalInSmallestUnit = (_totalIncome! * 100).round();

    final baseShare = totalInSmallestUnit ~/ count;

    var remainder = totalInSmallestUnit % count;

    for (final category in _selectedCategories) {
      var share = baseShare;

      if (remainder > 0) {
        share++;
        remainder--;
      }

      result[category.id] = share / 100;
    }
  }

  // ==========================================================================
  // SAVE TO SQLITE
  // ==========================================================================

  Future<void> _handleContinue() async {
    if (!_canContinue) {
      if (_allocationMode == 'manual' && _hasInvalidManualAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter an amount greater than zero for every selected category.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final allocations = _buildAllocations();

      final saved = await DatabaseHelper.instance.saveAllocation(
        income: _totalIncome!,
        allocations: allocations,
      );

      if (!saved) {
        throw StateError('The allocation could not be saved to SQLite.');
      }

      // saveAllocation() now stores setup_step = "summary"
      // but DOES NOT mark setup as completed.
      //
      // Setup becomes completed only when the user presses
      // "Confirm & Continue" on AllocationSummaryScreen.

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AllocationSummaryScreen(
            totalIncome: _totalIncome!,
            allocations: allocations,
            categories: _selectedCategories,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save your budget.\n$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Handle back button
  void _handleBackButton(BuildContext context) {
    if (_isSaving) {
      return;
    }

    // Allocation state → return to Income Setup
    if (_allocationMode != null) {
      setState(() {
        _allocationMode = null;

        for (final category in _categories) {
          category.isSelected = false;
          category.amountController.clear();
        }
      });

      return;
    }

    // Income Setup is the first screen.
    // Close the Android activity.
    SystemNavigator.pop();
  }
  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _incomeController.dispose();

    for (final category in _categories) {
      category.amountController.dispose();
    }

    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: _isSaving ? null : () => _handleBackButton(context),
        ),
        title: const Text(
          'Budget Setup',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),

                  const SizedBox(height: 28),

                  _buildIncomeSection(),

                  if (_totalIncome != null) ...[
                    const SizedBox(height: 28),

                    _buildAllocationMethod(),

                    if (_allocationMode != null) ...[
                      const SizedBox(height: 28),

                      _buildCategorySection(),
                    ],

                    if (_allocationMode != null && _hasSelectedCategory) ...[
                      const SizedBox(height: 24),

                      _buildSummary(),
                    ],
                  ],

                  const SizedBox(height: 30),

                  _buildContinueButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Let’s set up your budget',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.15,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Tell us your monthly income and decide how you want to organize your money.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // INCOME
  // ==========================================================================

  Widget _buildIncomeSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Income',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Enter the total amount you receive each month.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),

          const SizedBox(height: 14),

          TextFormField(
            controller: _incomeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _onIncomeChanged,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              prefixText: 'Rs. ',
              prefixStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              hintText: '50,000',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.45),
                fontSize: 20,
              ),
              errorText: _incomeError,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ALLOCATION METHOD
  // ==========================================================================

  Widget _buildAllocationMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How do you want to allocate it?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Choose a method first, then select the categories.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),

        const SizedBox(height: 15),

        Row(
          children: [
            Expanded(
              child: _buildMethodCard(
                title: 'Equally Divide',
                subtitle: 'Split evenly',
                icon: Icons.pie_chart_rounded,
                mode: 'equal',
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildMethodCard(
                title: 'Set Manually',
                subtitle: 'Choose amounts',
                icon: Icons.tune_rounded,
                mode: 'manual',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String mode,
  }) {
    final selected = _allocationMode == mode;

    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.12),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : AppColors.primary,
                size: 22,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.72)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 21,
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // CATEGORY SECTION
  // ==========================================================================

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          _allocationMode == 'equal'
              ? 'Select the categories you want to divide your income between.'
              : 'Select categories and enter how much you want to allocate.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 15),

        if (_isLoadingCategories)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length + 1,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: _hasSelectedCategory ? 1.10 : 1.30,
            ),
            itemBuilder: (context, index) {
              if (index == _categories.length) {
                return _buildAddCustomCategoryCard();
              }

              return _buildCategoryCard(_categories[index]);
            },
          ),

        if (!_hasSelectedCategory) ...[
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.accent,
                  size: 19,
                ),

                SizedBox(width: 9),

                Expanded(
                  child: Text(
                    'Select at least one category to continue.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================================================
  // ADD CUSTOM CATEGORY CARD
  // ==========================================================================

  Widget _buildAddCustomCategoryCard() {
    return GestureDetector(
      onTap: _isSaving ? null : _showAddCustomCategoryDialog,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.accent,
                size: 25,
              ),
            ),

            const SizedBox(height: 9),

            const Text(
              'Add Custom',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 3),

            const Text(
              'Create your own',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // CATEGORY CARD
  // ==========================================================================

  Widget _buildCategoryCard(CategoryItem category) {
    final selected = category.isSelected;

    return GestureDetector(
      onTap: () => _toggleCategory(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.10),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.06 : 0.025),
              blurRadius: selected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    category.icon,
                    color: selected ? Colors.white : AppColors.primary,
                    size: 20,
                  ),
                ),

                const Spacer(),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          key: ValueKey('selected'),
                          color: AppColors.accent,
                          size: 21,
                        )
                      : const Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: ValueKey('unselected'),
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 4),

            if (selected && _allocationMode == 'equal')
              Text(
                'Rs. ${_equalShare.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              )
            else if (selected && _allocationMode == 'manual')
              _buildManualAmountField(category)
            else
              Text(
                'Tap to select',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary.withValues(alpha: 0.75),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // MANUAL AMOUNT
  // ==========================================================================

  Widget _buildManualAmountField(CategoryItem category) {
    return TextField(
      controller: category.amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        prefixText: 'Rs. ',
        prefixStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        hintText: 'Amount',
        hintStyle: TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary.withValues(alpha: 0.55),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ==========================================================================
  // SUMMARY ON SETUP SCREEN
  // ==========================================================================

  Widget _buildSummary() {
    final overAllocated = _isOverAllocated;
    final invalidManual = _hasInvalidManualAmount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: overAllocated || invalidManual
            ? AppColors.danger.withValues(alpha: 0.07)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: overAllocated || invalidManual
              ? AppColors.danger.withValues(alpha: 0.18)
              : AppColors.primary.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Allocation Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'Total Income',
                  _totalIncome ?? 0,
                  AppColors.primary,
                ),
              ),

              Expanded(
                child: _summaryItem(
                  'Allocated',
                  _allocatedAmount,
                  AppColors.accent,
                ),
              ),

              Expanded(
                child: _summaryItem(
                  'Unallocated',
                  _unallocatedAmount,
                  AppColors.success,
                ),
              ),
            ],
          ),

          if (invalidManual) ...[
            const SizedBox(height: 14),
            _warningBox(
              'Enter an amount greater than zero for every selected category.',
            ),
          ],

          if (overAllocated) ...[
            const SizedBox(height: 14),
            _warningBox(
              'You have over-allocated Rs. ${(_manualAllocated - _totalIncome!).toStringAsFixed(2)}. Reduce an allocation to continue.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _warningBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.danger,
        ),
      ),
    );
  }

  Widget _summaryItem(String title, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),

        const SizedBox(height: 5),

        Text(
          'Rs. ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // CONTINUE BUTTON
  // ==========================================================================

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_canContinue && !_isSaving) ? _handleContinue : null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.18),
          disabledForegroundColor: AppColors.textSecondary.withValues(
            alpha: 0.65,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isSaving
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 21,
                  width: 21,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : const Row(
                  key: ValueKey('continue'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    SizedBox(width: 8),

                    Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
        ),
      ),
    );
  }
}

// ============================================================================
// ALLOCATION SUMMARY SCREEN
// ============================================================================

class AllocationSummaryScreen extends StatelessWidget {
  final double totalIncome;
  final Map<int, double> allocations;
  final List<CategoryItem> categories;

  const AllocationSummaryScreen({
    super.key,
    required this.totalIncome,
    required this.allocations,
    required this.categories,
  });

  double get totalAllocated {
    return allocations.values.fold<double>(0, (sum, amount) => sum + amount);
  }

  double get unallocated {
    final value = totalIncome - totalAllocated;
    return value < 0 ? 0 : value;
  }

  // ==========================================================================
  // CONFIRM SETUP
  // ==========================================================================

  Future<void> _confirmAndContinue(BuildContext context) async {
    try {
      // IMPORTANT:
      // Setup completion is now stored in SQLite.
      //
      // This is the ONLY point where setup becomes completed.
      await DatabaseHelper.instance.completeSetup();

      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to complete setup.\n$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Allocation Summary',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),

                  const SizedBox(height: 24),

                  _buildTotals(),

                  const SizedBox(height: 24),

                  _buildCategoryList(),

                  const SizedBox(height: 28),

                  _buildConfirmButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 38),

          SizedBox(height: 12),

          Text(
            'Your budget is ready!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: 6),

          Text(
            'Review your allocations before opening your dashboard.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TOTALS
  // ==========================================================================

  Widget _buildTotals() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(child: _totalItem('Income', totalIncome, AppColors.primary)),

          Expanded(
            child: _totalItem('Allocated', totalAllocated, AppColors.accent),
          ),

          Expanded(
            child: _totalItem('Remaining', unallocated, AppColors.success),
          ),
        ],
      ),
    );
  }

  Widget _totalItem(String title, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),

        const SizedBox(height: 6),

        Text(
          'Rs. ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // CATEGORY LIST
  // ==========================================================================

  Widget _buildCategoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Allocations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        ...categories.map((category) {
          final amount = allocations[category.id] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.icon,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Text(
                  'Rs. ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================================
  // CONFIRM BUTTON
  // ==========================================================================

  Widget _buildConfirmButton() {
    return Builder(
      builder: (context) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _confirmAndContinue(context),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Confirm & Continue',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),

                SizedBox(width: 8),

                Icon(Icons.arrow_forward_rounded, size: 19),
              ],
            ),
          ),
        );
      },
    );
  }
}
