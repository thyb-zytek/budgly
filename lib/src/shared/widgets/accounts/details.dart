import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/shared/widgets/accounts/default.dart';
import 'package:budgly/src/shared/widgets/inputs/dropdown.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AccountDetails extends StatefulWidget {
  final Account selectedAccount;
  final List<Account> accounts;
  final void Function(Account) onChangeAccount;
  final double incomes;
  final double outcomes;
  final double available;
  final List<Category> categories;
  final bool isExpanded;

  const AccountDetails({
    super.key,
    required this.selectedAccount,
    required this.onChangeAccount,
    required this.accounts,
    required this.incomes,
    required this.outcomes,
    required this.available,
    required this.categories,
    this.isExpanded = false,
  });

  @override
  State<AccountDetails> createState() => _AccountDetailsState();
}

class _AccountDetailsState extends State<AccountDetails>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    if (widget.isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(AccountDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: '€',
      decimalDigits: 0,
      locale: 'fr_FR',
    );

    // Hardcoded values as requested for initial build
    const double totalRevenues = 3100;
    const double totalExpenses = 2988;
    const double restAmount = 112;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        spacing: 8,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          DropDown<Account>(
            initialValue: widget.selectedAccount,
            onSelect: widget.onChangeAccount,
            options: widget.accounts,
            optionBuilder:
                (account, isSelected) => Container(
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8).copyWith(right: 80),
                  child: AccountView(account: account),
                ),
          ),
          SizeTransition(
            sizeFactor: _fadeAnimation,
            alignment: Alignment.topCenter,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: SizedBox(
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 120,
                            startDegreeOffset: 180,
                            sections: [
                              PieChartSectionData(
                                value: 1200,
                                color: const Color(0xFF6463D6),
                                radius: 40,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: 150,
                                color: const Color(0xFFF062B0),
                                radius: 40,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: 600,
                                color: const Color(0xFFFFA857),
                                radius: 40,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: 1038,
                                color: const Color(0xFF2DFF71),
                                radius: 40,
                                showTitle: false,
                              ),
                              // Remaining available space
                              PieChartSectionData(
                                value:
                                    totalRevenues - (1200 + 150 + 600 + 1038),
                                color: Colors.transparent,
                                radius: 0,
                                showTitle: false,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Revenus',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currencyFormat.format(totalRevenues),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Reste',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              currencyFormat.format(restAmount),
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dépenses',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              currencyFormat.format(totalExpenses),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
