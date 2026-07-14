import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Category { food, transport, shopping, bills, health, leisure, work }

enum ReportPeriod { daily, monthly, yearly }

const savedExpensesKey = 'saved_expenses';

const Map<Category, IconData> categoryIcons = {
  Category.food: Icons.restaurant,
  Category.transport: Icons.directions_bus,
  Category.shopping: Icons.shopping_bag,
  Category.bills: Icons.receipt_long,
  Category.health: Icons.favorite,
  Category.leisure: Icons.sports_esports,
  Category.work: Icons.work,
};

const Map<Category, Color> categoryColors = {
  Category.food: Color(0xFF0E9F6E),
  Category.transport: Color(0xFF2563EB),
  Category.shopping: Color(0xFFDB2777),
  Category.bills: Color(0xFFD97706),
  Category.health: Color(0xFFDC2626),
  Category.leisure: Color(0xFF7C3AED),
  Category.work: Color(0xFF475569),
};

final amountInputFormatter = TextInputFormatter.withFunction((
  oldValue,
  newValue,
) {
  final amountPattern = RegExp(r'^\d*$');

  if (amountPattern.hasMatch(newValue.text)) {
    return newValue;
  }

  return oldValue;
});

class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final Category category;
  final String note;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.note = '',
  });

  Map<String, Object> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category.name,
      'note': note,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      category: Category.values.firstWhere(
        (category) => category.name == json['category'],
        orElse: () => Category.food,
      ),
      note: json['note'] as String? ?? '',
    );
  }
}

class ReportEntry {
  final String label;
  final double total;
  final int count;

  const ReportEntry({
    required this.label,
    required this.total,
    required this.count,
  });
}

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ExpenseTrackerApp',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF8FAFC),
        ),
      ),
      home: const ExpenseDashboard(),
    );
  }
}

class ExpenseDashboard extends StatefulWidget {
  const ExpenseDashboard({super.key});

  @override
  State<ExpenseDashboard> createState() => _ExpenseDashboardState();
}

class _ExpenseDashboardState extends State<ExpenseDashboard> {
  final PageController _pageController = PageController();
  final List<Expense> _registeredExpenses = [];

  Category? _selectedFilter;
  ReportPeriod _selectedReportPeriod = ReportPeriod.daily;
  int _activePage = 0;

  List<Expense> get _visibleExpenses {
    final expenses = _selectedFilter == null
        ? _registeredExpenses
        : _registeredExpenses
              .where((expense) => expense.category == _selectedFilter)
              .toList();

    return expenses..sort((a, b) => b.date.compareTo(a.date));
  }

  double get _totalExpenses {
    return _registeredExpenses.fold(
      0.0,
      (sum, expense) => sum + expense.amount,
    );
  }

  double get _todayExpenses {
    final now = DateTime.now();
    return _registeredExpenses
        .where(
          (expense) =>
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.date.day == now.day,
        )
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double get _filteredTotal {
    return _visibleExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Map<Category, double> get _categoryTotals {
    final totals = <Category, double>{
      for (final category in Category.values) category: 0,
    };

    for (final expense in _registeredExpenses) {
      totals[expense.category] = totals[expense.category]! + expense.amount;
    }

    return totals;
  }

  List<ReportEntry> get _reportEntries {
    final grouped = <String, _ReportBucket>{};

    for (final expense in _registeredExpenses) {
      final key = reportKey(expense.date, _selectedReportPeriod);
      final label = reportLabel(expense.date, _selectedReportPeriod);
      final sortableDate = reportSortDate(expense.date, _selectedReportPeriod);
      final bucket = grouped.putIfAbsent(
        key,
        () => _ReportBucket(label: label, sortDate: sortableDate),
      );

      bucket.total += expense.amount;
      bucket.count += 1;
    }

    final buckets = grouped.values.toList()
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));

    return buckets
        .map(
          (bucket) => ReportEntry(
            label: bucket.label,
            total: bucket.total,
            count: bucket.count,
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedExpenses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedExpenses() async {
    final preferences = await SharedPreferences.getInstance();
    final savedExpenses = preferences.getString(savedExpensesKey);

    if (savedExpenses == null || savedExpenses.isEmpty) return;

    final decodedExpenses = jsonDecode(savedExpenses) as List<dynamic>;
    final loadedExpenses = decodedExpenses
        .map((expense) => Expense.fromJson(expense as Map<String, dynamic>))
        .toList();

    if (!mounted) return;

    setState(() {
      _registeredExpenses
        ..clear()
        ..addAll(loadedExpenses);
    });
  }

  Future<void> _saveExpenses() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedExpenses = jsonEncode(
      _registeredExpenses.map((expense) => expense.toJson()).toList(),
    );

    await preferences.setString(savedExpensesKey, encodedExpenses);
  }

  void _showExpensePage() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _openAddExpenseOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ExpenseFormModal(onSaveExpense: _addExpense),
    );
  }

