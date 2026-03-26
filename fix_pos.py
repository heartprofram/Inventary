import sys
import re

file_path = "lib/features/sales/presentation/screens/pos_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Find the start of _MixedPaymentDialog
start_class1 = content.find("class _MixedPaymentDialog extends ConsumerStatefulWidget {")
if start_class1 != -1:
    # Find the end of _MixedPaymentDialogState
    # It ends right before "  void _showEditPriceDialog"
    end_class = content.find("  void _showEditPriceDialog(BuildContext context, WidgetRef ref, dynamic item) {")
    if end_class != -1:
        extracted = content[start_class1:end_class]
        # Remove it from the current position
        content = content[:start_class1] + content[end_class:]
        # Append it at the very end of the file
        content += "\n" + extracted

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
