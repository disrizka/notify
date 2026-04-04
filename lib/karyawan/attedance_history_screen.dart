import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

const _kPrimary = Color(0xFF1565C0);
const _kPrimaryMd = Color(0xFF1976D2);
const _kPrimaryLt = Color(0xFF42A5F5);
const _kAccent = Color(0xFF0D47A1);
const _kBg = Color(0xFFF0F4FF);
const _kCard = Colors.white;
const _kText = Color(0xFF0D1B3E);
const _kSub = Color(0xFF8A99B5);
const _kGreen = Color(0xFF00897B);
const _kAmber = Color(0xFFF57C00);
const _kRed = Color(0xFFE53935);
const _kGray = Color(0xFF9CA3AF);

class AttendanceRecord {
  final int id;
  final String date;
  final String? checkIn;
  final String? checkOut;
  final String isApproved;
  final String isApprovedOut;
  final String? notes;
  final String? notesOut;

  AttendanceRecord({
    required this.id,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.isApproved,
    required this.isApprovedOut,
    this.notes,
    this.notesOut,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'],
      date: json['date'] ?? '',
      checkIn: json['check_in'],
      checkOut: json['check_out'],
      isApproved: json['is_approved'] ?? 'pending',
      isApprovedOut: json['is_approved_out'] ?? 'pending',
      notes: json['notes'],
      notesOut: json['notes_out'],
    );
  }

  bool get isFullyPresent =>
      checkOut != null &&
      isApproved == 'approved' &&
      isApprovedOut == 'approved';

  bool get isBelumCheckOut => isApproved == 'approved' && checkOut == null;

  String get workDuration {
    if (checkIn == null || checkOut == null) return '-';
    try {
      final inParts = checkIn!.split(':');
      final outParts = checkOut!.split(':');
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final diff = outMin - inMin;
      if (diff <= 0) return '-';
      final h = diff ~/ 60;
      final m = diff % 60;
      return h > 0 ? '${h}j ${m}m' : '${m}m';
    } catch (_) {
      return '-';
    }
  }

  String get checkInShort => _shortTime(checkIn);
  String get checkOutShort => _shortTime(checkOut);

