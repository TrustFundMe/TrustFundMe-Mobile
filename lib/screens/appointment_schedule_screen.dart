import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api/api_service.dart';
import '../core/models/appointment_model.dart';
import '../core/providers/auth_provider.dart';

class AppointmentScheduleScreen extends StatefulWidget {
  const AppointmentScheduleScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentScheduleScreen> createState() => _AppointmentScheduleScreenState();
}

class _AppointmentScheduleScreenState extends State<AppointmentScheduleScreen> {
  final ApiService _api = ApiService();
  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  String removeDiacritics(String str) {
    const withDia = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDia = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    String result = str;
    for (int i = 0; i < withDia.length; i++) {
        result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  List<AppointmentModel> get _filteredAppointments {
    return _appointments.where((apt) {
      final query = removeDiacritics(_searchQuery).toLowerCase();
      final purposeStr = removeDiacritics(apt.purpose ?? '').toLowerCase();
      final locationStr = removeDiacritics(apt.location ?? '').toLowerCase();
      final staffStr = removeDiacritics(apt.staffName ?? '').toLowerCase();

      final matchesSearch = query.isEmpty || 
        purposeStr.contains(query) ||
        locationStr.contains(query) ||
        staffStr.contains(query);
        
      final matchesStatus = _selectedStatus == 'ALL' || apt.status.toUpperCase() == _selectedStatus.toUpperCase();
      return matchesSearch && matchesStatus;
    }).toList();
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) {
        setState(() => _errorMessage = "Bạn cần đăng nhập để xem lịch hẹn.");
        return;
      }
      final res = await _api.getAppointmentsByDonor(user.id);
      if (res.statusCode == 200) {
        final List<dynamic> data = res.data;
        if (mounted) {
          setState(() {
            _appointments = data.map((x) => AppointmentModel.fromJson(x)).toList();
            // Sort by start time descending
            _appointments.sort((a, b) {
              if (a.startTime == null || b.startTime == null) return 0;
              return b.startTime!.compareTo(a.startTime!);
            });
          });
        }
      } else {
        if (mounted) {
          setState(() => _errorMessage = "Lỗi hệ thống (${res.statusCode})");
        }
      }
    } catch (e) {
      debugPrint("Error loading appointments: $e");
      if (mounted) {
        setState(() => _errorMessage = "Không thể tải danh sách lịch hẹn.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'COMPLETED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Chờ xác nhận';
      case 'CONFIRMED':
        return 'Đã xác nhận';
      case 'CANCELLED':
        return 'Đã hủy';
      case 'COMPLETED':
        return 'Hoàn thành';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "Lịch hẹn của tôi",
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F2937), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAppointments,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: "Tìm kiếm mục đích, địa điểm...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Tất cả'),
                _buildFilterChip('PENDING', 'Chờ xác nhận'),
                _buildFilterChip('CONFIRMED', 'Đã xác nhận'),
                _buildFilterChip('COMPLETED', 'Hoàn thành'),
                _buildFilterChip('CANCELLED', 'Đã hủy'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String statusValue, String label) {
    final bool isSelected = _selectedStatus == statusValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedStatus = statusValue);
        },
        selectedColor: const Color(0xFFF84D43).withOpacity(0.15),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? const Color(0xFFF84D43) : Colors.grey.shade300,
        ),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFFF84D43) : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAppointments,
              child: const Text("Thử lại"),
            )
          ],
        ),
      );
    }
    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              "Bạn chưa có lịch hẹn nào.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              "Các lịch hẹn với nhân viên sẽ xuất hiện tại đây.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    final items = _filteredAppointments;
    if (items.isEmpty && _appointments.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              "Không tìm thấy lịch hẹn phù hợp.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final apt = items[index];
        return _buildAppointmentCard(apt);
      },
    );
  }

  Widget _buildAppointmentCard(AppointmentModel apt) {
    final bool hasTime = apt.startTime != null && apt.endTime != null;
    final String dateStr = hasTime ? DateFormat('dd/MM/yyyy').format(apt.startTime!) : 'Chưa xếp lịch';
    final String timeStr = hasTime
        ? '${DateFormat('HH:mm').format(apt.startTime!)} - ${DateFormat('HH:mm').format(apt.endTime!)}'
        : '--:--';

    return InkWell(
      onTap: () => _showAppointmentDetails(context, apt),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(apt.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(apt.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(apt.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (apt.purpose != null && apt.purpose!.isNotEmpty)
            Row(
              children: [
                Icon(Icons.description_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    apt.purpose!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (apt.location != null && apt.location!.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    apt.location!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text(
                "Xem chi tiết",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF84D43),
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFFF84D43))
            ],
          )
        ],
      ),
      ),
    );
  }

  void _showAppointmentDetails(BuildContext context, AppointmentModel apt) {
    final bool hasTime = apt.startTime != null && apt.endTime != null;
    final String dateStr = hasTime ? DateFormat('dd/MM/yyyy').format(apt.startTime!) : 'Chưa xếp lịch';
    final String timeStr = hasTime ? '${DateFormat('HH:mm').format(apt.startTime!)} - ${DateFormat('HH:mm').format(apt.endTime!)}' : '--:--';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo (Swipe indicator)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text(
                "Chi tiết lịch hẹn",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 16),
              _buildDetailRow("Trạng thái", _getStatusText(apt.status), color: _getStatusColor(apt.status)),
              _buildDetailRow("Ngày hẹn", dateStr),
              _buildDetailRow("Giờ", timeStr),
              if (apt.staffName != null) _buildDetailRow("Nhân viên tư vấn", apt.staffName!),
              if (apt.location != null && apt.location!.isNotEmpty) _buildDetailRow("Hình thức / Địa chỉ", apt.location!),
              if (apt.purpose != null && apt.purpose!.isNotEmpty) _buildDetailRow("Mục đích", apt.purpose!),
              _buildDetailRow("Tạo lúc", apt.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(apt.createdAt!) : '--/--/----'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF84D43),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Đóng", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color ?? const Color(0xFF1F2937),
                fontWeight: color != null ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