  void _openEditExpenseOverlay(Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) =>
          ExpenseFormModal(expense: expense, onSaveExpense: _updateExpense),
    );
  }

  void _addExpense(Expense expense) {
    setState(() {
      _registeredExpenses.add(expense);
    });
    _saveExpenses();

    _showSuccessMessage('${expense.title} created successfully');
  }

  void _updateExpense(Expense expense) {
    final expenseIndex = _registeredExpenses.indexWhere(
      (item) => item.id == expense.id,
    );

    if (expenseIndex == -1) return;

    setState(() {
      _registeredExpenses[expenseIndex] = expense;
    });
    _saveExpenses();

    _showSuccessMessage('${expense.title} updated successfully');
  }

  void _deleteExpense(Expense expense) {
    final expenseIndex = _registeredExpenses.indexOf(expense);

    setState(() {
      _registeredExpenses.remove(expense);
    });
    _saveExpenses();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('${expense.title} deleted')),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _registeredExpenses.insert(expenseIndex, expense);
            });
            _saveExpenses();
          },
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF047857),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleExpenses = _visibleExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ExpenseTrackerApp',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: _activePage == 1
            ? [
                IconButton.filledTonal(
                  tooltip: 'Add expense',
                  icon: const Icon(Icons.add),
                  onPressed: _openAddExpenseOverlay,
                ),
                const SizedBox(width: 12),
              ]
            : null,
      ),
      floatingActionButton: _activePage == 1
          ? FloatingActionButton.extended(
              onPressed: _openAddExpenseOverlay,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: (page) => setState(() => _activePage = page),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: HomeWelcomePanel(onStartPressed: _showExpensePage),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Back to home',
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () {
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Current expense process',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DashboardSummary(
                  totalExpenses: _totalExpenses,
                  todayExpenses: _todayExpenses,
                  transactionCount: _registeredExpenses.length,
                ),
                const SizedBox(height: 16),
                ExpenseReports(
                  selectedPeriod: _selectedReportPeriod,
                  entries: _reportEntries,
                  onPeriodChanged: (period) {
                    setState(() => _selectedReportPeriod = period);
                  },
                ),
                const SizedBox(height: 16),
                CategoryBreakdown(
                  categoryTotals: _categoryTotals,
                  totalExpenses: _totalExpenses,
                ),
                const SizedBox(height: 18),
                ExpenseFilters(
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (category) {
                    setState(() => _selectedFilter = category);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedFilter == null
                          ? 'Recent expenses'
                          : '${formatCategory(_selectedFilter!)} expenses',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      formatCurrency(_filteredTotal),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (visibleExpenses.isEmpty)
                  EmptyExpenses(
                    hasFilter: _selectedFilter != null,
                    onClearFilter: () => setState(() => _selectedFilter = null),
                  )
                else
                  ...visibleExpenses.map(
                    (expense) => ExpenseTile(
                      key: ValueKey(expense.id),
                      expense: expense,
                      onEdit: _openEditExpenseOverlay,
                      onDelete: _deleteExpense,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HomeWelcomePanel extends StatelessWidget {
  final VoidCallback onStartPressed;

  const HomeWelcomePanel({super.key, required this.onStartPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withAlpha(28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.onPrimary,
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Hello Baby , This is for you',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Track every expense, review your reports, and keep your money story clear.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary.withAlpha(220),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.tonalIcon(
              onPressed: onStartPressed,
              icon: const Icon(Icons.keyboard_arrow_up),
              label: const Text('View expense process'),
            ),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Text(
                    'Slide up for expense process',
                    style: TextStyle(
                      color: colorScheme.onPrimary.withAlpha(220),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.keyboard_arrow_up,
                    color: colorScheme.onPrimary,
                    size: 30,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBucket {
  final String label;
  final DateTime sortDate;
  double total = 0;
  int count = 0;

  _ReportBucket({required this.label, required this.sortDate});
}

class DashboardSummary extends StatelessWidget {
  final double totalExpenses;
  final double todayExpenses;
  final int transactionCount;

  const DashboardSummary({
    super.key,
    required this.totalExpenses,
    required this.todayExpenses,
    required this.transactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total spent',
            style: TextStyle(
              color: colorScheme.onPrimary.withAlpha(210),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency(totalExpenses),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SummaryMetric(
                  icon: Icons.today,
                  label: 'Today',
                  value: formatCurrency(todayExpenses),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryMetric(
                  icon: Icons.list_alt,
                  label: 'Records',
                  value: transactionCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const SummaryMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onPrimary.withAlpha(200),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseReports extends StatelessWidget {
  final ReportPeriod selectedPeriod;
  final List<ReportEntry> entries;
  final ValueChanged<ReportPeriod> onPeriodChanged;

  const ExpenseReports({
    super.key,
    required this.selectedPeriod,
    required this.entries,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final highestTotal = entries.fold<double>(
      0,
      (highest, entry) => entry.total > highest ? entry.total : highest,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ReportPeriod>(
            segments: const [
              ButtonSegment(
                value: ReportPeriod.daily,
                icon: Icon(Icons.today),
                label: Text('Daily'),
              ),
              ButtonSegment(
                value: ReportPeriod.monthly,
                icon: Icon(Icons.calendar_view_month),
                label: Text('Monthly'),
              ),
              ButtonSegment(
                value: ReportPeriod.yearly,
                icon: Icon(Icons.calendar_month),
                label: Text('Yearly'),
              ),
            ],
            selected: {selectedPeriod},
            onSelectionChanged: (selection) {
              onPeriodChanged(selection.first);
            },
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: entries.isEmpty
              ? const Text(
                  'Add expenses to see daily, monthly, and yearly reports.',
                )
              : Column(
                  children: entries.map((entry) {
                    final ratio = highestTotal == 0
                        ? 0.0
                        : entry.total / highestTotal;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              reportIcon(selectedPeriod),
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(entry.total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 8,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${entry.count} ${entry.count == 1 ? 'expense' : 'expenses'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class CategoryBreakdown extends StatelessWidget {
  final Map<Category, double> categoryTotals;
  final double totalExpenses;

  const CategoryBreakdown({
    super.key,
    required this.categoryTotals,
    required this.totalExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final activeCategories = Category.values
        .where((category) => (categoryTotals[category] ?? 0) > 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category breakdown',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: activeCategories.isEmpty
              ? const Text('Add an expense to see category totals.')
              : Column(
                  children: activeCategories.map((category) {
                    final amount = categoryTotals[category] ?? 0;
                    final ratio = totalExpenses == 0
                        ? 0.0
                        : amount / totalExpenses;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Icon(
                            categoryIcons[category],
                            color: categoryColors[category],
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 86,
                            child: Text(
                              formatCategory(category),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 9,
                                color: categoryColors[category],
                                backgroundColor: const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 72,
                            child: Text(
                              formatCurrency(amount),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class ExpenseFilters extends StatelessWidget {
  final Category? selectedFilter;
  final ValueChanged<Category?> onFilterChanged;

  const ExpenseFilters({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: const Icon(Icons.all_inclusive, size: 18),
              label: const Text('All'),
              selected: selectedFilter == null,
              onSelected: (_) => onFilterChanged(null),
            ),
          ),
          ...Category.values.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(categoryIcons[category], size: 18),
                label: Text(formatCategory(category)),
                selected: selectedFilter == category,
                onSelected: (_) => onFilterChanged(category),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final ValueChanged<Expense> onEdit;
  final ValueChanged<Expense> onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryColors[expense.category]!;

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(expense),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          minVerticalPadding: 14,
          leading: CircleAvatar(
            backgroundColor: color.withAlpha(32),
            foregroundColor: color,
            child: Icon(categoryIcons[expense.category]),
          ),
          title: Text(
            expense.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              expense.note.isEmpty
                  ? '${formatDate(expense.date)} - ${formatCategory(expense.category)}'
                  : '${formatDate(expense.date)} - ${expense.note}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: SizedBox(
            width: 168,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    formatCurrency(expense.amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Edit expense',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(expense),
                ),
                IconButton(
                  tooltip: 'Delete expense',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDelete(expense),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyExpenses extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onClearFilter;

  const EmptyExpenses({
    super.key,
    required this.hasFilter,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            hasFilter ? Icons.filter_alt_off : Icons.account_balance_wallet,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'No expenses in this category' : 'No expenses yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Clear the filter to view all saved expenses.'
                : 'Tap Add to record your first expense.',
            textAlign: TextAlign.center,
          ),
          if (hasFilter) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onClearFilter,
              icon: const Icon(Icons.clear),
              label: const Text('Clear filter'),
            ),
          ],
        ],
      ),
    );
  }
}

class ExpenseFormModal extends StatefulWidget {
  final Expense? expense;
  final void Function(Expense expense) onSaveExpense;

  const ExpenseFormModal({
    super.key,
    this.expense,
    required this.onSaveExpense,
  });

  @override
  State<ExpenseFormModal> createState() => _ExpenseFormModalState();
}

class _ExpenseFormModalState extends State<ExpenseFormModal> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Category _selectedCategory = Category.food;
  DateTime _selectedDate = DateTime.now();

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;
    if (expense == null) return;

    _titleController.text = expense.title;
    _amountController.text = expense.amount.toStringAsFixed(0);
    _noteController.text = expense.note;
    _selectedCategory = expense.category;
    _selectedDate = expense.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );

    if (pickedDate == null) return;

    setState(() => _selectedDate = pickedDate);
  }

  void _submitExpenseData() {
    final enteredAmount = double.tryParse(_amountController.text.trim());
    final amountIsValid = enteredAmount != null && enteredAmount > 0;

    if (_titleController.text.trim().isEmpty || !amountIsValid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invalid expense'),
          content: const Text(
            'Please enter a title and an amount greater than 0.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Okay'),
            ),
          ],
        ),
      );
      return;
    }

    widget.onSaveExpense(
      Expense(
        id:
            widget.expense?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        amount: enteredAmount,
        date: _selectedDate,
        category: _selectedCategory,
        note: _noteController.text.trim(),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit expense' : 'New expense',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              maxLength: 50,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [amountInputFormatter],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixText: '\$ ',
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<Category>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: Category.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(categoryIcons[category], size: 18),
                          const SizedBox(width: 8),
                          Text(formatCategory(category)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(formatDate(_selectedDate)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _submitExpenseData,
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? 'Update expense' : 'Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData reportIcon(ReportPeriod period) {
  switch (period) {
    case ReportPeriod.daily:
      return Icons.today;
    case ReportPeriod.monthly:
      return Icons.calendar_view_month;
    case ReportPeriod.yearly:
      return Icons.calendar_month;
  }
}

String reportKey(DateTime date, ReportPeriod period) {
  switch (period) {
    case ReportPeriod.daily:
      return '${date.year}-${date.month}-${date.day}';
    case ReportPeriod.monthly:
      return '${date.year}-${date.month}';
    case ReportPeriod.yearly:
      return date.year.toString();
  }
}

String reportLabel(DateTime date, ReportPeriod period) {
  switch (period) {
    case ReportPeriod.daily:
      return formatDate(date);
    case ReportPeriod.monthly:
      return '${monthName(date.month)} ${date.year}';
    case ReportPeriod.yearly:
      return date.year.toString();
  }
}

DateTime reportSortDate(DateTime date, ReportPeriod period) {
  switch (period) {
    case ReportPeriod.daily:
      return DateTime(date.year, date.month, date.day);
    case ReportPeriod.monthly:
      return DateTime(date.year, date.month);
    case ReportPeriod.yearly:
      return DateTime(date.year);
  }
}

String formatCategory(Category category) {
  final name = category.name;
  return '${name[0].toUpperCase()}${name.substring(1)}';
}

String formatCurrency(double amount) {
  return '\$${amount.round()}';
}

String monthName(int month) {
  const names = [
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

  return names[month - 1];
}

String formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day/${date.year}';
}
