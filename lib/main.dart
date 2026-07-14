import 'package:flutter/material.dart';
// import 'expense.dart'; // Import your model here


enum Category { food, transport, leisure, work }

class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final Category category;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
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
      title: 'Expense Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
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
  // Sample initial data
  final List<Expense> _registeredExpenses = [
    Expense(id: 'e1', title: 'Groceries', amount: 45.50, date: DateTime.now(), category: Category.food),
    Expense(id: 'e2', title: 'Bus Fair', amount: 3.20, date: DateTime.now(), category: Category.transport),
  ];

  // Calculated property for the header total
  double get _totalExpenses {
    return _registeredExpenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  // Opens a slide-up sheet to enter new expense details
  void _openAddExpenseOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Prevents keyboard from overlapping inputs
      builder: (ctx) => NewExpenseModal(onAddExpense: _addExpense),
    );
  }

  void _addExpense(Expense expense) {
    setState(() {
      _registeredExpenses.add(expense);
    });
  }

  void _deleteExpense(Expense expense) {
    setState(() {
      _registeredExpenses.remove(expense);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddExpenseOverlay,
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Sum Card
          Card(
            margin: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Spent:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('\$${_totalExpenses.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          // Expense List (Swipe to delete)
          Expanded(
            child: _registeredExpenses.isEmpty
                ? const Center(child: Text('No expenses recorded yet. Add some!'))
                : ListView.builder(
                    itemCount: _registeredExpenses.length,
                    itemBuilder: (ctx, index) {
                      final expense = _registeredExpenses[index];
                      return Dismissible(
                        key: ValueKey(expense.id),
                        background: Container(
                          color: Colors.red.withAlpha(200),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.right(20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) => _deleteExpense(expense),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(_getCategoryIcon(expense.category)),
                            ),
                            title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${expense.date.month}/${expense.date.day}/${expense.date.year}'),
                            trailing: Text('\$${expense.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(Category category) {
    switch (category) {
      case Category.food: return Icons.fastfood;
      case Category.transport: return Icons.directions_bus;
      case Category.leisure: return Icons.movie;
      case Category.work: return Icons.work;
    }
  }
}

// Separate widget handling form inputs
class NewExpenseModal extends StatefulWidget {
  final void Function(Expense expense) onAddExpense;

  const NewExpenseModal({super.key, required this.onAddExpense});

  @override
  State<NewExpenseModal> createState() => _NewExpenseModalState();
}

class _NewExpenseModalState extends State<NewExpenseModal> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  Category _selectedCategory = Category.food;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submitExpenseData() {
    final enteredAmount = double.tryParse(_amountController.text);
    final amountIsValid = enteredAmount != null && enteredAmount > 0;

    if (_titleController.text.trim().isEmpty || !amountIsValid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invalid Input'),
          content: const Text('Please check your title and amount entry.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay')),
          ],
        ),
      );
      return;
    }

    widget.onAddExpense(
      Expense(
        id: DateTime.now().toString(),
        title: _titleController.text,
        amount: enteredAmount,
        date: DateTime.now(),
        category: _selectedCategory,
      ),
    );
    Navigator.pop(context); // Close sheet
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 48, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            maxLength: 50,
            decoration: const InputDecoration(label: Text('Item Name')),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: '\$ ', label: Text('Amount')),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<Category>(
                value: _selectedCategory,
                items: Category.values.map((category) => DropdownMenuItem(
                  value: category,
                  child: Text(category.name.toUpperCase()),
                )).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedCategory = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(onPressed: _submitExpenseData, child: const Text('Save Expense')),
            ],
          ),
        ],
      ),
    );
  }
}