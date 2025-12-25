import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendrail_worker_app/features/history/history_screen.dart';
import 'package:spendrail_worker_app/l10n/app_localizations.dart';
import 'package:spendrail_worker_app/models/transaction_model.dart';
import 'package:spendrail_worker_app/services/analytics_service.dart';
import 'package:spendrail_worker_app/theme.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('analytics')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: transactionsAsync.when(
          data: (transactions) {
            final analyticsService = AnalyticsService();
            final analytics = analyticsService.calculateAnalytics(transactions);

            if (analytics.transactionCount == 0) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                    SizedBox(height: AppSpacing.md),
                    Text('No data available', style: context.textStyles.titleMedium?.semiBold),
                    SizedBox(height: AppSpacing.sm),
                    Text('Complete some transactions to see analytics', style: context.textStyles.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: AppSpacing.paddingLg,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.translate('total_spent'), style: context.textStyles.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  SizedBox(height: AppSpacing.xs),
                                  Text('₹${analytics.totalSpent.toStringAsFixed(2)}', style: context.textStyles.headlineMedium?.bold?.copyWith(color: theme.colorScheme.primary)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.account_balance_wallet, size: 32, color: theme.colorScheme.primary),
                              ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.md),
                          Divider(),
                          SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  context,
                                  'Transactions',
                                  analytics.transactionCount.toString(),
                                  Icons.receipt_long,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  context,
                                  'Average',
                                  '₹${(analytics.totalSpent / analytics.transactionCount).toStringAsFixed(2)}',
                                  Icons.trending_up,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl),
                  Text(l10n.translate('spending_by_category'), style: context.textStyles.titleLarge?.semiBold),
                  SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: AppSpacing.paddingLg,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: SpendingPieChart(
                              spendingByCategory: analytics.spendingByCategory,
                              analyticsService: analyticsService,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xl),
                          ...analytics.spendingByCategory.entries.map((entry) {
                            final percentage = (entry.value / analytics.totalSpent * 100).toStringAsFixed(1);
                            return Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.md),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: analyticsService.getCategoryColor(entry.key),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(entry.key.name.toUpperCase(), style: context.textStyles.bodyMedium?.semiBold),
                                  ),
                                  Text('$percentage%', style: context.textStyles.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  SizedBox(width: AppSpacing.md),
                                  Text('₹${entry.value.toStringAsFixed(2)}', style: context.textStyles.bodyMedium?.bold),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: ${e.toString()}')),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.secondary, size: 24),
        SizedBox(height: AppSpacing.sm),
        Text(value, style: context.textStyles.titleMedium?.bold),
        SizedBox(height: AppSpacing.xs),
        Text(label, style: context.textStyles.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class SpendingPieChart extends StatefulWidget {
  final Map<TransactionCategory, double> spendingByCategory;
  final AnalyticsService analyticsService;

  const SpendingPieChart({
    super.key,
    required this.spendingByCategory,
    required this.analyticsService,
  });

  @override
  State<SpendingPieChart> createState() => _SpendingPieChartState();
}

class _SpendingPieChartState extends State<SpendingPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.spendingByCategory.values.fold<double>(0, (sum, val) => sum + val);

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 50,
        sections: widget.spendingByCategory.entries.toList().asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value.key;
          final amount = entry.value.value;
          final isTouched = index == _touchedIndex;
          final radius = isTouched ? 70.0 : 60.0;
          final fontSize = isTouched ? 16.0 : 14.0;

          return PieChartSectionData(
            color: widget.analyticsService.getCategoryColor(category),
            value: amount,
            title: '${(amount / total * 100).toStringAsFixed(1)}%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
}
