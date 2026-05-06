import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/models/new_campaign_state.dart';

/// Step 3: Milestones / Đợt giải ngân.
///
/// UI: ExpansionTile cho mỗi đợt, nested cho categories/items.
/// Tổng mục tiêu tự động tính = sum(quantity × price) tất cả items.
///
/// **Auto-chain dates**: Đợt 1 startDate tự do. Đợt N+1 startDate = Đợt N endDate.
class Step3Milestones extends StatefulWidget {
  final NewCampaignState campaignState;
  final ValueChanged<bool> onValidChanged;

  const Step3Milestones({
    super.key,
    required this.campaignState,
    required this.onValidChanged,
  });

  @override
  State<Step3Milestones> createState() => _Step3MilestonesState();
}

class _Step3MilestonesState extends State<Step3Milestones>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Milestone> get _milestones => widget.campaignState.milestones;

  final _currencyFormat = NumberFormat('#,###', 'vi_VN');
  final _dateFmt = DateFormat('yyyy-MM-dd');

  // ── Color constants (matching design spec) ──────────────────────────
  static const _lockedBg = Color(0xFFF3F4F6); // gray-100
  static const _lockedText = Color(0xFF6B7280); // gray-500
  static const _dateBorder = Color(0xFFD1D5DB); // gray-300
  static const _dateFocus = Color(0xFFEA580C); // orange-600
  static const _errorColor = Color(0xFFEF4444); // red-500
  static const _targetBlue = Color(0xFF1E3A5F); // dark blue

  @override
  void initState() {
    super.initState();
    // Nếu chưa có milestone nào → thêm 1 cái mặc định
    if (_milestones.isEmpty) {
      _milestones.add(Milestone(title: 'Đợt giải ngân 1'));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateAndNotify());
  }

  void _validateAndNotify() {
    bool isValid = _milestones.isNotEmpty;
    for (final ms in _milestones) {
      if (ms.validate().isNotEmpty) {
        isValid = false;
        break;
      }
    }
    widget.onValidChanged(isValid);
  }

  // ── Auto-chain helpers ──────────────────────────────────────────────

  /// Propagate endDate of milestone [msIndex] → startDate of milestone [msIndex+1].
  /// Nếu startDate mới > endDate đợt sau → clear endDate & evidenceDueAt.
  void _propagateEndDate(int msIndex) {
    if (msIndex + 1 >= _milestones.length) return;

    final current = _milestones[msIndex];
    final next = _milestones[msIndex + 1];

    next.startDate = current.endDate;

    // Nếu startDate mới > endDate hiện tại của đợt sau → clear
    if (next.startDate.isNotEmpty && next.endDate.isNotEmpty) {
      final start = DateTime.tryParse(next.startDate);
      final end = DateTime.tryParse(next.endDate);
      if (start != null && end != null && !end.isAfter(start)) {
        next.endDate = '';
        next.evidenceDueAt = '';
        // Tiếp tục propagate nếu đợt sau nữa cũng bị ảnh hưởng
        _propagateEndDate(msIndex + 1);
      }
    }

    // Nếu endDate bị clear → evidenceDate cũng phải clear
    if (next.endDate.isEmpty) {
      next.evidenceDueAt = '';
    }
  }

  /// Re-chain tất cả startDate từ đầu dựa trên endDate đợt trước.
  void _rechainAllDates() {
    for (int i = 1; i < _milestones.length; i++) {
      _milestones[i].startDate = _milestones[i - 1].endDate;

      // Clear nếu startDate > endDate
      if (_milestones[i].startDate.isNotEmpty &&
          _milestones[i].endDate.isNotEmpty) {
        final start = DateTime.tryParse(_milestones[i].startDate);
        final end = DateTime.tryParse(_milestones[i].endDate);
        if (start != null && end != null && !end.isAfter(start)) {
          _milestones[i].endDate = '';
          _milestones[i].evidenceDueAt = '';
        }
      }
      if (_milestones[i].endDate.isEmpty) {
        _milestones[i].evidenceDueAt = '';
      }
    }
  }

  // ── CRUD milestones ─────────────────────────────────────────────────

  void _addMilestone() {
    setState(() {
      final newMs = Milestone(
        title: 'Đợt giải ngân ${_milestones.length + 1}',
      );
      // Auto-chain: startDate = endDate đợt trước
      if (_milestones.isNotEmpty) {
        newMs.startDate = _milestones.last.endDate;
      }
      _milestones.add(newMs);
    });
    _validateAndNotify();
  }

  void _removeMilestone(int index) {
    if (_milestones.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần ít nhất 1 đợt giải ngân')),
      );
      return;
    }
    setState(() {
      _milestones.removeAt(index);
      _rechainAllDates();
    });
    _validateAndNotify();
  }

  void _addCategory(Milestone ms) {
    setState(() {
      ms.categories
          .add(MilestoneCategory(name: 'Danh mục ${ms.categories.length + 1}'));
    });
    _validateAndNotify();
  }

  void _removeCategory(Milestone ms, int catIndex) {
    setState(() => ms.categories.removeAt(catIndex));
    _validateAndNotify();
  }

  void _addItem(MilestoneCategory cat) {
    setState(() {
      cat.items.add(MilestoneCategoryItem());
    });
    _validateAndNotify();
  }

  void _removeItem(MilestoneCategory cat, int itemIndex) {
    setState(() => cat.items.removeAt(itemIndex));
    _validateAndNotify();
  }

  // ── Date picker ─────────────────────────────────────────────────────

  Future<DateTime?> _pickDate({DateTime? initial, DateTime? firstDate}) async {
    final now = DateTime.now();
    final first = firstDate ?? now;
    var initialDate = initial ?? first.add(const Duration(days: 1));
    // Đảm bảo initialDate >= firstDate
    if (initialDate.isBefore(first)) {
      initialDate = first.add(const Duration(days: 1));
    }
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: now.add(const Duration(days: 730)),
      locale: const Locale('vi'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _dateFocus,
                ),
          ),
          child: child!,
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Chọn';
    final dt = DateTime.tryParse(dateStr);
    return dt != null ? DateFormat('dd/MM/yyyy').format(dt) : dateStr;
  }

  /// Lấy danh sách lỗi date cho milestone tại [msIndex].
  List<String> _getDateErrors(int msIndex) {
    final ms = _milestones[msIndex];
    final errors = <String>[];

    if (ms.startDate.isNotEmpty && ms.endDate.isNotEmpty) {
      final start = DateTime.tryParse(ms.startDate);
      final end = DateTime.tryParse(ms.endDate);
      if (start != null && end != null && !end.isAfter(start)) {
        errors.add('Ngày kết thúc phải sau ngày bắt đầu');
      }
    }

    if (ms.endDate.isNotEmpty && ms.evidenceDueAt.isNotEmpty) {
      final end = DateTime.tryParse(ms.endDate);
      final evidence = DateTime.tryParse(ms.evidenceDueAt);
      if (end != null && evidence != null && !evidence.isAfter(end)) {
        errors.add('Hạn nộp minh chứng phải sau ngày kết thúc');
      }
    }

    return errors;
  }

  // ── BUILD ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final totalAmount = widget.campaignState.calculatedTargetAmount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header ────────────────────────────────────────────────
        Text(
          'Đợt giải ngân (Milestones)',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Chia chiến dịch thành các đợt giải ngân để đảm bảo minh bạch.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        // ── Tổng mục tiêu ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng mục tiêu gây quỹ',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '${_currencyFormat.format(totalAmount)} ₫',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_milestones.length} đợt',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Danh sách milestones ──────────────────────────────────
        ...List.generate(_milestones.length, (msIndex) {
          return _buildMilestoneCard(msIndex, theme);
        }),

        // ── Nút thêm đợt ─────────────────────────────────────────
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addMilestone,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Thêm đợt giải ngân'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade700,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildMilestoneCard(int msIndex, ThemeData theme) {
    final ms = _milestones[msIndex];
    final msAmount = ms.calculatedAmount;
    final errors = ms.validate();
    final dateErrors = _getDateErrors(msIndex);
    final isFirstMilestone = msIndex == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              errors.isEmpty ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Text(
            '${msIndex + 1}',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          ms.title.isEmpty ? 'Đợt ${msIndex + 1}' : ms.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_currencyFormat.format(msAmount)} ₫ · ${ms.categories.length} danh mục',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errors.isEmpty)
              Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: () => _removeMilestone(msIndex),
              tooltip: 'Xóa đợt',
            ),
          ],
        ),
        children: [
          // Tên đợt
          TextFormField(
            initialValue: ms.title,
            decoration: _inputDeco('Tên đợt giải ngân *', Icons.label_outline),
            onChanged: (v) {
              ms.title = v;
              setState(() {});
              _validateAndNotify();
            },
          ),
          const SizedBox(height: 12),

          // Mô tả
          TextFormField(
            initialValue: ms.description,
            decoration: _inputDeco('Mô tả (tùy chọn)', Icons.notes_outlined),
            maxLines: 2,
            onChanged: (v) {
              ms.description = v;
              _validateAndNotify();
            },
          ),
          const SizedBox(height: 12),

          // ── Ngày (auto-chain) ─────────────────────────────────
          Row(
            children: [
              // ── startDate ──
              Expanded(
                child: isFirstMilestone
                    ? _buildDateChip(
                        label: 'Bắt đầu',
                        value: _formatDate(ms.startDate),
                        onTap: () async {
                          final d = await _pickDate();
                          if (d != null) {
                            setState(() {
                              ms.startDate = _dateFmt.format(d);
                              // Nếu endDate trước startDate → clear
                              if (ms.endDate.isNotEmpty) {
                                final end = DateTime.tryParse(ms.endDate);
                                if (end != null && !end.isAfter(d)) {
                                  ms.endDate = '';
                                  ms.evidenceDueAt = '';
                                  _propagateEndDate(msIndex);
                                }
                              }
                            });
                            _validateAndNotify();
                          }
                        },
                      )
                    : _buildLockedDateChip(
                        label: 'Bắt đầu',
                        value: _formatDate(ms.startDate),
                      ),
              ),
              const SizedBox(width: 8),

              // ── endDate ──
              Expanded(
                child: _buildDateChip(
                  label: 'Kết thúc',
                  value: _formatDate(ms.endDate),
                  hasError: dateErrors.any((e) => e.contains('kết thúc')),
                  onTap: () async {
                    final firstDate = ms.startDate.isNotEmpty
                        ? DateTime.tryParse(ms.startDate)
                            ?.add(const Duration(days: 1))
                        : null;
                    final d = await _pickDate(firstDate: firstDate);
                    if (d != null) {
                      setState(() {
                        ms.endDate = _dateFmt.format(d);
                        // Nếu evidenceDate trước endDate → clear
                        if (ms.evidenceDueAt.isNotEmpty) {
                          final ev = DateTime.tryParse(ms.evidenceDueAt);
                          if (ev != null && !ev.isAfter(d)) {
                            ms.evidenceDueAt = '';
                          }
                        }
                        // Auto-chain: cập nhật startDate đợt tiếp theo
                        _propagateEndDate(msIndex);
                      });
                      _validateAndNotify();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // ── evidenceDueAt ──
              Expanded(
                child: _buildDateChip(
                  label: 'Nộp MC',
                  value: _formatDate(ms.evidenceDueAt),
                  hasError: dateErrors.any((e) => e.contains('minh chứng')),
                  onTap: () async {
                    final firstDate = ms.endDate.isNotEmpty
                        ? DateTime.tryParse(ms.endDate)
                            ?.add(const Duration(days: 1))
                        : null;
                    final d = await _pickDate(firstDate: firstDate);
                    if (d != null) {
                      setState(() {
                        ms.evidenceDueAt = _dateFmt.format(d);
                      });
                      _validateAndNotify();
                    }
                  },
                ),
              ),
            ],
          ),

          // ── Date errors ───────────────────────────────────────
          if (dateErrors.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...dateErrors.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 14, color: _errorColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          e,
                          style: const TextStyle(
                            color: _errorColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          // ── Auto-chain info badge ─────────────────────────────
          if (!isFirstMilestone && ms.startDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED), // orange-50
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)), // orange-200
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.orange.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ngày bắt đầu tự động nối tiếp từ đợt ${msIndex}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Categories ──────────────────────────────────────────
          Row(
            children: [
              Text(
                'Danh mục chi tiêu',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addCategory(ms),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                ),
              ),
            ],
          ),

          if (ms.categories.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Chưa có danh mục. Nhấn "Thêm" để tạo.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),

          ...List.generate(ms.categories.length, (catIndex) {
            return _buildCategorySection(ms, catIndex, theme);
          }),
        ],
      ),
    );
  }

  Widget _buildCategorySection(Milestone ms, int catIndex, ThemeData theme) {
    final cat = ms.categories[catIndex];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(Icons.folder_outlined, color: Colors.blue.shade400),
        title: Text(
          cat.name.isEmpty ? 'Danh mục ${catIndex + 1}' : cat.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_currencyFormat.format(cat.totalAmount)} ₫ · ${cat.items.length} hạng mục',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
          onPressed: () => _removeCategory(ms, catIndex),
        ),
        children: [
          // Tên danh mục
          TextFormField(
            initialValue: cat.name,
            decoration: _inputDeco('Tên danh mục *', Icons.folder_outlined),
            style: const TextStyle(fontSize: 14),
            onChanged: (v) {
              cat.name = v;
              setState(() {});
              _validateAndNotify();
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: cat.description,
            decoration: _inputDeco('Mô tả danh mục', Icons.notes_outlined),
            style: const TextStyle(fontSize: 14),
            onChanged: (v) {
              cat.description = v;
              _validateAndNotify();
            },
          ),
          const SizedBox(height: 12),

          // Items header
          Row(
            children: [
              Text(
                'Hạng mục chi tiêu',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addItem(cat),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Thêm', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ],
          ),

          if (cat.items.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Chưa có hạng mục',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),

          ...List.generate(cat.items.length, (itemIndex) {
            return _buildItemCard(cat, itemIndex);
          }),
        ],
      ),
    );
  }

  Widget _buildItemCard(MilestoneCategory cat, int itemIndex) {
    final item = cat.items[itemIndex];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                'Hạng mục ${itemIndex + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              if (item.subtotal > 0)
                Text(
                  '${_currencyFormat.format(item.subtotal)} ₫',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _removeItem(cat, itemIndex),
                child: Icon(Icons.remove_circle_outline,
                    size: 18, color: Colors.red.shade400),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tên
          TextFormField(
            initialValue: item.name,
            decoration: _smallInputDeco('Tên hạng mục *'),
            onChanged: (v) {
              item.name = v;
              setState(() {});
              _validateAndNotify();
            },
          ),
          const SizedBox(height: 8),

          // Quantity + Price + Unit row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.expectedQuantity > 0
                      ? item.expectedQuantity.toString()
                      : '',
                  decoration: _smallInputDeco('Số lượng *'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    item.expectedQuantity = int.tryParse(v) ?? 0;
                    setState(() {});
                    _validateAndNotify();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.expectedPrice > 0
                      ? item.expectedPrice.toString()
                      : '',
                  decoration: _smallInputDeco('Đơn giá (₫) *'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    item.expectedPrice = int.tryParse(v) ?? 0;
                    setState(() {});
                    _validateAndNotify();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.expectedUnit,
                  decoration: _smallInputDeco('Đơn vị'),
                  onChanged: (v) {
                    item.expectedUnit = v;
                    _validateAndNotify();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Brand + Purchase Location
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.expectedBrand,
                  decoration: _smallInputDeco('Thương hiệu'),
                  onChanged: (v) {
                    item.expectedBrand = v;
                    _validateAndNotify();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.expectedPurchaseLocation,
                  decoration: _smallInputDeco('Nơi mua'),
                  onChanged: (v) {
                    item.expectedPurchaseLocation = v;
                    _validateAndNotify();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Link + Note
          TextFormField(
            initialValue: item.expectedPurchaseLink,
            decoration: _smallInputDeco('Link tham khảo'),
            onChanged: (v) {
              item.expectedPurchaseLink = v;
              _validateAndNotify();
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: item.expectedNote,
            decoration: _smallInputDeco('Ghi chú'),
            onChanged: (v) {
              item.expectedNote = v;
              _validateAndNotify();
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
    );
  }

  InputDecoration _smallInputDeco(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  /// Date chip cho editable fields.
  Widget _buildDateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool hasError = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasError ? _errorColor : _dateBorder,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: hasError ? _errorColor : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 12,
                    color: hasError ? _errorColor : Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      color: value == 'Chọn'
                          ? Colors.grey.shade400
                          : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Date chip cho locked/readonly fields (auto-chained startDate).
  Widget _buildLockedDateChip({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: _dateBorder),
        borderRadius: BorderRadius.circular(8),
        color: _lockedBg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: _lockedText,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.lock, size: 10, color: _lockedText),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 12, color: _lockedText),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: value == 'Chọn' ? Colors.grey.shade400 : _lockedText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