  String _shortTime(String? t) {
    if (t == null) return '--:--';
    return t.length >= 5 ? t.substring(0, 5) : t;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();

  List<AttendanceRecord> _allRecords = [];
  List<AttendanceRecord> _filtered = [];
  bool _isLoading = true;
  String? _error;

  String _selectedStatus = 'semua';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _fetchHistory();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────
  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _animController.reset();
    try {
      final token = await _storage.read(key: 'auth_token');
      final uri = Uri.parse(
        '${Api.baseUrl}/api/presence/history'
        '?month=$_selectedMonth&year=$_selectedYear',
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _allRecords = data.map((e) => AttendanceRecord.fromJson(e)).toList();
        _applyFilter();
        _animController.forward();
      } else {
        setState(() => _error = 'Gagal memuat data (${response.statusCode})');
      }
    } catch (_) {
      setState(() => _error = 'Tidak dapat terhubung ke server');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered =
          _selectedStatus == 'semua'
              ? List.from(_allRecords)
              : _allRecords
                  .where((r) => r.isApproved == _selectedStatus)
                  .toList();
    });
  }

  int get _totalHadir =>
      _allRecords
          .where((r) => r.isApproved == 'approved' && r.checkOut != null)
          .length;
  int get _totalBelumOut =>
      _allRecords
          .where((r) => r.isApproved == 'approved' && r.checkOut == null)
          .length;
  int get _totalPending =>
      _allRecords.where((r) => r.isApproved == 'pending').length;
  int get _totalDitolak =>
      _allRecords.where((r) => r.isApproved == 'rejected').length;

  void _pickMonthYear() {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setModalState) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Text(
                        'Pilih Bulan & Tahun',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _YearButton(
                            icon: Icons.chevron_left_rounded,
                            onTap: () => setModalState(() => tempYear--),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              '$tempYear',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _kPrimary,
                              ),
                            ),
                          ),
                          _YearButton(
                            icon: Icons.chevron_right_rounded,
                            onTap: () => setModalState(() => tempYear++),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.8,
                            ),
                        itemCount: 12,
                        itemBuilder: (_, i) {
                          final selected = i + 1 == tempMonth;
                          return GestureDetector(
                            onTap: () => setModalState(() => tempMonth = i + 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color:
                                    selected
                                        ? _kPrimary
                                        : _kPrimary.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  _months[i].substring(0, 3),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? Colors.white : _kText,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _kPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedMonth = tempMonth;
                              _selectedYear = tempYear;
                            });
                            _fetchHistory();
                          },
                          child: const Text(
                            'Tampilkan',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildStatsRow()),
          SliverToBoxAdapter(child: _buildFilterRow()),
          if (_isLoading)
            const SliverFillRemaining(child: _LoadingState())
          else if (_error != null)
            SliverFillRemaining(
              child: _ErrorState(message: _error!, onRetry: _fetchHistory),
            )
          else if (_filtered.isEmpty)
            const SliverFillRemaining(child: _EmptyState())
          else
            _buildList(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: _kPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _fetchHistory,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kAccent, _kPrimary, _kPrimaryMd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            22,
            MediaQuery.of(context).padding.top + 56,
            22,
            16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Riwayat Absensi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_months[_selectedMonth - 1]} $_selectedYear',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _pickMonthYear,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Ganti Bulan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Hadir',
              value: _totalHadir,
              color: _kGreen,
              icon: Icons.check_circle_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Blm Checkout',
              value: _totalBelumOut,
              color: _kPrimary,
              icon: Icons.exit_to_app_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Pending',
              value: _totalPending,
              color: _kAmber,
              icon: Icons.hourglass_top_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Ditolak',
              value: _totalDitolak,
              color: _kRed,
              icon: Icons.cancel_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    const statusList = [
      ('semua', 'Semua'),
      ('approved', 'Disetujui'),
      ('pending', 'Pending'),
      ('rejected', 'Ditolak'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              statusList.map((s) {
                final active = _selectedStatus == s.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedStatus = s.$1);
                      _applyFilter();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _kPrimary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? _kPrimary : Colors.grey.shade200,
                        ),
                        boxShadow:
                            active
                                ? [
                                  BoxShadow(
                                    color: _kPrimary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                                : [],
                      ),
                      child: Text(
                        s.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : _kSub,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((_, i) {
        final record = _filtered[i];
        return FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.05 * (i + 1).clamp(1, 5).toDouble()),
              end: Offset.zero,
            ).animate(_fadeAnim),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _AttendanceCard(record: record),
            ),
          ),
        );
      }, childCount: _filtered.length),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;
  const _AttendanceCard({required this.record});

  Color get _statusInColor => _statusColor(record.isApproved);
  IconData get _statusInIcon => _statusIcon(record.isApproved);
  String get _statusInLabel => _statusLabel(record.isApproved);

  Color get _statusOutColor =>
      record.checkOut == null ? _kGray : _statusColor(record.isApprovedOut);
  IconData get _statusOutIcon =>
      record.checkOut == null
          ? Icons.schedule_rounded
          : _statusIcon(record.isApprovedOut);
  String get _statusOutLabel =>
      record.checkOut == null
          ? 'Belum Checkout'
          : _statusLabel(record.isApprovedOut);

  static Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return _kGreen;
      case 'rejected':
        return _kRed;
      default:
        return _kAmber;
    }
  }

  static IconData _statusIcon(String s) {
    switch (s) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 24),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(color: _kPrimary.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${DateTime.tryParse(record.date)?.day ?? '--'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _kPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatDate(record.date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _TimeInfo(
                    icon: Icons.login_rounded,
                    label: 'Masuk',
                    time: record.checkInShort,
                    color: _kPrimary,
                    hasValue: record.checkIn != null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: _kSub.withOpacity(0.5),
                      ),
                      if (record.workDuration != '-') ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _kPrimary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            record.workDuration,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _kPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _TimeInfo(
                    icon: Icons.logout_rounded,
                    label: 'Pulang',
                    time: record.checkOutShort,
                    color: _kGreen,
                    hasValue: record.checkOut != null,
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                // Status IN
                Expanded(
                  child: _StatusChip(
                    label: 'Status IN',
                    value: _statusInLabel,
                    color: _statusInColor,
                    icon: _statusInIcon,
                  ),
                ),
                const SizedBox(width: 8),
                // Status OUT
                Expanded(
                  child: _StatusChip(
                    label: 'Status OUT',
                    value: _statusOutLabel,
                    color: _statusOutColor,
                    icon: _statusOutIcon,
                  ),
                ),
              ],
            ),
          ),

          if (record.notes != null && record.notes!.isNotEmpty)
            _NotesRow(
              icon: Icons.login_rounded,
              iconColor: _kPrimary,
              label: 'Ket. Masuk',
              text: record.notes!,
              isLast: record.notesOut == null || record.notesOut!.isEmpty,
            ),

          if (record.notesOut != null && record.notesOut!.isNotEmpty)
            _NotesRow(
              icon: Icons.logout_rounded,
              iconColor: _kGreen,
              label: 'Ket. Pulang',
              text: record.notesOut!,
              isLast: true,
            ),

          if ((record.notes == null || record.notes!.isEmpty) &&
              (record.notesOut == null || record.notesOut!.isEmpty))
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: _kSub,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
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

class _NotesRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String text;
  final bool isLast;

  const _NotesRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.text,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: _kSub),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;
  final bool hasValue;
  final bool alignRight;

  const _TimeInfo({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
    required this.hasValue,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!alignRight) ...[
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: _kSub,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (alignRight) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 11, color: color),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(
          time,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: hasValue ? _kText : _kSub,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _kSub,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _YearButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _YearButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _kPrimary, size: 20),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: _kPrimary, strokeWidth: 3),
        SizedBox(height: 14),
        Text(
          'Memuat riwayat absensi...',
          style: TextStyle(color: _kSub, fontSize: 13),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, size: 36, color: _kRed),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: _kText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kPrimary.withOpacity(0.1),
                  _kPrimaryLt.withOpacity(0.08),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 40,
              color: _kPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada data absensi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Belum ada catatan absensi\npada periode ini',
            style: TextStyle(fontSize: 13, color: _kSub),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
