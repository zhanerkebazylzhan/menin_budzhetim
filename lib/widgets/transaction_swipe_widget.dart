import 'package:flutter/material.dart';
import '../models/transaction.dart';

/// Виджет с swipe действиями для транзакции
class TransactionSwipeWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Transaction transaction;

  const TransactionSwipeWidget({
    super.key,
    required this.child,
    required this.onDelete,
    required this.onEdit,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('transaction_${transaction.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe влево - удаление
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удалить операцию?'),
              content: Text(
                'Вы уверены, что хотите удалить операцию "${transaction.description}"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Удалить'),
                ),
              ],
            ),
          );
          
          if (confirmed == true) {
            onDelete();
          }
          return false; // Не убираем виджет автоматически
        } else {
          // Swipe вправо - редактирование
          onEdit();
          return false;
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.blue.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Редактировать',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Удалить',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      child: child,
    );
  }
}