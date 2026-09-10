//chnggg2
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'dart:convert';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  static const String _databaseName = 'my_kharcha.db';
  static const int _databaseVersion = 8;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _open();
    return _database!;
  }

  // ---------------------------------------------------------------------------
  // DATABASE OPEN
  // ---------------------------------------------------------------------------

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      onOpen: (db) async {
        await _ensureSettings(db);
        await _ensureLegacyIncomeTransaction(db);
        await _createSetupProgressTable(db);
        await _seedDefaultCategories(db);
        await _seedDefaultSubCategories(db);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CREATE DATABASE
  // ---------------------------------------------------------------------------

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY CHECK(id = 1),
        currency TEXT NOT NULL DEFAULT 'PKR',
        total_income REAL NOT NULL DEFAULT 0,
        unallocated_balance REAL NOT NULL DEFAULT 0,
        current_month TEXT NOT NULL,
        budget_alert_80 INTEGER NOT NULL DEFAULT 1,
        budget_alert_90 INTEGER NOT NULL DEFAULT 1,
        budget_alert_100 INTEGER NOT NULL DEFAULT 1,
        income_alert_90 INTEGER NOT NULL DEFAULT 1,
        income_alert_100 INTEGER NOT NULL DEFAULT 1,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        dark_mode INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE monthly_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL UNIQUE,
        total_income REAL NOT NULL DEFAULT 0,
        allocated_amount REAL NOT NULL DEFAULT 0,
        unallocated_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active'
          CHECK(status IN ('active', 'closed', 'continued')),
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon TEXT NOT NULL,
        is_budgeted INTEGER NOT NULL DEFAULT 0,
        budget_amount REAL NOT NULL DEFAULT 0,
        spent_amount REAL NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sub_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(category_id, name),
        FOREIGN KEY(category_id)
          REFERENCES categories(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE monthly_category_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        budget_amount REAL NOT NULL DEFAULT 0,
        spent_amount REAL NOT NULL DEFAULT 0,
        UNIQUE(month_key, category_id),
        FOREIGN KEY(category_id)
          REFERENCES categories(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        sub_category_id INTEGER,
        amount REAL NOT NULL CHECK(amount > 0),
        type TEXT NOT NULL
          CHECK(type IN ('expense', 'income')),
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_overspent INTEGER NOT NULL DEFAULT 0,
        funding_source TEXT NOT NULL DEFAULT 'category'
          CHECK(
            funding_source IN (
              'category',
              'unallocated',
              'transfer',
              'overspent'
            )
          ),
        income_source TEXT,
        FOREIGN KEY(category_id)
          REFERENCES categories(id)
          ON DELETE SET NULL,
        FOREIGN KEY(sub_category_id)
          REFERENCES sub_categories(id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE monthly_subcategory_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL,
        sub_category_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        allocated_amount REAL NOT NULL DEFAULT 0,
        UNIQUE(month_key, sub_category_id),
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE,
        FOREIGN KEY(sub_category_id) REFERENCES sub_categories(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_category_id INTEGER,
        destination_category_id INTEGER NOT NULL,
        amount REAL NOT NULL CHECK(amount > 0),
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(source_category_id)
          REFERENCES categories(id)
          ON DELETE SET NULL,
        FOREIGN KEY(destination_category_id)
          REFERENCES categories(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL CHECK(target_amount > 0),
        current_amount REAL NOT NULL DEFAULT 0,
        deadline TEXT,
        status TEXT NOT NULL DEFAULT 'active'
          CHECK(status IN ('active', 'achieved', 'closed')),
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        transaction_id INTEGER,
        amount REAL NOT NULL CHECK(amount > 0),
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(goal_id)
          REFERENCES savings_goals(id)
          ON DELETE CASCADE,
        FOREIGN KEY(transaction_id)
          REFERENCES transactions(id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL CHECK(amount > 0),
        category_id INTEGER NOT NULL,
        sub_category_id INTEGER,
        due_date TEXT NOT NULL,
        reminder_days_before INTEGER NOT NULL DEFAULT 3,
        payment_status TEXT NOT NULL DEFAULT 'pending'
          CHECK(payment_status IN ('pending', 'paid', 'skipped')),
        last_paid_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY(category_id)
          REFERENCES categories(id)
          ON DELETE RESTRICT,
        FOREIGN KEY(sub_category_id)
          REFERENCES sub_categories(id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        related_id INTEGER,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE monthly_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL UNIQUE,
        total_income REAL NOT NULL DEFAULT 0,
        total_allocated REAL NOT NULL DEFAULT 0,
        total_spent REAL NOT NULL DEFAULT 0,
        total_unallocated REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await _ensureSettings(db);
    await _createSetupProgressTable(db);
    await _seedDefaultCategories(db);
    await _seedDefaultSubCategories(db);
  }

  // ---------------------------------------------------------------------------
  // DATABASE UPGRADE
  // ---------------------------------------------------------------------------

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Existing version 4 databases need the new tables.
    if (oldVersion < 5) {
      await _createMissingTables(db);
    }

    if (oldVersion < 6) {
      await _addMissingColumns(db);
    }

    if (oldVersion < 7) {
      await _createSetupProgressTable(db);
    }

    if (oldVersion < 8) {
      await _tryAddColumn(db, 'transactions', 'income_source', 'TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monthly_subcategory_budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          month_key TEXT NOT NULL,
          sub_category_id INTEGER NOT NULL,
          category_id INTEGER NOT NULL,
          allocated_amount REAL NOT NULL DEFAULT 0,
          UNIQUE(month_key, sub_category_id),
          FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE,
          FOREIGN KEY(sub_category_id) REFERENCES sub_categories(id) ON DELETE CASCADE
        )
      ''');
    }

    await _ensureSettings(db);
    await _seedDefaultCategories(db);
    await _seedDefaultSubCategories(db);
  }

  Future<void> _createMissingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL UNIQUE,
        total_income REAL NOT NULL DEFAULT 0,
        allocated_amount REAL NOT NULL DEFAULT 0,
        unallocated_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sub_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(category_id, name),
        FOREIGN KEY(category_id)
          REFERENCES categories(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_category_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        budget_amount REAL NOT NULL DEFAULT 0,
        spent_amount REAL NOT NULL DEFAULT 0,
        UNIQUE(month_key, category_id),
        FOREIGN KEY(category_id)
          REFERENCES categories(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_subcategory_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL,
        sub_category_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        allocated_amount REAL NOT NULL DEFAULT 0,
        UNIQUE(month_key, sub_category_id),
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE,
        FOREIGN KEY(sub_category_id) REFERENCES sub_categories(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_category_id INTEGER,
        destination_category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(source_category_id)
          REFERENCES categories(id)
          ON DELETE SET NULL,
        FOREIGN KEY(destination_category_id)
          REFERENCES categories(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS savings_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        transaction_id INTEGER,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(goal_id)
          REFERENCES savings_goals(id)
          ON DELETE CASCADE,
        FOREIGN KEY(transaction_id)
          REFERENCES transactions(id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        related_id INTEGER,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL UNIQUE,
        total_income REAL NOT NULL DEFAULT 0,
        total_allocated REAL NOT NULL DEFAULT 0,
        total_spent REAL NOT NULL DEFAULT 0,
        total_unallocated REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _addMissingColumns(Database db) async {
    await _tryAddColumn(
      db,
      'categories',
      'is_active',
      'INTEGER NOT NULL DEFAULT 1',
    );

    await _tryAddColumn(db, 'transactions', 'sub_category_id', 'INTEGER');

    await _tryAddColumn(
      db,
      'transactions',
      'is_overspent',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await _tryAddColumn(
      db,
      'transactions',
      'funding_source',
      "TEXT NOT NULL DEFAULT 'category'",
    );
  }

  Future<void> _tryAddColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    } catch (_) {
      // Column already exists.
    }
  }

  // ---------------------------------------------------------------------------
  // SETUP PROGRESS
  // ---------------------------------------------------------------------------

  Future<void> _createSetupProgressTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS setup_progress (
        id INTEGER PRIMARY KEY CHECK(id = 1),
        is_completed INTEGER NOT NULL DEFAULT 0,
        current_step TEXT NOT NULL DEFAULT 'income',
        income REAL NOT NULL DEFAULT 0,
        allocation_mode TEXT,
        selected_category_ids TEXT NOT NULL DEFAULT '[]',
        manual_allocations TEXT NOT NULL DEFAULT '{}',
        updated_at TEXT NOT NULL
      )
    ''');

    final existing = await db.query(
      'setup_progress',
      where: 'id = 1',
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('setup_progress', {
        'id': 1,
        'is_completed': 0,
        'current_step': 'income',
        'income': 0,
        'allocation_mode': null,
        'selected_category_ids': '[]',
        'manual_allocations': '{}',
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<Map<String, dynamic>> getSetupProgress() async {
    final db = await database;
    await _createSetupProgressTable(db);

    final result = await db.query('setup_progress', where: 'id = 1', limit: 1);

    if (result.isEmpty) {
      return {
        'id': 1,
        'is_completed': 0,
        'current_step': 'income',
        'income': 0.0,
        'allocation_mode': null,
        'selected_category_ids': '[]',
        'manual_allocations': '{}',
        'updated_at': DateTime.now().toIso8601String(),
      };
    }

    return result.first;
  }

  Future<bool> isSetupCompleted() async {
    final progress = await getSetupProgress();
    return (progress['is_completed'] as int? ?? 0) == 1;
  }

  Future<void> saveSetupProgress({
    required String currentStep,
    double? income,
    String? allocationMode,
    List<int>? selectedCategoryIds,
    Map<int, double>? manualAllocations,
  }) async {
    final db = await database;
    await _createSetupProgressTable(db);

    final existing = await getSetupProgress();

    final currentIncome =
        income ?? (existing['income'] as num?)?.toDouble() ?? 0.0;

    final currentMode =
        allocationMode ?? existing['allocation_mode'] as String?;

    final decodedCategoryIds = jsonDecode(
      existing['selected_category_ids'] as String? ?? '[]',
    );

    final currentCategoryIds =
        selectedCategoryIds ??
        (decodedCategoryIds is List
            ? decodedCategoryIds.map((e) => (e as num).toInt()).toList()
            : <int>[]);

    final decodedManualAllocations = jsonDecode(
      existing['manual_allocations'] as String? ?? '{}',
    );

    final currentManualAllocations =
        manualAllocations ??
        (decodedManualAllocations is Map
            ? decodedManualAllocations.map(
                (key, value) => MapEntry(
                  int.parse(key.toString()),
                  (value as num).toDouble(),
                ),
              )
            : <int, double>{});

    await db.insert('setup_progress', {
      'id': 1,
      'is_completed': 0,
      'current_step': currentStep,
      'income': currentIncome,
      'allocation_mode': currentMode,
      'selected_category_ids': jsonEncode(currentCategoryIds),
      'manual_allocations': jsonEncode(
        currentManualAllocations.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      ),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markSetupCompleted() async {
    final db = await database;
    await _createSetupProgressTable(db);

    await db.update('setup_progress', {
      'is_completed': 1,
      'current_step': 'completed',
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = 1');
  }

  /// Completes the first-time budget setup after the user confirms the
  /// allocation summary. The allocation itself has already been persisted by
  /// [saveAllocation]; this method only advances the setup state.
  Future<void> completeSetup() async {
    await markSetupCompleted();
  }

  // ---------------------------------------------------------------------------
  // SETTINGS
  // ---------------------------------------------------------------------------

  Future<void> _ensureSettings(DatabaseExecutor db) async {
    final now = DateTime.now();

    await db.insert('app_settings', {
      'id': 1,
      'currency': 'PKR',
      'total_income': 0,
      'unallocated_balance': 0,
      'current_month': _monthKey(now),
      'budget_alert_80': 1,
      'budget_alert_90': 1,
      'budget_alert_100': 1,
      'income_alert_90': 1,
      'income_alert_100': 1,
      'notifications_enabled': 1,
      'dark_mode': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _ensureLegacyIncomeTransaction(DatabaseExecutor db) async {
    final settingsRows = await db.query(
      'app_settings',
      where: 'id = 1',
      limit: 1,
    );
    if (settingsRows.isEmpty) return;
    final configured =
        (settingsRows.first['total_income'] as num?)?.toDouble() ?? 0;
    if (configured <= 0) return;
    final month = _monthKey(DateTime.now());
    final incomeRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions WHERE type = 'income' AND substr(date, 1, 7) = ?
    ''',
      [month],
    );
    final existing = (incomeRows.first['total'] as num).toDouble();
    final difference = configured - existing;
    if (difference <= 0.01) return;
    await db.insert('transactions', {
      'category_id': null,
      'sub_category_id': null,
      'amount': difference,
      'type': 'income',
      'note': 'Initial income setup',
      'date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'is_overspent': 0,
      'funding_source': 'unallocated',
      'income_source': 'Setup',
    });
  }

  Future<Map<String, dynamic>> getAppSettings() async {
    final db = await database;
    await _ensureSettings(db);

    final rows = await db.query('app_settings', where: 'id = 1', limit: 1);

    return rows.first;
  }

  Future<double> getTotalIncome() async {
    final settings = await getAppSettings();

    return (settings['total_income'] as num).toDouble();
  }

  Future<double> getUnallocatedBalance() async {
    final settings = await getAppSettings();

    return (settings['unallocated_balance'] as num).toDouble();
  }

  Future<void> setUnallocatedBalance(double value) async {
    final db = await database;

    await db.update('app_settings', {
      'unallocated_balance': value < 0 ? 0 : value,
    }, where: 'id = 1');
  }

  // ---------------------------------------------------------------------------
  // DEFAULT CATEGORIES
  // ---------------------------------------------------------------------------

  static const List<Map<String, String>> _defaultCategories = [
    {'name': 'Bill', 'icon': 'bolt'},
    {'name': 'Fees', 'icon': 'school'},
    {'name': 'Rent', 'icon': 'home'},
    {'name': 'Installments', 'icon': 'credit_card'},
    {'name': 'Home Expenses', 'icon': 'shopping_basket'},
    {'name': 'Savings', 'icon': 'savings'},
  ];

  Future<void> _seedDefaultCategories(DatabaseExecutor db) async {
    // Clean up duplicates created by older versions BEFORE seeding.
    // A renamed default category is identified by its stable icon, not its
    // display name. This also removes old duplicate Bill/Savings rows.
    await _cleanupDuplicateDefaultCategories(db);

    final now = DateTime.now().toIso8601String();
    for (final category in _defaultCategories) {
      final existing = await db.query(
        'categories',
        where: 'is_default=1 AND is_active=1 AND icon=?',
        whereArgs: [category['icon']],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;

      await db.insert('categories', {
        'name': category['name'],
        'icon': category['icon'],
        'is_default': 1,
        'is_active': 1,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _cleanupDuplicateDefaultCategories(DatabaseExecutor db) async {
    for (final definition in _defaultCategories) {
      final rows = await db.query(
        'categories',
        where: 'is_default=1 AND is_active=1 AND icon=?',
        whereArgs: [definition['icon']],
        orderBy: 'id ASC',
      );
      if (rows.length <= 1) continue;

      // Keep the row that contains the user's real data. If several rows have
      // data, keep the oldest one and merge the others into it.
      int keeperId = rows.first['id'] as int;
      var bestScore = -1.0;
      for (final row in rows) {
        final id = row['id'] as int;
        final tx =
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM transactions WHERE category_id=?',
                [id],
              ),
            ) ??
            0;
        final monthly = await db.rawQuery(
          'SELECT COALESCE(SUM(budget_amount),0) AS total FROM monthly_category_budgets WHERE category_id=?',
          [id],
        );
        final budget = (row['budget_amount'] as num?)?.toDouble() ?? 0;
        final monthlyBudget = (monthly.first['total'] as num?)?.toDouble() ?? 0;
        final score = tx * 1000000.0 + budget.abs() + monthlyBudget.abs();
        if (score > bestScore) {
          bestScore = score;
          keeperId = id;
        }
      }

      for (final row in rows) {
        final duplicateId = row['id'] as int;
        if (duplicateId == keeperId) continue;

        // Move all expense/income records to the keeper category.
        await db.update(
          'transactions',
          {'category_id': keeperId},
          where: 'category_id=?',
          whereArgs: [duplicateId],
        );

        // Merge monthly category budgets without violating the unique
        // (month_key, category_id) constraint.
        final monthlyRows = await db.query(
          'monthly_category_budgets',
          where: 'category_id=?',
          whereArgs: [duplicateId],
        );
        for (final m in monthlyRows) {
          final monthKey = m['month_key'].toString();
          final existing = await db.query(
            'monthly_category_budgets',
            where: 'month_key=? AND category_id=?',
            whereArgs: [monthKey, keeperId],
            limit: 1,
          );
          final oldBudget = (m['budget_amount'] as num?)?.toDouble() ?? 0;
          final oldSpent = (m['spent_amount'] as num?)?.toDouble() ?? 0;
          if (existing.isEmpty) {
            await db.update(
              'monthly_category_budgets',
              {'category_id': keeperId},
              where: 'id=?',
              whereArgs: [m['id']],
            );
          } else {
            final e = existing.first;
            final newBudget =
                ((e['budget_amount'] as num?)?.toDouble() ?? 0) + oldBudget;
            final newSpent =
                ((e['spent_amount'] as num?)?.toDouble() ?? 0) + oldSpent;
            await db.update(
              'monthly_category_budgets',
              {'budget_amount': newBudget, 'spent_amount': newSpent},
              where: 'id=?',
              whereArgs: [e['id']],
            );
            await db.delete(
              'monthly_category_budgets',
              where: 'id=?',
              whereArgs: [m['id']],
            );
          }
        }

        // Merge sub-expenses with the same name; otherwise move them to the
        // keeper category. Their transaction links are preserved.
        final duplicateSubs = await db.query(
          'sub_categories',
          where: 'category_id=?',
          whereArgs: [duplicateId],
        );
        for (final sub in duplicateSubs) {
          final subId = sub['id'] as int;
          final subName = sub['name'].toString();
          final same = await db.query(
            'sub_categories',
            where: 'category_id=? AND name=? COLLATE NOCASE',
            whereArgs: [keeperId, subName],
            limit: 1,
          );
          if (same.isEmpty) {
            await db.update(
              'sub_categories',
              {'category_id': keeperId},
              where: 'id=?',
              whereArgs: [subId],
            );
            await db.update(
              'monthly_subcategory_budgets',
              {'category_id': keeperId},
              where: 'sub_category_id=?',
              whereArgs: [subId],
            );
          } else {
            final keeperSubId = same.first['id'] as int;
            await db.update(
              'transactions',
              {'sub_category_id': keeperSubId},
              where: 'sub_category_id=?',
              whereArgs: [subId],
            );
            final subBudgets = await db.query(
              'monthly_subcategory_budgets',
              where: 'sub_category_id=?',
              whereArgs: [subId],
            );
            for (final b in subBudgets) {
              final monthKey = b['month_key'].toString();
              final existingBudget = await db.query(
                'monthly_subcategory_budgets',
                where: 'month_key=? AND sub_category_id=?',
                whereArgs: [monthKey, keeperSubId],
                limit: 1,
              );
              if (existingBudget.isEmpty) {
                await db.update(
                  'monthly_subcategory_budgets',
                  {'sub_category_id': keeperSubId},
                  where: 'id=?',
                  whereArgs: [b['id']],
                );
              } else {
                final e = existingBudget.first;
                await db.update(
                  'monthly_subcategory_budgets',
                  {
                    'allocated_amount':
                        ((e['allocated_amount'] as num?)?.toDouble() ?? 0) +
                        ((b['allocated_amount'] as num?)?.toDouble() ?? 0),
                  },
                  where: 'id=?',
                  whereArgs: [e['id']],
                );
                await db.delete(
                  'monthly_subcategory_budgets',
                  where: 'id=?',
                  whereArgs: [b['id']],
                );
              }
            }
            await db.delete(
              'sub_categories',
              where: 'id=?',
              whereArgs: [subId],
            );
          }
        }

        await db.delete(
          'monthly_subcategory_budgets',
          where: 'category_id=?',
          whereArgs: [duplicateId],
        );
        await db.update(
          'categories',
          {'is_active': 0},
          where: 'id=?',
          whereArgs: [duplicateId],
        );
      }

      final spentRows = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) AS total FROM transactions WHERE type='expense' AND category_id=?",
        [keeperId],
      );
      final keeperSpent = (spentRows.first['total'] as num?)?.toDouble() ?? 0;
      await db.update(
        'categories',
        {'spent_amount': keeperSpent},
        where: 'id=?',
        whereArgs: [keeperId],
      );
    }
  }

  Future<void> insertDefaultCategories() async {
    final db = await database;

    await _seedDefaultCategories(db);
    await _seedDefaultSubCategories(db);
  }

  // ---------------------------------------------------------------------------
  // DEFAULT SUB-CATEGORIES
  // ---------------------------------------------------------------------------

  static const Map<String, List<String>> _defaultSubCategories = {
    'Bill': ['Electricity', 'Water', 'Gas'],
    'Fees': ['School Fee', 'Tuition', 'Other Fees'],
    'Rent': ['House Rent'],
    'Installments': ['Loan', 'EMI'],
    'Home Expenses': ['Groceries', 'Cleaning', 'Household'],
    'Savings': ['General Savings'],
  };

  Future<void> _seedDefaultSubCategories(DatabaseExecutor db) async {
    final categories = await db.query('categories', columns: ['id', 'name']);

    final now = DateTime.now().toIso8601String();

    for (final category in categories) {
      final categoryId = category['id'] as int;
      final categoryName = category['name'] as String;

      final subCategories = _defaultSubCategories[categoryName] ?? [];

      for (final name in subCategories) {
        await db.insert('sub_categories', {
          'category_id': categoryId,
          'name': name,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CATEGORY METHODS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;

    return db.query(
      'categories',
      where: 'is_active = 1',
      orderBy: 'is_default DESC, id ASC',
    );
  }

  Future<Map<String, dynamic>?> getCategoryById(int id) async {
    return _first('categories', 'id = ?', [id]);
  }

  Future<Map<String, dynamic>?> getCategoryByName(String name) async {
    return _first('categories', 'name = ? COLLATE NOCASE AND is_active = 1', [
      name.trim(),
    ]);
  }

  Future<Map<String, dynamic>?> _first(
    String table,
    String where,
    List<Object?> args,
  ) async {
    final db = await database;

    final rows = await db.query(table, where: where, whereArgs: args, limit: 1);

    return rows.isEmpty ? null : rows.first;
  }

  // ---------------------------------------------------------------------------
  // AUTOMATIC CATEGORY ICON
  // ---------------------------------------------------------------------------

  String getAutomaticCategoryIcon(String name) {
    final value = name.toLowerCase().trim();

    if (_containsAny(value, [
      'travel',
      'trip',
      'tour',
      'flight',
      'air',
      'vacation',
    ])) {
      return 'travel';
    }

    if (_containsAny(value, [
      'food',
      'restaurant',
      'dining',
      'lunch',
      'dinner',
      'breakfast',
      'grocery',
    ])) {
      return 'food';
    }

    if (_containsAny(value, [
      'shopping',
      'clothes',
      'fashion',
      'market',
      'store',
    ])) {
      return 'shopping';
    }

    if (_containsAny(value, [
      'medical',
      'medicine',
      'doctor',
      'hospital',
      'health',
      'pharmacy',
    ])) {
      return 'medical';
    }

    if (_containsAny(value, [
      'education',
      'school',
      'college',
      'university',
      'course',
      'study',
    ])) {
      return 'education';
    }

    if (_containsAny(value, [
      'entertainment',
      'movie',
      'cinema',
      'game',
      'fun',
    ])) {
      return 'entertainment';
    }

    if (_containsAny(value, ['fitness', 'gym', 'sport', 'workout'])) {
      return 'fitness';
    }

    if (_containsAny(value, [
      'car',
      'vehicle',
      'transport',
      'taxi',
      'fuel',
      'petrol',
    ])) {
      return 'car';
    }

    if (_containsAny(value, ['internet', 'wifi', 'mobile', 'phone', 'data'])) {
      return 'internet';
    }

    if (_containsAny(value, ['insurance', 'security', 'protection'])) {
      return 'insurance';
    }

    if (_containsAny(value, ['business', 'work', 'office', 'freelance'])) {
      return 'business';
    }

    if (_containsAny(value, ['home', 'house', 'furniture', 'repair'])) {
      return 'home';
    }

    return 'category';
  }

  bool _containsAny(String value, List<String> words) {
    return words.any(value.contains);
  }

  Future<int> insertCustomCategory({required String name}) async {
    final trimmed = name.trim();

    if (trimmed.length < 2) {
      throw ArgumentError('Category name must contain at least 2 characters.');
    }

    final icon = getAutomaticCategoryIcon(trimmed);
    final db = await database;

    try {
      return await db.transaction((txn) async {
        final activeDuplicate = await txn.query(
          'categories',
          where: 'name = ? COLLATE NOCASE AND is_active = 1',
          whereArgs: [trimmed],
          limit: 1,
        );

        if (activeDuplicate.isNotEmpty) {
          throw ArgumentError('A category with this name already exists.');
        }

        // Permanently remove old inactive/ghost rows with the same name.
        // This is important because categories.name is UNIQUE, so an old
        // inactive row would otherwise block a fresh category with the same
        // name from being inserted.
        final inactiveDuplicates = await txn.query(
          'categories',
          where: 'name = ? COLLATE NOCASE AND is_active = 0 AND is_default = 0',
          whereArgs: [trimmed],
        );

        for (final ghost in inactiveDuplicates) {
          final ghostId = ghost['id'] as int;
          final ghostTransactions = await txn.query(
            'transactions',
            where: 'category_id = ?',
            whereArgs: [ghostId],
          );

          final months = <String>{getCurrentMonthKey()};
          for (final row in ghostTransactions) {
            final d =
                DateTime.tryParse(row['date']?.toString() ?? '') ??
                DateTime.now();
            months.add(_monthKey(d));
            if (row['type'] == 'expense') {
              await _reverseExpense(txn, row);
            }
            await txn.delete(
              'transactions',
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }

          await txn.delete(
            'monthly_subcategory_budgets',
            where: 'category_id = ?',
            whereArgs: [ghostId],
          );
          await txn.delete(
            'monthly_category_budgets',
            where: 'category_id = ?',
            whereArgs: [ghostId],
          );
          await txn.delete(
            'transfers',
            where: 'source_category_id = ? OR destination_category_id = ?',
            whereArgs: [ghostId, ghostId],
          );
          await txn.delete(
            'recurring_items',
            where: 'category_id = ?',
            whereArgs: [ghostId],
          );
          await txn.delete(
            'sub_categories',
            where: 'category_id = ?',
            whereArgs: [ghostId],
          );
          await txn.delete('categories', where: 'id = ?', whereArgs: [ghostId]);

          for (final month in months) {
            await _refreshMonth(txn, month);
          }
        }

        final id = await txn.insert('categories', {
          'name': trimmed,
          'icon': icon,
          'is_budgeted': 0,
          'budget_amount': 0.0,
          'spent_amount': 0.0,
          'is_default': 0,
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
        });

        await txn.insert('sub_categories', {
          'category_id': id,
          'name': 'General',
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        return id;
      });
    } on DatabaseException catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('unique') || message.contains('constraint')) {
        throw ArgumentError('A category with this name already exists.');
      }
      throw Exception('Unable to create category. Please try again.');
    }
  }

  Future<bool> deleteCategory(int categoryId) async {
    final db = await database;

    return db.transaction((txn) async {
      final categoryRows = await txn.query(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );

      if (categoryRows.isEmpty) {
        return false;
      }

      final category = categoryRows.first;

      if (category['is_default'] == 1) {
        return false;
      }

      final transactionCount =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              '''
              SELECT COUNT(*)
              FROM transactions
              WHERE category_id = ?
              ''',
              [categoryId],
            ),
          ) ??
          0;

      if (transactionCount > 0) {
        return false;
      }

      // Permanently delete the category and all records that would otherwise
      // keep the category alive because of foreign-key restrictions.
      await txn.delete(
        'monthly_subcategory_budgets',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
      await txn.delete(
        'monthly_category_budgets',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
      await txn.delete(
        'transfers',
        where: 'source_category_id = ? OR destination_category_id = ?',
        whereArgs: [categoryId, categoryId],
      );
      await txn.delete(
        'recurring_items',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
      await txn.delete(
        'sub_categories',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );

      final result = await txn.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
      );

      return result == 1;
    });
  }

  // ---------------------------------------------------------------------------
  // SUB-CATEGORY METHODS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getSubCategories(int categoryId) async {
    final db = await database;

    return db.query(
      'sub_categories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'id ASC',
    );
  }

  Future<int> insertSubCategory({
    required int categoryId,
    required String name,
  }) async {
    final trimmed = name.trim();

    if (trimmed.length < 2) {
      throw ArgumentError('Sub-expense name is too short.');
    }

    final db = await database;

    return db.insert('sub_categories', {
      'category_id': categoryId,
      'name': trimmed,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<bool> deleteSubCategory(int subCategoryId) async {
    final db = await database;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM transactions WHERE sub_category_id = ?',
            [subCategoryId],
          ),
        ) ??
        0;
    if (count > 0) return false;
    final result = await db.delete(
      'sub_categories',
      where: 'id = ?',
      whereArgs: [subCategoryId],
    );
    return result == 1;
  }

  // ---------------------------------------------------------------------------
  // MONTH HELPERS
  // ---------------------------------------------------------------------------

  String _monthKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}';
  }

  String getCurrentMonthKey() {
    return _monthKey(DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // INCOME + ALLOCATION
  // ---------------------------------------------------------------------------

  Future<bool> saveAllocation({
    required double income,
    required Map<int, double> allocations,
  }) async {
    if (income <= 0) {
      return false;
    }

    if (allocations.values.any((value) => value < 0)) {
      return false;
    }

    final allocated = allocations.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    if (allocated > income + 0.01) {
      return false;
    }

    final unallocated = income - allocated;

    final db = await database;
    final monthKey = getCurrentMonthKey();
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final categoryIds = (await txn.query(
        'categories',
        columns: ['id'],
        where: 'is_active = 1',
      )).map((row) => row['id'] as int).toSet();

      if (!allocations.keys.every(categoryIds.contains)) {
        return false;
      }

      await txn.update('app_settings', {
        'total_income': income,
        'unallocated_balance': unallocated,
        'current_month': monthKey,
      }, where: 'id = 1');

      // The income entered during the first-time allocation setup is also kept
      // as a real income transaction so Dashboard totals always have one source
      // of truth: the transactions table.
      await txn.delete(
        'transactions',
        where: "type = 'income' AND income_source = 'Setup' AND substr(date, 1, 7) = ?",
        whereArgs: [monthKey],
      );
      await txn.insert('transactions', {
        'category_id': null,
        'sub_category_id': null,
        'amount': income,
        'type': 'income',
        'note': 'Initial income setup',
        'date': now,
        'created_at': now,
        'is_overspent': 0,
        'funding_source': 'unallocated',
        'income_source': 'Setup',
      });

      await txn.insert('monthly_budgets', {
        'month_key': monthKey,
        'total_income': income,
        'allocated_amount': allocated,
        'unallocated_amount': unallocated,
        'status': 'active',
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.update('categories', {'is_budgeted': 0, 'budget_amount': 0});

      await txn.delete(
        'monthly_category_budgets',
        where: 'month_key = ?',
        whereArgs: [monthKey],
      );

      await txn.delete(
        'monthly_subcategory_budgets',
        where: 'month_key = ?',
        whereArgs: [monthKey],
      );

      for (final entry in allocations.entries) {
        if (entry.value <= 0) {
          continue;
        }

        await txn.update(
          'categories',
          {'is_budgeted': 1, 'budget_amount': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );

        await txn.insert('monthly_category_budgets', {
          'month_key': monthKey,
          'category_id': entry.key,
          'budget_amount': entry.value,
          'spent_amount': 0,
        });
      }

      return true;
    });
  }

  Future<void> setMonthlyIncome(double income) async {
    if (income <= 0) {
      throw ArgumentError.value(income, 'income');
    }

    await saveAllocation(income: income, allocations: {});
  }

  Future<bool> allocateToCategory({
    required int categoryId,
    required double amount,
  }) async {
    if (amount <= 0) {
      return false;
    }

    final db = await database;
    final monthKey = getCurrentMonthKey();

    return db.transaction((txn) async {
      final settings = await txn.query(
        'app_settings',
        where: 'id = 1',
        limit: 1,
      );

      if (settings.isEmpty) {
        return false;
      }

      final available = (settings.first['unallocated_balance'] as num)
          .toDouble();

      if (amount > available + 0.01) {
        return false;
      }

      final updated = await txn.rawUpdate(
        '''
          UPDATE categories
          SET is_budgeted = 1,
              budget_amount = budget_amount + ?
          WHERE id = ?
            AND is_active = 1
          ''',
        [amount, categoryId],
      );

      if (updated != 1) {
        return false;
      }

      await txn.update('app_settings', {
        'unallocated_balance': available - amount,
      }, where: 'id = 1');

      final existing = await txn.query(
        'monthly_category_budgets',
        where: '''
            month_key = ?
            AND category_id = ?
          ''',
        whereArgs: [monthKey, categoryId],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('monthly_category_budgets', {
          'month_key': monthKey,
          'category_id': categoryId,
          'budget_amount': amount,
          'spent_amount': 0,
        });
      } else {
        await txn.rawUpdate(
          '''
            UPDATE monthly_category_budgets
            SET budget_amount =
              budget_amount + ?
            WHERE month_key = ?
              AND category_id = ?
            ''',
          [amount, monthKey, categoryId],
        );
      }

      await _updateMonthlyAllocationInsideTransaction(txn, monthKey);

      return true;
    });
  }

  Future<void> _updateMonthlyAllocationInsideTransaction(
    DatabaseExecutor txn,
    String monthKey,
  ) async {
    final budgetRows = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(budget_amount), 0) AS total
      FROM monthly_category_budgets
      WHERE month_key = ?
      ''',
      [monthKey],
    );

    final allocated = (budgetRows.first['total'] as num).toDouble();

    final settings = await txn.query('app_settings', where: 'id = 1', limit: 1);

    if (settings.isEmpty) {
      return;
    }

    final income = (settings.first['total_income'] as num).toDouble();

    await txn.update(
      'monthly_budgets',
      {
        'total_income': income,
        'allocated_amount': allocated,
        'unallocated_amount': (income - allocated).clamp(0, double.infinity),
      },
      where: 'month_key = ?',
      whereArgs: [monthKey],
    );
  }

  // ---------------------------------------------------------------------------
  // TRANSACTIONS / INCOME / EXPENSES
  // ---------------------------------------------------------------------------

  Future<double> _incomeForMonth(DatabaseExecutor db, String monthKey) async {
    final r = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total FROM transactions
      WHERE type = 'income' AND substr(date, 1, 7) = ?
    ''',
      [monthKey],
    );
    return (r.first['total'] as num).toDouble();
  }

  Future<double> _allocatedForMonth(
    DatabaseExecutor db,
    String monthKey,
  ) async {
    final r = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(budget_amount), 0) AS total
      FROM monthly_category_budgets WHERE month_key = ?
    ''',
      [monthKey],
    );
    return (r.first['total'] as num).toDouble();
  }

  Future<void> _refreshMonth(DatabaseExecutor db, String monthKey) async {
    final income = await _incomeForMonth(db, monthKey);
    final allocated = await _allocatedForMonth(db, monthKey);
    final unallocated = (income - allocated).clamp(0.0, double.infinity);
    await db.insert('monthly_budgets', {
      'month_key': monthKey,
      'total_income': income,
      'allocated_amount': allocated,
      'unallocated_amount': unallocated,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (monthKey == getCurrentMonthKey()) {
      await db.update('app_settings', {
        'total_income': income,
        'unallocated_balance': unallocated,
        'current_month': monthKey,
      }, where: 'id = 1');
    }
  }

  Future<int> addIncomeTransaction({
    required double amount,
    required String source,
    String? note,
    String? date,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be greater than zero.');
    final cleanSource = source.trim().isEmpty ? 'Other' : source.trim();
    final incomeDate = date ?? DateTime.now().toIso8601String();
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('transactions', {
        'category_id': null,
        'sub_category_id': null,
        'amount': amount,
        'type': 'income',
        'note': note,
        'date': incomeDate,
        'created_at': DateTime.now().toIso8601String(),
        'is_overspent': 0,
        'funding_source': 'unallocated',
        'income_source': cleanSource,
      });
      await _refreshMonth(
        txn,
        _monthKey(DateTime.tryParse(incomeDate) ?? DateTime.now()),
      );
      return id;
    });
  }

  Future<void> addIncome(double amount) async {
    await addIncomeTransaction(amount: amount, source: 'Other');
  }

  Future<bool> updateIncomeTransaction({
    required int id,
    required double newAmount,
    required String newSource,
    String? newNote,
    String? newDate,
  }) async {
    if (newAmount <= 0)
      throw ArgumentError('Amount must be greater than zero.');
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ? AND type = ?',
        whereArgs: [id, 'income'],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final old = rows.first;
      final oldAmount = (old['amount'] as num).toDouble();
      final oldDate =
          DateTime.tryParse(old['date']?.toString() ?? '') ?? DateTime.now();
      final targetDate =
          DateTime.tryParse(newDate ?? old['date']?.toString() ?? '') ??
          oldDate;
      final oldMonth = _monthKey(oldDate);
      final newMonth = _monthKey(targetDate);
      if (oldMonth == newMonth && oldMonth == getCurrentMonthKey()) {
        final allocated = await _allocatedForMonth(txn, oldMonth);
        final after =
            await _incomeForMonth(txn, oldMonth) - oldAmount + newAmount;
        if (after + 0.01 < allocated)
          throw StateError(
            'Income cannot be reduced below the amount already allocated.',
          );
      }
      if (oldMonth != newMonth && oldMonth == getCurrentMonthKey()) {
        final allocated = await _allocatedForMonth(txn, oldMonth);
        final after = await _incomeForMonth(txn, oldMonth) - oldAmount;
        if (after + 0.01 < allocated)
          throw StateError(
            'This income cannot be moved because current allocations depend on it.',
          );
      }
      await txn.update(
        'transactions',
        {
          'amount': newAmount,
          'income_source': newSource.trim().isEmpty
              ? 'Other'
              : newSource.trim(),
          'note': newNote,
          'date': targetDate.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _refreshMonth(txn, oldMonth);
      if (newMonth != oldMonth) await _refreshMonth(txn, newMonth);
      return true;
    });
  }

  Future<int> insertTransaction({
    int? categoryId,
    int? subCategoryId,
    required double amount,
    required String type,
    String? note,
    required String date,
    bool isOverspent = false,
    String fundingSource = 'category',
    String? incomeSource,
  }) async {
    if (type == 'income') {
      return addIncomeTransaction(
        amount: amount,
        source: incomeSource ?? 'Other',
        note: note,
        date: date,
      );
    }
    if (amount <= 0) throw ArgumentError('Amount must be greater than zero.');
    if (categoryId == null)
      throw ArgumentError('Expense category is required.');
    final db = await database;
    return db.transaction((txn) async {
      final cat = await txn.query(
        'categories',
        where: 'id = ? AND is_active = 1',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (cat.isEmpty) throw StateError('Category not found.');
      if (subCategoryId != null) {
        final sub = await txn.query(
          'sub_categories',
          where: 'id = ? AND category_id = ?',
          whereArgs: [subCategoryId, categoryId],
          limit: 1,
        );
        if (sub.isEmpty)
          throw StateError('Subcategory does not belong to this category.');
      }
      await _validateExpenseAvailable(
        txn,
        categoryId,
        subCategoryId,
        amount,
        date,
        isOverspent,
      );
      final id = await txn.insert('transactions', {
        'category_id': categoryId,
        'sub_category_id': subCategoryId,
        'amount': amount,
        'type': 'expense',
        'note': note,
        'date': date,
        'created_at': DateTime.now().toIso8601String(),
        'is_overspent': isOverspent ? 1 : 0,
        'funding_source': isOverspent ? 'overspent' : fundingSource,
        'income_source': null,
      });
      await txn.rawUpdate(
        'UPDATE categories SET spent_amount = spent_amount + ? WHERE id = ?',
        [amount, categoryId],
      );
      await _updateMonthlySpent(txn, categoryId, amount, date);
      return id;
    });
  }

  Future<void> _validateExpenseAvailable(
    DatabaseExecutor txn,
    int categoryId,
    int? subCategoryId,
    double amount,
    String date,
    bool overspent, {
    int? excludeTransactionId,
  }) async {
    if (overspent) return;

    final parsedDate = DateTime.tryParse(date) ?? DateTime.now();
    final month = _monthKey(parsedDate);

    final b = await txn.query(
      'monthly_category_budgets',
      where: 'month_key=? AND category_id=?',
      whereArgs: [month, categoryId],
      limit: 1,
    );

    final budget = b.isEmpty
        ? 0.0
        : (b.first['budget_amount'] as num).toDouble();

    final queryArgs = <Object?>[categoryId, month];

    var expenseQuery = '''
    SELECT COALESCE(SUM(amount),0) AS total
    FROM transactions
    WHERE type='expense'
      AND category_id=?
      AND substr(date,1,7)=?
  ''';

    if (excludeTransactionId != null) {
      expenseQuery += ' AND id <> ?';
      queryArgs.add(excludeTransactionId);
    }

    final r = await txn.rawQuery(expenseQuery, queryArgs);

    final spent = (r.first['total'] as num).toDouble();
    final available = budget - spent;

    if (amount > available + 0.01) {
      throw StateError(
        'Not enough money remaining in this category. '
        'Available: ${available.clamp(0, double.infinity).toStringAsFixed(0)}.',
      );
    }
  }

  Future<void> _updateMonthlySpent(
    DatabaseExecutor txn,
    int categoryId,
    double amount,
    String date,
  ) async {
    final monthKey = _monthKey(DateTime.tryParse(date) ?? DateTime.now());
    final existing = await txn.query(
      'monthly_category_budgets',
      where: 'month_key = ? AND category_id = ?',
      whereArgs: [monthKey, categoryId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await txn.insert('monthly_category_budgets', {
        'month_key': monthKey,
        'category_id': categoryId,
        'budget_amount': 0,
        'spent_amount': amount,
      });
    } else {
      await txn.rawUpdate(
        'UPDATE monthly_category_budgets SET spent_amount = MAX(0, spent_amount + ?) WHERE month_key = ? AND category_id = ?',
        [amount, monthKey, categoryId],
      );
    }
  }

  Future<Map<String, dynamic>?> getTransactionById(int id) async =>
      _first('transactions', 'id = ?', [id]);

  Future<List<Map<String, dynamic>>> getRecentTransactions({
    int limit = 5,
  }) async {
    final db = await database;
    return db.rawQuery(
      '''SELECT t.*, c.name AS category_name, c.icon AS category_icon, s.name AS sub_category_name FROM transactions t LEFT JOIN categories c ON c.id=t.category_id LEFT JOIN sub_categories s ON s.id=t.sub_category_id ORDER BY t.date DESC, t.id DESC LIMIT ?''',
      [limit],
    );
  }

  Future<List<Map<String, dynamic>>> getAllTransactions({
    String? type,
    int? categoryId,
    int? subCategoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (type != null) {
      conditions.add('t.type=?');
      args.add(type);
    }
    if (categoryId != null) {
      conditions.add('t.category_id=?');
      args.add(categoryId);
    }
    if (subCategoryId != null) {
      conditions.add('t.sub_category_id=?');
      args.add(subCategoryId);
    }
    if (startDate != null) {
      conditions.add('t.date>=?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      conditions.add('t.date<?');
      args.add(endDate.toIso8601String());
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery(
      '''SELECT t.*, c.name AS category_name, c.icon AS category_icon, s.name AS sub_category_name FROM transactions t LEFT JOIN categories c ON c.id=t.category_id LEFT JOIN sub_categories s ON s.id=t.sub_category_id $where ORDER BY t.date DESC, t.id DESC''',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> getSubcategoryDetails(
    int categoryId,
  ) async {
    final db = await database;
    final month = getCurrentMonthKey();

    final rows = await db.rawQuery(
      '''
    SELECT
      s.id,
      s.category_id,
      s.name,

      COALESCE(
        b.allocated_amount,
        0
      ) AS allocated_amount,

      COALESCE(
        (
          SELECT SUM(t.amount)
          FROM transactions t
          WHERE t.type = 'expense'
            AND t.category_id = s.category_id
            AND t.sub_category_id = s.id
            AND substr(t.date, 1, 7) = ?
        ),
        0
      ) AS spent,

      CASE
        WHEN EXISTS (
          SELECT 1
          FROM transactions ot
          WHERE ot.type = 'expense'
            AND ot.category_id = s.category_id
            AND ot.sub_category_id = s.id
            AND substr(ot.date, 1, 7) = ?
            AND ot.is_overspent = 1
        )
        THEN 1
        ELSE 0
      END AS is_overspent

    FROM sub_categories s

    LEFT JOIN monthly_subcategory_budgets b
      ON b.sub_category_id = s.id
      AND b.month_key = ?

    WHERE s.category_id = ?

    ORDER BY s.id
    ''',
      [
        // Current-month subcategory spending
        month,

        // Current-month overspent transaction
        month,

        // Subcategory budget
        month,

        // Selected category
        categoryId,
      ],
    );

    return rows;
  }

  Future<bool> updateSubCategory({
    required int id,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.length < 2)
      throw ArgumentError('Sub-expense name is too short.');
    final db = await database;
    final rows = await db.query(
      'sub_categories',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final categoryId = rows.first['category_id'] as int;
    final dup = await db.query(
      'sub_categories',
      where: 'category_id=? AND name=? COLLATE NOCASE AND id<>?',
      whereArgs: [categoryId, trimmed, id],
      limit: 1,
    );
    if (dup.isNotEmpty) throw ArgumentError('This sub-expense already exists.');
    return await db.update(
          'sub_categories',
          {'name': trimmed},
          where: 'id=?',
          whereArgs: [id],
        ) ==
        1;
  }

  Future<void> setSubcategorySpending({
    required int subCategoryId,
    required double amount,
    String? note,
    String? date,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    final db = await database;
    final targetDate = date ?? DateTime.now().toIso8601String();
    final subRows = await db.query(
      'sub_categories',
      where: 'id=?',
      whereArgs: [subCategoryId],
      limit: 1,
    );
    if (subRows.isEmpty) throw StateError('Sub-expense not found.');
    final categoryId = subRows.first['category_id'] as int;
    await insertTransaction(
      categoryId: categoryId,
      subCategoryId: subCategoryId,
      amount: amount,
      type: 'expense',
      note: note,
      date: targetDate,
    );
  }

  Future<void> clearSubcategorySpending(int subCategoryId) async =>
      deleteSubCategoryDefinition(subCategoryId);

  Future<bool> deleteSubCategoryDefinition(int subCategoryId) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'sub_categories',
        where: 'id=?',
        whereArgs: [subCategoryId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final txRows = await txn.query(
        'transactions',
        where: 'sub_category_id=?',
        whereArgs: [subCategoryId],
      );
      final months = <String>{};
      for (final row in txRows) {
        final d =
            DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now();
        months.add(_monthKey(d));
        if (row['type'] == 'expense') await _reverseExpense(txn, row);
        await txn.delete('transactions', where: 'id=?', whereArgs: [row['id']]);
      }
      await txn.delete(
        'monthly_subcategory_budgets',
        where: 'sub_category_id=?',
        whereArgs: [subCategoryId],
      );
      final ok =
          await txn.delete(
            'sub_categories',
            where: 'id=?',
            whereArgs: [subCategoryId],
          ) ==
          1;
      for (final m in months) await _refreshMonth(txn, m);
      return ok;
    });
  }

  Future<bool> deleteCustomCategoryWithTransactions(int categoryId) async {
    final db = await database;
    return db.transaction((txn) async {
      final cats = await txn.query(
        'categories',
        where: 'id=?',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (cats.isEmpty || cats.first['is_default'] == 1) return false;

      final txRows = await txn.query(
        'transactions',
        where: 'category_id=?',
        whereArgs: [categoryId],
      );

      final months = <String>{getCurrentMonthKey()};
      for (final row in txRows) {
        final d =
            DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now();
        months.add(_monthKey(d));
        if (row['type'] == 'expense') await _reverseExpense(txn, row);
        await txn.delete('transactions', where: 'id=?', whereArgs: [row['id']]);
      }

      await txn.delete(
        'monthly_subcategory_budgets',
        where: 'category_id=?',
        whereArgs: [categoryId],
      );
      await txn.delete(
        'monthly_category_budgets',
        where: 'category_id=?',
        whereArgs: [categoryId],
      );
      await txn.delete(
        'transfers',
        where: 'source_category_id=? OR destination_category_id=?',
        whereArgs: [categoryId, categoryId],
      );
      await txn.delete(
        'recurring_items',
        where: 'category_id=?',
        whereArgs: [categoryId],
      );
      await txn.delete(
        'sub_categories',
        where: 'category_id=?',
        whereArgs: [categoryId],
      );

      // Permanently remove the category instead of marking it inactive.
      final deleted = await txn.delete(
        'categories',
        where: 'id=?',
        whereArgs: [categoryId],
      );

      if (deleted != 1) return false;

      for (final m in months) await _refreshMonth(txn, m);
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // CATEGORY EDIT / ALLOCATION MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<bool> renameCategory({
    required int categoryId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.length < 2) throw ArgumentError('Category name is too short.');
    final db = await database;

    return db.transaction((txn) async {
      // Repair duplicate default rows left by older builds before checking
      // the requested name. This lets a real renamed default (for example
      // Bills) safely become its original name (Bill).
      await _cleanupDuplicateDefaultCategories(txn);

      final currentRows = await txn.query(
        'categories',
        where: 'id=? AND is_active=1',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (currentRows.isEmpty) return false;

      final current = currentRows.first;
      final duplicate = await txn.query(
        'categories',
        where: 'name=? COLLATE NOCASE AND id<>? AND is_active=1',
        whereArgs: [trimmed, categoryId],
        limit: 1,
      );

      if (duplicate.isNotEmpty) {
        // Older builds could leave an empty custom copy when a default
        // category was renamed. Remove only that safe, empty ghost copy.
        final other = duplicate.first;
        final currentIsDefault = (current['is_default'] as num?)?.toInt() == 1;
        final otherIsDefault = (other['is_default'] as num?)?.toInt() == 1;
        if (currentIsDefault && !otherIsDefault) {
          final otherId = other['id'] as int;
          final txCountRows = await txn.rawQuery(
            'SELECT COUNT(*) AS count FROM transactions WHERE category_id=?',
            [otherId],
          );
          final txCount = (txCountRows.first['count'] as num).toInt();
          final otherBudget = (other['budget_amount'] as num?)?.toDouble() ?? 0;
          final monthlyRows = await txn.rawQuery(
            'SELECT COALESCE(SUM(budget_amount),0) AS total FROM monthly_category_budgets WHERE category_id=?',
            [otherId],
          );
          final monthlyBudget = (monthlyRows.first['total'] as num).toDouble();

          if (txCount == 0 &&
              otherBudget.abs() < 0.01 &&
              monthlyBudget.abs() < 0.01) {
            await txn.delete(
              'monthly_subcategory_budgets',
              where: 'category_id=?',
              whereArgs: [otherId],
            );
            await txn.delete(
              'monthly_category_budgets',
              where: 'category_id=?',
              whereArgs: [otherId],
            );
            await txn.delete(
              'sub_categories',
              where: 'category_id=?',
              whereArgs: [otherId],
            );
            await txn.delete('categories', where: 'id=?', whereArgs: [otherId]);
          } else {
            throw ArgumentError('This category already exists.');
          }
        } else {
          throw ArgumentError('This category already exists.');
        }
      }

      return await txn.update(
            'categories',
            {'name': trimmed},
            where: 'id=?',
            whereArgs: [categoryId],
          ) ==
          1;
    });
  }

  Future<double> getCurrentMonthCategoryRemaining(int categoryId) async {
    final db = await database;
    final month = getCurrentMonthKey();
    final budgetRows = await db.query(
      'monthly_category_budgets',
      where: 'month_key=? AND category_id=?',
      whereArgs: [month, categoryId],
      limit: 1,
    );
    final budget = budgetRows.isEmpty
        ? 0.0
        : (budgetRows.first['budget_amount'] as num).toDouble();
    final spentRows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount),0) AS total FROM transactions WHERE type='expense' AND category_id=? AND substr(date,1,7)=?",
      [categoryId, month],
    );
    final spent = (spentRows.first['total'] as num).toDouble();
    return budget - spent;
  }

  Future<bool> increaseCategoryFromUnallocated({
    required int categoryId,
    required double amount,
  }) async {
    if (amount <= 0) return false;
    final db = await database;
    final month = getCurrentMonthKey();
    return db.transaction((txn) async {
      final settings = await txn.query('app_settings', where: 'id=1', limit: 1);
      final cat = await txn.query(
        'categories',
        where: 'id=? AND is_active=1',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (settings.isEmpty || cat.isEmpty) return false;
      final available = (settings.first['unallocated_balance'] as num)
          .toDouble();
      if (amount > available + 0.01) return false;
      await txn.rawUpdate(
        'UPDATE categories SET is_budgeted=1,budget_amount=budget_amount+? WHERE id=?',
        [amount, categoryId],
      );
      await txn.update('app_settings', {
        'unallocated_balance': available - amount,
      }, where: 'id=1');
      await _changeMonthlyCategoryBudget(txn, month, categoryId, amount);
      await _refreshMonth(txn, month);
      return true;
    });
  }

  Future<bool> increaseCategoryFromCategory({
    required int sourceCategoryId,
    required int destinationCategoryId,
    required double amount,
  }) async {
    if (amount <= 0 || sourceCategoryId == destinationCategoryId) return false;
    final db = await database;
    final month = getCurrentMonthKey();
    return db.transaction((txn) async {
      final source = await txn.query(
        'categories',
        where: 'id=? AND is_active=1',
        whereArgs: [sourceCategoryId],
        limit: 1,
      );
      final destination = await txn.query(
        'categories',
        where: 'id=? AND is_active=1',
        whereArgs: [destinationCategoryId],
        limit: 1,
      );
      if (source.isEmpty || destination.isEmpty) return false;
      final sourceBudget = (source.first['budget_amount'] as num).toDouble();
      final spentRows = await txn.rawQuery(
        "SELECT COALESCE(SUM(amount),0) AS total FROM transactions WHERE type='expense' AND category_id=? AND substr(date,1,7)=?",
        [sourceCategoryId, month],
      );
      final sourceSpent = (spentRows.first['total'] as num).toDouble();
      final available = sourceBudget - sourceSpent;
      if (amount > available + 0.01) return false;
      await txn.rawUpdate(
        'UPDATE categories SET budget_amount=MAX(0,budget_amount-?) WHERE id=?',
        [amount, sourceCategoryId],
      );
      await txn.rawUpdate(
        'UPDATE categories SET is_budgeted=1,budget_amount=budget_amount+? WHERE id=?',
        [amount, destinationCategoryId],
      );
      await _changeMonthlyCategoryBudget(txn, month, sourceCategoryId, -amount);
      await _changeMonthlyCategoryBudget(
        txn,
        month,
        destinationCategoryId,
        amount,
      );
      await txn.insert('transfers', {
        'source_category_id': sourceCategoryId,
        'destination_category_id': destinationCategoryId,
        'amount': amount,
        'note': 'Allocation adjustment',
        'date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await _refreshMonth(txn, month);
      return true;
    });
  }

  Future<bool> reduceCategoryAllocation({
    required int categoryId,
    required double amount,
  }) async {
    if (amount <= 0) return false;
    final db = await database;
    final month = getCurrentMonthKey();
    return db.transaction((txn) async {
      final cat = await txn.query(
        'categories',
        where: 'id=? AND is_active=1',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (cat.isEmpty) return false;
      final budget = (cat.first['budget_amount'] as num).toDouble();
      final spentRows = await txn.rawQuery(
        "SELECT COALESCE(SUM(amount),0) AS total FROM transactions WHERE type='expense' AND category_id=? AND substr(date,1,7)=?",
        [categoryId, month],
      );
      final spent = (spentRows.first['total'] as num).toDouble();
      if (budget - amount + 0.01 < spent) return false;
      await txn.rawUpdate(
        'UPDATE categories SET budget_amount=MAX(0,budget_amount-?),is_budgeted=CASE WHEN budget_amount-? > 0 THEN 1 ELSE 0 END WHERE id=?',
        [amount, amount, categoryId],
      );
      await _changeMonthlyCategoryBudget(txn, month, categoryId, -amount);
      await _refreshMonth(txn, month);
      return true;
    });
  }

  Future<void> _changeMonthlyCategoryBudget(
    DatabaseExecutor txn,
    String month,
    int categoryId,
    double delta,
  ) async {
    final rows = await txn.query(
      'monthly_category_budgets',
      where: 'month_key=? AND category_id=?',
      whereArgs: [month, categoryId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await txn.insert('monthly_category_budgets', {
        'month_key': month,
        'category_id': categoryId,
        'budget_amount': delta < 0 ? 0 : delta,
        'spent_amount': 0,
      });
    } else {
      await txn.rawUpdate(
        'UPDATE monthly_category_budgets SET budget_amount=MAX(0,budget_amount+?) WHERE month_key=? AND category_id=?',
        [delta, month, categoryId],
      );
    }
  }

  Future<bool> deleteTransactionsBySubCategories(
    List<int> subCategoryIds,
  ) async {
    if (subCategoryIds.isEmpty) return false;
    final db = await database;
    return db.transaction((txn) async {
      final placeholders = List.filled(subCategoryIds.length, '?').join(',');
      final rows = await txn.rawQuery(
        'SELECT * FROM transactions WHERE sub_category_id IN ($placeholders)',
        subCategoryIds,
      );
      final months = <String>{};
      for (final row in rows) {
        final d =
            DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now();
        months.add(_monthKey(d));
        if (row['type'] == 'expense') await _reverseExpense(txn, row);
        await txn.delete('transactions', where: 'id=?', whereArgs: [row['id']]);
      }
      for (final id in subCategoryIds) {
        await txn.delete(
          'monthly_subcategory_budgets',
          where: 'sub_category_id=?',
          whereArgs: [id],
        );
        await txn.delete('sub_categories', where: 'id=?', whereArgs: [id]);
      }
      for (final m in months) await _refreshMonth(txn, m);
      return rows.isNotEmpty || subCategoryIds.isNotEmpty;
    });
  }

  Future<bool> setSubcategoryAllocation({
    required int subCategoryId,
    required double amount,
  }) async {
    if (amount < 0) return false;
    final db = await database;
    final month = getCurrentMonthKey();
    return db.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''SELECT s.id,s.category_id,c.budget_amount FROM sub_categories s JOIN categories c ON c.id=s.category_id WHERE s.id=? AND c.is_active=1''',
        [subCategoryId],
      );
      if (rows.isEmpty) return false;
      final categoryId = rows.first['category_id'] as int;
      final budget = (rows.first['budget_amount'] as num).toDouble();
      final spentRows = await txn.rawQuery(
        '''SELECT COALESCE(SUM(amount),0) total FROM transactions WHERE type='expense' AND sub_category_id=? AND substr(date,1,7)=?''',
        [subCategoryId, month],
      );
      final spent = (spentRows.first['total'] as num).toDouble();
      if (amount + 0.01 < spent)
        throw StateError(
          'Subcategory allocation cannot be lower than money already spent.',
        );
      final otherRows = await txn.rawQuery(
        '''SELECT COALESCE(SUM(allocated_amount),0) total FROM monthly_subcategory_budgets WHERE month_key=? AND category_id=? AND sub_category_id<>?''',
        [month, categoryId, subCategoryId],
      );
      final other = (otherRows.first['total'] as num).toDouble();
      if (other + amount > budget + 0.01)
        throw StateError(
          'Subcategory allocations cannot exceed the parent category allocation.',
        );
      await txn.insert('monthly_subcategory_budgets', {
        'month_key': month,
        'sub_category_id': subCategoryId,
        'category_id': categoryId,
        'allocated_amount': amount,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  Future<void> _reverseExpense(
    DatabaseExecutor txn,
    Map<String, dynamic> row,
  ) async {
    final categoryId = row['category_id'] as int?;
    final amount = (row['amount'] as num).toDouble();
    final date =
        DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now();
    if (categoryId != null) {
      await txn.rawUpdate(
        'UPDATE categories SET spent_amount=MAX(0,spent_amount-?) WHERE id=?',
        [amount, categoryId],
      );
      final month = _monthKey(date);
      await txn.rawUpdate(
        'UPDATE monthly_category_budgets SET spent_amount=MAX(0,spent_amount-?) WHERE month_key=? AND category_id=?',
        [amount, month, categoryId],
      );
    }
  }

  Future<void> updateExpenseTransaction({
    required int id,
    required double newAmount,
    required int newCategoryId,
    int? newSubCategoryId,
    String? newNote,
    String? newDate,
    bool? forceOverspent,
  }) async {
    if (newAmount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    final db = await database;

    await db.transaction((txn) async {
      // -----------------------------------------------------------------------
      // 1. Find the existing expense.
      // -----------------------------------------------------------------------
      final rows = await txn.query(
        'transactions',
        where: 'id=? AND type=?',
        whereArgs: [id, 'expense'],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Expense transaction not found.');
      }

      final old = rows.first;

      // final oldCategoryId = old['category_id'] as int?;
      // final oldAmount = (old['amount'] as num).toDouble();
      final oldDate =
          old['date']?.toString() ?? DateTime.now().toIso8601String();

      final targetDate = newDate ?? oldDate;

      // -----------------------------------------------------------------------
      // 2. Validate the new category.
      // -----------------------------------------------------------------------
      final categoryRows = await txn.query(
        'categories',
        where: 'id=? AND is_active=1',
        whereArgs: [newCategoryId],
        limit: 1,
      );

      if (categoryRows.isEmpty) {
        throw StateError('Category not found.');
      }

      // -----------------------------------------------------------------------
      // 3. Validate the new subcategory, if supplied.
      // -----------------------------------------------------------------------
      if (newSubCategoryId != null) {
        final subRows = await txn.query(
          'sub_categories',
          where: 'id=? AND category_id=?',
          whereArgs: [newSubCategoryId, newCategoryId],
          limit: 1,
        );

        if (subRows.isEmpty) {
          throw StateError('Subcategory does not belong to this category.');
        }
      }

      // -----------------------------------------------------------------------
      // 4. Reverse the OLD expense from accounting.
      //
      //    Example:
      //    Old expense = Rs 5,000
      //
      //    Category spent:
      //      Rs 10,000 -> Rs 5,000
      //
      //    This does NOT delete the transaction.
      // -----------------------------------------------------------------------
      await _reverseExpense(txn, old);

      // -----------------------------------------------------------------------
      // 5. Determine the overspent state.
      //
      //    null  = check budget normally
      //    false = explicitly save as normal
      //    true  = explicitly save as overspent
      //
      //    IMPORTANT:
      //    We do NOT inherit the old is_overspent value.
      //
      //    Therefore:
      //      Rs 12,000 overspent -> edit to Rs 7,000
      //      becomes normal automatically when allowed.
      // -----------------------------------------------------------------------
      final bool overspent;

      if (forceOverspent == true) {
        overspent = true;
      } else {
        overspent = false;

        // When editing the same category/month, transaction ID must be
        // excluded from the budget calculation because it is still present
        // in the transactions table.
        await _validateExpenseAvailable(
          txn,
          newCategoryId,
          newSubCategoryId,
          newAmount,
          targetDate,
          false,
          excludeTransactionId: id,
        );
      }

      // -----------------------------------------------------------------------
      // 6. UPDATE THE EXISTING TRANSACTION.
      //
      //    This is the important change:
      //
      //    NO DELETE
      //    NO INSERT
      //
      //    The original transaction ID remains unchanged.
      // -----------------------------------------------------------------------
      final updated = await txn.update(
        'transactions',
        {
          'category_id': newCategoryId,
          'sub_category_id': newSubCategoryId,
          'amount': newAmount,
          'note': newNote,
          'date': targetDate,
          'is_overspent': overspent ? 1 : 0,
          'funding_source': overspent ? 'overspent' : 'category',
          'income_source': null,
        },
        where: 'id=?',
        whereArgs: [id],
      );

      if (updated != 1) {
        throw StateError('Unable to update expense transaction.');
      }

      // -----------------------------------------------------------------------
      // 7. Apply the NEW expense to the new category.
      // -----------------------------------------------------------------------
      await txn.rawUpdate(
        'UPDATE categories SET spent_amount=spent_amount+? WHERE id=?',
        [newAmount, newCategoryId],
      );

      // -----------------------------------------------------------------------
      // 8. Apply the NEW expense to the correct month.
      // -----------------------------------------------------------------------
      await _updateMonthlySpent(txn, newCategoryId, newAmount, targetDate);
    });
  }

  Future<void> updateTransaction({
    required int id,
    required double newAmount,
    int? newCategoryId,
    int? newSubCategoryId,
    String? newNote,
    String? newDate,
  }) async {
    final old = await getTransactionById(id);
    if (old == null) throw StateError('Transaction not found.');
    if (old['type'] == 'income') {
      await updateIncomeTransaction(
        id: id,
        newAmount: newAmount,
        newSource: old['income_source']?.toString() ?? 'Other',
        newNote: newNote,
        newDate: newDate,
      );
      return;
    }
    await updateExpenseTransaction(
      id: id,
      newAmount: newAmount,
      newCategoryId: newCategoryId ?? (old['category_id'] as int),
      newSubCategoryId: newSubCategoryId,
      newNote: newNote,
      newDate: newDate,
    );
  }

  Future<void> deleteTransaction(int id) async => deleteTransactions([id]);

  Future<void> deleteTransactions(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final rows = <Map<String, dynamic>>[];
      for (final id in ids) {
        final r = await txn.query(
          'transactions',
          where: 'id=?',
          whereArgs: [id],
          limit: 1,
        );
        if (r.isNotEmpty) rows.add(r.first);
      }
      final current = getCurrentMonthKey();
      final deleting = rows
          .where(
            (r) =>
                r['type'] == 'income' &&
                _monthKey(
                      DateTime.tryParse(r['date']?.toString() ?? '') ??
                          DateTime.now(),
                    ) ==
                    current,
          )
          .fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
      final allocated = await _allocatedForMonth(txn, current);
      final income = await _incomeForMonth(txn, current);
      if (income - deleting + 0.01 < allocated)
        throw StateError(
          'These income records cannot be deleted because the remaining income would be lower than the amount already allocated.',
        );
      final months = <String>{};
      for (final row in rows) {
        final d =
            DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now();
        months.add(_monthKey(d));
        if (row['type'] == 'expense') await _reverseExpense(txn, row);
        await txn.delete('transactions', where: 'id=?', whereArgs: [row['id']]);
      }
      for (final m in months) await _refreshMonth(txn, m);
    });
  }

  // ---------------------------------------------------------------------------
  // CATEGORY SPENDING
  // ---------------------------------------------------------------------------

  Future<double> getCategorySpent(int categoryId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE category_id = ?
        AND type = 'expense'
      ''',
      [categoryId],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getCurrentMonthCategorySpent(int categoryId) async {
    final db = await database;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE category_id = ?
        AND type = 'expense'
        AND date >= ?
        AND date < ?
      ''',
      [categoryId, start.toIso8601String(), end.toIso8601String()],
    );

    return (result.first['total'] as num).toDouble();
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD TOTALS
  // ---------------------------------------------------------------------------

  Future<double> getTotalAllocated() async {
    final db = await database;
    final month = getCurrentMonthKey();
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(budget_amount),0) AS total
      FROM monthly_category_budgets
      WHERE month_key = ?
    ''',
      [month],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalSpent() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT COALESCE(
        SUM(amount),
        0
      ) AS total
      FROM transactions
      WHERE type = 'expense'
      ''');

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getCurrentMonthTotalSpent() async {
    final db = await database;

    final now = DateTime.now();

    final start = DateTime(now.year, now.month);

    final end = DateTime(now.year, now.month + 1);

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(amount),
        0
      ) AS total
      FROM transactions
      WHERE type = 'expense'
        AND date >= ?
        AND date < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return (result.first['total'] as num).toDouble();
  }

  // ---------------------------------------------------------------------------
  // CURRENT MONTH CATEGORY SPENDING
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCurrentMonthCategorySpending() async {
    final db = await database;

    final now = DateTime.now();

    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);

    return db.rawQuery(
      '''
    SELECT
      c.id,
      c.name,
      c.icon,
      c.is_default,
      COALESCE(m.budget_amount, c.budget_amount, 0) AS budget_amount,
      COALESCE(
        SUM(
          CASE
            WHEN t.type = 'expense'
            THEN t.amount
            ELSE 0
          END
        ),
        0
      ) AS spent
    FROM categories c
    LEFT JOIN monthly_category_budgets m
      ON m.category_id = c.id AND m.month_key = ?
    LEFT JOIN transactions t
      ON t.category_id = c.id
      AND t.date >= ?
      AND t.date < ?
    WHERE c.is_active = 1
    GROUP BY c.id
    ORDER BY spent DESC, c.id ASC
    ''',
      [getCurrentMonthKey(), start.toIso8601String(), end.toIso8601String()],
    );
  }

  // ---------------------------------------------------------------------------
  // DAILY SPENDING
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCurrentMonthDailySpending() async {
    final db = await database;

    final now = DateTime.now();

    final start = DateTime(now.year, now.month);

    final end = DateTime(now.year, now.month + 1);

    return db.rawQuery(
      '''
      SELECT
        substr(date, 1, 10) AS day,
        COALESCE(
          SUM(amount),
          0
        ) AS spent
      FROM transactions
      WHERE type = 'expense'
        AND date >= ?
        AND date < ?
      GROUP BY substr(date, 1, 10)
      ORDER BY day ASC
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
  }

  // ---------------------------------------------------------------------------
  // SAVINGS GOALS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAllSavingsGoals() async {
    final db = await database;

    return db.query('savings_goals', orderBy: 'id DESC');
  }

  Future<int> createSavingsGoal({
    required String name,
    required double targetAmount,
    String? deadline,
  }) async {
    if (targetAmount <= 0) {
      throw ArgumentError('Target amount must be greater than zero.');
    }

    final db = await database;

    return db.insert('savings_goals', {
      'name': name.trim(),
      'target_amount': targetAmount,
      'current_amount': 0,
      'deadline': deadline,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> addSavingsContribution({
    required int goalId,
    required double amount,
    int? transactionId,
    String? date,
  }) async {
    if (amount <= 0) {
      return false;
    }

    final db = await database;

    return db.transaction((txn) async {
      final goals = await txn.query(
        'savings_goals',
        where: 'id = ?',
        whereArgs: [goalId],
        limit: 1,
      );

      if (goals.isEmpty) {
        return false;
      }

      final goal = goals.first;

      final target = (goal['target_amount'] as num).toDouble();

      final current = (goal['current_amount'] as num).toDouble();

      final newAmount = current + amount;

      await txn.update(
        'savings_goals',
        {
          'current_amount': newAmount,
          'status': newAmount >= target ? 'achieved' : 'active',
        },
        where: 'id = ?',
        whereArgs: [goalId],
      );

      await txn.insert('savings_contributions', {
        'goal_id': goalId,
        'transaction_id': transactionId,
        'amount': amount,
        'date': date ?? DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // RECURRING PAYMENTS / REMINDERS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAllRecurringItems() async {
    final db = await database;

    return db.query(
      'recurring_items',
      where: 'is_active = 1',
      orderBy: 'due_date ASC',
    );
  }

  Future<int> createRecurringItem({
    required String name,
    required double amount,
    required int categoryId,
    int? subCategoryId,
    required String dueDate,
    int reminderDaysBefore = 3,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    final db = await database;

    return db.insert('recurring_items', {
      'name': name.trim(),
      'amount': amount,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'due_date': dueDate,
      'reminder_days_before': reminderDaysBefore,
      'payment_status': 'pending',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------

  Future<int> createNotification({
    required String title,
    required String message,
    required String type,
    int? relatedId,
  }) async {
    final db = await database;

    return db.insert('notifications', {
      'title': title,
      'message': message,
      'type': type,
      'related_id': relatedId,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final db = await database;

    return db.query('notifications', orderBy: 'created_at DESC');
  }

  Future<void> markNotificationRead(int id) async {
    final db = await database;

    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // TRANSFERS
  // ---------------------------------------------------------------------------

  Future<bool> transferBetweenCategories({
    required int sourceCategoryId,
    required int destinationCategoryId,
    required double amount,
    String? note,
    String? date,
  }) async {
    if (amount <= 0) {
      return false;
    }

    if (sourceCategoryId == destinationCategoryId) {
      return false;
    }

    final db = await database;

    return db.transaction((txn) async {
      final sourceRows = await txn.query(
        'categories',
        where: 'id = ?',
        whereArgs: [sourceCategoryId],
        limit: 1,
      );

      final destinationRows = await txn.query(
        'categories',
        where: 'id = ?',
        whereArgs: [destinationCategoryId],
        limit: 1,
      );

      if (sourceRows.isEmpty || destinationRows.isEmpty) {
        return false;
      }

      final sourceBudget = (sourceRows.first['budget_amount'] as num)
          .toDouble();

      if (amount > sourceBudget + 0.01) {
        return false;
      }

      await txn.rawUpdate(
        '''
          UPDATE categories
          SET budget_amount =
            MAX(
              0,
              budget_amount - ?
            )
          WHERE id = ?
          ''',
        [amount, sourceCategoryId],
      );

      await txn.rawUpdate(
        '''
          UPDATE categories
          SET is_budgeted = 1,
              budget_amount =
                budget_amount + ?
          WHERE id = ?
          ''',
        [amount, destinationCategoryId],
      );

      await txn.insert('transfers', {
        'source_category_id': sourceCategoryId,
        'destination_category_id': destinationCategoryId,
        'amount': amount,
        'note': note,
        'date': date ?? DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // UTILITY
  // ---------------------------------------------------------------------------

  Future<bool> categoriesExist() async {
    final db = await database;

    final rows = await db.query('categories', where: 'is_active = 1', limit: 1);

    return rows.isNotEmpty;
  }

  Future<void> adjustCategorySpent(int categoryId, double amountChange) async {
    final db = await database;

    await db.rawUpdate(
      '''
      UPDATE categories
      SET spent_amount =
        MAX(
          0,
          spent_amount + ?
        )
      WHERE id = ?
      ''',
      [amountChange, categoryId],
    );
  }

  Future<void> closeDatabase() async {
    final db = _database;

    if (db != null && db.isOpen) {
      await db.close();
    }

    _database = null;
  }
}
