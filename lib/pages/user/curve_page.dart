import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../shared/widgets/z_paging_refresh.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/curve_calendar_card.dart';
import 'widgets/curve_detail_card.dart';
import 'widgets/curve_holidays.dart';
import 'widgets/curve_picker_sheet.dart';
import 'widgets/curve_pie_card.dart';
import 'widgets/curve_stats_card.dart';

/// 盈亏分析页 — 1:1 复刻 uni-app pages/user/curve.vue
/// 账本 Tab + 盈亏统计卡 + 盈亏日历(日/月/年) + 盈亏明细TOP5 + 持仓结构饼图
///
/// 平台专有能力（umeng 埋点）未迁移。
class UserCurvePage extends StatefulWidget {
  /// 路由 query 参数 bookId（对齐 uni-app onLoad options.bookId）
  final String? bookId;

  const UserCurvePage({super.key, this.bookId});

  @override
  State<UserCurvePage> createState() => _UserCurvePageState();
}

class _UserCurvePageState extends State<UserCurvePage> {
  static const String _kAllBookId = 'all';
  static const _pieColors = [
    0xFF3D73EB, 0xFFFF9C1C, 0xFF4EB2F0, 0xFFF42A42, 0xFF9033F0,
    0xFFFF5B69, 0xFF07B361, 0xFFFFBE37, 0xFF5D7EF6, 0xFFE85F6F,
    0xFF00B8D9, 0xFFFF6B35, 0xFF8E6FF7, 0xFF2ECC71, 0xFFE74C3C,
    0xFF3498DB, 0xFFF39C12, 0xFF1ABC9C, 0xFF9B59B6, 0xFFE67E22,
    0xFF2980B9, 0xFF27AE60, 0xFFC0392B, 0xFF16A085, 0xFFD35400,
    0xFF8E44AD, 0xFF2C3E50, 0xFFF1C40F, 0xFF7F8C8D, 0xFFE91E63,
  ];

  final ApiClient _api = ApiClient();
  final ScrollController _tabScrollController = ScrollController();
  final List<GlobalKey> _tabKeys = [];

  // ===== 账本 Tab =====
  List<({String name, String bookId})> _tabList = const [(name: '全部', bookId: _kAllBookId)];
  int _tabIndex = 0;
  String _bookId = _kAllBookId;

  // ===== 金额隐藏 =====
  bool _amountHidden = false;

  // ===== 统计卡 =====
  double _totalMarketValue = 0;
  double _principal = 0;
  double _totalProfit = 0;
  double _totalProfitRatio = 0;
  double _todayProfit = 0;
  double _todayProfitRatio = 0;

  // ===== 日历 =====
  CurveCalendarView _view = CurveCalendarView.day;
  bool _showPercent = false;
  late DateTime _pickerDate = _firstOfMonth(DateTime.now()); // monthPickerValue
  late String _monthLabel = '${_pickerDate.year}年${_pickerDate.month}月';
  List<CurveCalendarDay> _days = [];
  int? _selectedDay;
  int? _selectedMonthCard;
  int? _selectedYearCard;
  Map<int, String> _monthlyProfitMap = {};
  Map<int, String> _monthlyRateMap = {};
  Map<int, String> _yearlyProfitMap = {};
  Map<int, String> _yearlyRateMap = {};

  late final List<int> _yearOptions = [
    for (var i = 0; i < 7; i++) DateTime.now().year - 5 + i,
  ];

  // ===== 盈亏明细 =====
  String _detailTab = '盈利TOP5';
  List<CurveDetailItem> _profitList = [];
  List<CurveDetailItem> _lossList = [];
  String _detailTitle = '当日盈亏明细';
  String _selectedProfitDate = '';
  bool _hasAutoSelectedDay = false;

  // ===== 持仓结构 =====
  List<CurvePieDatum> _fundData = [];
  List<CurvePieDatum> _sectorData = [];
  List<CurvePieDatum> _typeData = [];

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  // ==================== 工具 ====================

  String _normBookId(dynamic value) {
    if (value == null || value == '') return _kAllBookId;
    final s = value.toString();
    if (s == _kAllBookId) return _kAllBookId;
    final n = num.tryParse(s);
    if (n == null) return s;
    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  int? get _apiBookId => _bookId == _kAllBookId ? null : int.tryParse(_bookId);

  String _maskAmount(String value) {
    if (value.isEmpty || value == '--') return value;
    return _amountHidden ? '******' : value;
  }

  static double? _toNum(dynamic v) {
    if (v == null) return null;
    final n = num.tryParse(v.toString());
    return n?.toDouble();
  }

  /// changeRate ?? changeRatio ?? profitRate ?? profitRatio ?? rate ?? ratio
  static double? _getChangeRate(Map<String, dynamic> item) {
    for (final k in ['changeRate', 'changeRatio', 'profitRate', 'profitRatio', 'rate', 'ratio']) {
      final n = _toNum(item[k]);
      if (n != null) return n;
    }
    return null;
  }

  /// 接口已返回百分比数值，直接展示；0 / null → ''
  static String _fmtPercentRate(double? rate) {
    if (rate == null || rate == 0) return '';
    return '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%';
  }

  static String _fmtProfitAmount(double amount) {
    if (amount == 0) return '';
    return '${amount >= 0 ? '+' : ''}${amount.toStringAsFixed(2)}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  // ==================== 生命周期 ====================

  @override
  void initState() {
    super.initState();
    // onLoad: applyRouteBookId(options.bookId)
    if (widget.bookId != null && widget.bookId!.isNotEmpty) {
      _bookId = _normBookId(widget.bookId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPageData());
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    await _fetchBookList();
    final now = DateTime.now();
    _monthLabel = '${now.year}年${now.month}月';
    await _fetchCalendarData(now.year, now.month);
    await Future.wait([_fetchDistribution(), _fetchStatsSummary()]);
    if (_selectedProfitDate.isEmpty) {
      await _loadProfitDetail(null);
    }
  }

  // ==================== 账本 ====================

  Future<void> _fetchBookList() async {
    try {
      final res = await _api.get(ApiEndpoints.assetBooks);
      final body = res.data;
      final raw = body is List
          ? body
          : (body is Map && body['data'] is List ? body['data'] as List : const []);
      final books = raw.whereType<Map>().toList();
      final tabs = <({String name, String bookId})>[
        const (name: '全部', bookId: _kAllBookId),
        for (var i = 0; i < books.length; i++)
          (
            name: (books[i]['bookName'] ?? books[i]['name'] ?? '账本${books[i]['bookId'] ?? i}').toString(),
            bookId: _normBookId(books[i]['bookId'] ?? books[i]['id']),
          ),
      ];
      var idx = tabs.indexWhere((t) => t.bookId == _bookId);
      if (idx < 0) {
        idx = 0;
        _bookId = _kAllBookId;
      }
      setState(() {
        _tabList = tabs;
        _tabIndex = idx;
        _syncTabKeys();
      });
    } catch (_) {/* 静默处理 */}
  }

  void _syncTabKeys() {
    while (_tabKeys.length < _tabList.length) {
      _tabKeys.add(GlobalKey());
    }
  }

  void _onBookTabTap(int index) {
    final tab = _tabList[index];
    if (_tabIndex == index && _bookId == tab.bookId) return;
    setState(() {
      _tabIndex = index;
      _bookId = tab.bookId;
      _selectedProfitDate = '';
      _detailTitle = '当日盈亏明细';
      _hasAutoSelectedDay = false;
    });
    final keyCtx = _tabKeys[index].currentContext;
    if (keyCtx != null) {
      Scrollable.ensureVisible(keyCtx, duration: const Duration(milliseconds: 250));
    }
    final now = DateTime.now();
    _fetchCalendarData(now.year, now.month);
    _fetchDistribution();
    _fetchStatsSummary();
  }

  // ==================== 统计 ====================

  Future<void> _fetchStatsSummary() async {
    try {
      final res = await _api.get(
        ApiEndpoints.profitBookProfit,
        queryParameters: _apiBookId != null ? {'bookId': _apiBookId} : null,
      );
      final body = res.data;
      final data = body is Map ? (body['data'] is Map ? body['data'] as Map : body) : const {};
      setState(() {
        _totalMarketValue = _toNum(data['totalMarketValue']) ?? 0;
        _principal = _toNum(data['principal']) ?? 0;
        _totalProfit = _toNum(data['totalProfit']) ?? 0;
        _todayProfit = _toNum(data['profitOfDay']) ?? 0;
        _totalProfitRatio = _toNum(data['totalChangeRate']) ?? 0;
        _todayProfitRatio = _toNum(data['changeRateOfDay']) ?? 0;
      });
    } catch (_) {/* 静默处理 */}
  }

  // ==================== 日历 ====================

  Future<void> _fetchCalendarData(int year, int month) async {
    try {
      final bookIdVal = _apiBookId;
      final res = _bookId == _kAllBookId
          ? await _api.get(ApiEndpoints.profitCalendarAll)
          : await _api.get('${ApiEndpoints.profitCalendarBook}/$bookIdVal');
      final body = res.data;
      final data = body is Map ? (body['data'] is Map ? body['data'] as Map : body) : const {};

      // 月度收益映射
      final monthlyMap = <int, String>{};
      final monthlyRate = <int, String>{};
      final monthly = data['monthly'];
      if (monthly is List) {
        for (final e in monthly.whereType<Map>()) {
          final period = e['period']?.toString() ?? '';
          final parts = period.split('-');
          if (parts.length < 2) continue;
          final m = int.tryParse(parts[1]);
          if (m == null) continue;
          final item = e.cast<String, dynamic>();
          monthlyMap[m] = _fmtProfitAmount(_toNum(item['changeAmount']) ?? 0);
          monthlyRate[m] = _fmtPercentRate(_getChangeRate(item));
        }
      }

      // 年度收益映射
      final yearlyMap = <int, String>{};
      final yearlyRate = <int, String>{};
      final annual = data['annual'];
      if (annual is List) {
        for (final e in annual.whereType<Map>()) {
          final y = int.tryParse(e['period']?.toString() ?? '');
          if (y == null) continue;
          final item = e.cast<String, dynamic>();
          yearlyMap[y] = _fmtProfitAmount(_toNum(item['changeAmount']) ?? 0);
          yearlyRate[y] = _fmtPercentRate(_getChangeRate(item));
        }
      }

      // 日数据映射
      final dailyMap = <String, Map<String, dynamic>>{};
      final daily = data['daily'];
      if (daily is List) {
        for (final e in daily.whereType<Map>()) {
          final dateStr = e['date']?.toString() ?? '';
          if (dateStr.length >= 10) {
            dailyMap[dateStr.substring(0, 10)] = e.cast<String, dynamic>();
          }
        }
      }

      // 生成当月日历格子（跳过周末；法定节假日标"休"）
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final now = DateTime.now();
      final result = <CurveCalendarDay>[];
      for (var d = 1; d <= daysInMonth; d++) {
        final date = DateTime(year, month, d);
        final weekday = date.weekday; // 1=周一 … 7=周日
        if (weekday == DateTime.saturday || weekday == DateTime.sunday) continue;

        final key = '$year-${_two(month)}-${_two(d)}';
        final isClosed = isCurveClosedHoliday(date);
        final isToday = !isClosed && date.year == now.year && date.month == now.month && date.day == now.day;

        final apiItem = dailyMap[key];
        final amount = apiItem != null ? _toNum(apiItem['changeAmount']) : null;
        final rate = apiItem != null ? _getChangeRate(apiItem) : null;

        String type = '';
        if (!isClosed && amount != null) {
          type = amount > 0 ? 'rise' : (amount < 0 ? 'loss' : '');
        }
        result.add(CurveCalendarDay(
          day: d,
          value: isClosed ? '' : (amount != null ? _fmtProfitAmount(amount) : ''),
          percentValue: isClosed ? '' : _fmtPercentRate(rate),
          type: type,
          tag: isClosed ? '休' : '',
          isToday: isToday,
        ));
      }

      // 前置空白格（周一开头）
      var firstWeekday = -1;
      for (var d = 1; d <= daysInMonth; d++) {
        final w = DateTime(year, month, d).weekday;
        if (w != DateTime.saturday && w != DateTime.sunday) {
          firstWeekday = w;
          break;
        }
      }
      final prefixBlanks = firstWeekday > 0 ? firstWeekday - 1 : 0;

      setState(() {
        _monthlyProfitMap = monthlyMap;
        _monthlyRateMap = monthlyRate;
        _yearlyProfitMap = yearlyMap;
        _yearlyRateMap = yearlyRate;
        _selectedDay = null;
        _days = [
          for (var i = 0; i < prefixBlanks; i++) const CurveCalendarDay(),
          ...result,
        ];
      });

      await _selectDefaultDay(year, month);
      if (_view == CurveCalendarView.month) {
        _selectDefaultMonthCard();
      } else if (_view == CurveCalendarView.year) {
        _selectDefaultYearCard();
      }
    } catch (_) {
      setState(() => _days = []);
    }
  }

  List<CurveCalendarDay> get _selectableDays => _days
      .where((d) => d.day != null && (d.type == 'rise' || d.type == 'strong-rise' || d.type == 'loss'))
      .toList();

  Future<void> _selectDefaultDay(int year, int month) async {
    if (_hasAutoSelectedDay || _view != CurveCalendarView.day) return;
    final selectable = _selectableDays;
    if (selectable.isEmpty) return;

    final now = DateTime.now();
    final isCurrentMonth = now.year == year && now.month == month;
    CurveCalendarDay? defaultDay;
    if (isCurrentMonth) {
      for (final d in selectable) {
        if (d.day == now.day) {
          defaultDay = d;
          break;
        }
      }
    }
    defaultDay ??= selectable.last;

    final day = defaultDay;
    final dateStr = '$year-${_two(month)}-${_two(day.day!)}';
    setState(() {
      _selectedDay = day.day;
      _hasAutoSelectedDay = true;
      _selectedProfitDate = dateStr;
      _detailTitle = '$month月${day.day}号盈亏明细';
      _detailTab = day.type == 'loss' ? '亏损TOP5' : '盈利TOP5';
    });
    await _loadProfitDetail(dateStr);
  }

  void _selectDefaultMonthCard() {
    final cells = _buildMonthCells();
    CurveCalendarPeriod? current;
    CurveCalendarPeriod? latest;
    for (final c in cells) {
      if (!c.hasValue) continue;
      if (c.period == _pickerDate.month) current ??= c;
      latest = c;
    }
    setState(() => _selectedMonthCard = (current ?? latest)?.period);
  }

  void _selectDefaultYearCard() {
    final cells = _buildYearCells();
    CurveCalendarPeriod? current;
    CurveCalendarPeriod? latest;
    for (final c in cells) {
      if (!c.hasValue) continue;
      if (c.period == _pickerDate.year) current ??= c;
      latest = c;
    }
    setState(() => _selectedYearCard = (current ?? latest)?.period);
  }

  List<CurveCalendarPeriod> _buildMonthCells() {
    return [
      for (var m = 1; m <= 12; m++)
        CurveCalendarPeriod(
          period: m,
          title: '$m月',
          value: _monthlyProfitMap[m] ?? '',
          percentValue: _monthlyRateMap[m] ?? '',
          type: _periodType(_monthlyProfitMap[m]),
          isActive: (_monthlyProfitMap[m] ?? '').isNotEmpty && m == _selectedMonthCard,
        ),
    ];
  }

  List<CurveCalendarPeriod> _buildYearCells() {
    return [
      for (final y in _yearOptions.take(6))
        CurveCalendarPeriod(
          period: y,
          title: '$y',
          value: _yearlyProfitMap[y] ?? '',
          percentValue: _yearlyRateMap[y] ?? '',
          type: _periodType(_yearlyProfitMap[y]),
          isActive: (_yearlyProfitMap[y] ?? '').isNotEmpty && y == _selectedYearCard,
        ),
    ];
  }

  static String _periodType(String? value) {
    final n = _toNum(value) ?? 0;
    return n < 0 ? 'loss' : (n > 0 ? 'rise' : '');
  }

  // ---- 日历交互 ----

  void _onDayTap(CurveCalendarDay day) async {
    if (day.day == null || day.type.isEmpty) return;
    final dateStr = '${_pickerDate.year}-${_two(_pickerDate.month)}-${_two(day.day!)}';
    setState(() {
      _hasAutoSelectedDay = true;
      _selectedDay = day.day;
      _detailTitle = '${_pickerDate.month}月${day.day}号盈亏明细';
      _selectedProfitDate = dateStr;
    });
    await _loadProfitDetail(dateStr);
  }

  void _onMonthTap(CurveCalendarPeriod cell) {
    if (!cell.hasValue) return;
    if (_selectedMonthCard == cell.period) {
      setState(() => _selectedMonthCard = null);
      return;
    }
    final nextDate = DateTime(_pickerDate.year, cell.period, 1);
    setState(() {
      _selectedMonthCard = cell.period;
      _pickerDate = nextDate;
      _monthLabel = '${nextDate.year}年${nextDate.month}月';
      _selectedDay = null;
      _hasAutoSelectedDay = false;
    });
    _fetchCalendarData(nextDate.year, nextDate.month);
  }

  void _onYearTap(CurveCalendarPeriod cell) {
    if (!cell.hasValue) return;
    if (_selectedYearCard == cell.period) {
      setState(() => _selectedYearCard = null);
      return;
    }
    final nextDate = DateTime(cell.period, _pickerDate.month, 1);
    setState(() {
      _selectedYearCard = cell.period;
      _pickerDate = nextDate;
      _monthLabel = '${nextDate.year}年${nextDate.month}月';
      _selectedDay = null;
      _hasAutoSelectedDay = false;
    });
    _fetchCalendarData(nextDate.year, nextDate.month);
  }

  Future<void> _onViewChange(CurveCalendarView view) async {
    if (_view == view) return;
    setState(() {
      _view = view;
      _selectedMonthCard = null;
      _selectedYearCard = null;
      _detailTitle = '当日盈亏明细';
    });
    if (view == CurveCalendarView.day) {
      _hasAutoSelectedDay = false;
      await _selectDefaultDay(_pickerDate.year, _pickerDate.month);
    } else if (view == CurveCalendarView.month) {
      _selectDefaultMonthCard();
    } else {
      _selectDefaultYearCard();
    }
  }

  Future<void> _openPicker() async {
    if (_view == CurveCalendarView.month) {
      // 年选择器
      final result = await CurvePickerSheet.show(
        context,
        isDark: Theme.of(context).brightness == Brightness.dark,
        yearOptions: _yearOptions,
        withMonth: false,
        initialYear: _pickerDate.year,
      );
      if (result != null) {
        _applyCalendarDate(DateTime(result.$1, _pickerDate.month, 1));
      }
    } else {
      // 年月选择器
      final result = await CurvePickerSheet.show(
        context,
        isDark: Theme.of(context).brightness == Brightness.dark,
        yearOptions: _yearOptions,
        withMonth: true,
        initialYear: _pickerDate.year,
        initialMonth: _pickerDate.month,
      );
      if (result != null) {
        _applyCalendarDate(DateTime(result.$1, result.$2 ?? 1, 1));
      }
    }
  }

  void _applyCalendarDate(DateTime nextDate) {
    setState(() {
      _pickerDate = nextDate;
      _monthLabel = '${nextDate.year}年${nextDate.month}月';
      _selectedDay = null;
      _selectedMonthCard = null;
      _selectedYearCard = null;
      _selectedProfitDate = '';
      _hasAutoSelectedDay = false;
      _detailTitle = '当日盈亏明细';
    });
    _fetchCalendarData(nextDate.year, nextDate.month);
  }

  // ==================== 盈亏明细 ====================

  Future<void> _loadProfitDetail(String? dateStr) async {
    try {
      final res = await _api.get(
        ApiEndpoints.profitDay,
        queryParameters: {
          'date': ?dateStr,
          'bookId': ?_apiBookId,
        },
      );
      final body = res.data;
      final raw = body is List
          ? body
          : (body is Map && body['data'] is List ? body['data'] as List : const []);
      final items = raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      if (items.isEmpty) {
        setState(() {
          _profitList = [];
          _lossList = [];
        });
        return;
      }

      double changeOf(Map<String, dynamic> item) => _toNum(item['changeAmount']) ?? 0;

      final profit = items.where((i) => changeOf(i) > 0).toList()
        ..sort((a, b) => changeOf(b).abs().compareTo(changeOf(a).abs()));
      final loss = items.where((i) => changeOf(i) < 0).toList()
        ..sort((a, b) => changeOf(b).abs().compareTo(changeOf(a).abs()));
      final profitTop = profit.take(5).toList();
      final lossTop = loss.take(5).toList();

      var maxAbs = 1.0;
      for (final i in [...profitTop, ...lossTop]) {
        if (changeOf(i).abs() > maxAbs) maxAbs = changeOf(i).abs();
      }

      CurveDetailItem toItem(Map<String, dynamic> i) => CurveDetailItem(
            name: (i['shortName'] ?? i['name'] ?? '--').toString(),
            value: '${changeOf(i) > 0 ? '+' : ''}${changeOf(i).toStringAsFixed(2)}',
            percentage: (changeOf(i).abs() / maxAbs * 100).round(),
          );

      var nextTab = _detailTab;
      if (profitTop.isNotEmpty && lossTop.isEmpty) {
        nextTab = '盈利TOP5';
      } else if (profitTop.isEmpty && lossTop.isNotEmpty) {
        nextTab = '亏损TOP5';
      } else if (dateStr != null) {
        CurveCalendarDay? selectedDay;
        for (final d in _days) {
          if (d.day == _selectedDay) {
            selectedDay = d;
            break;
          }
        }
        if (selectedDay?.type == 'loss') {
          nextTab = '亏损TOP5';
        } else if (selectedDay?.type == 'rise' || selectedDay?.type == 'strong-rise') {
          nextTab = '盈利TOP5';
        }
      }

      setState(() {
        _profitList = profitTop.map(toItem).toList();
        _lossList = lossTop.map(toItem).toList();
        _detailTab = nextTab;
      });
    } catch (_) {/* 静默处理 */}
  }

  // ==================== 持仓结构 ====================

  Future<void> _fetchDistribution() async {
    try {
      final res = await _api.get(
        ApiEndpoints.profitDistribution,
        queryParameters: _apiBookId != null ? {'bookId': _apiBookId} : null,
      );
      final body = res.data;
      final data = body is Map ? (body['data'] is Map ? body['data'] as Map : body) : const {};

      List<CurvePieDatum> parse(dynamic list) {
        if (list is! List) return [];
        final items = list.whereType<Map>().toList();
        return [
          for (var i = 0; i < items.length; i++)
            CurvePieDatum(
              name: (items[i]['name'] ?? items[i]['key'] ?? '--').toString(),
              valueText: (_toNum(items[i]['ratio']) ?? 0).toStringAsFixed(1),
              value: _toNum(items[i]['ratio']) ?? 0,
              color: Color(_pieColors[i % _pieColors.length]),
            ),
        ];
      }

      setState(() {
        _fundData = parse(data['fundDistribution']);
        _sectorData = parse(data['sectorDistribution']);
        _typeData = parse(data['typeDistribution']);
      });
    } catch (_) {/* 静默处理 */}
  }

  // ==================== 页面跳转 ====================

  void _goToProfitDetail() {
    // uni-app: /pages/user/profit-detail?bookId=${bookId}${date}
    final date = _selectedProfitDate.isNotEmpty ? '&date=$_selectedProfitDate' : '';
    context.push('/user/profit-detail?bookId=$_bookId$date');
  }

  void _goToDistribution(String type) {
    // uni-app: /pages/user/distribution?bookId=${bookId}&type=${type}
    context.push('/user/distribution?bookId=$_bookId&type=$type');
  }

  // ==================== UI ====================

  String get _switchLabel {
    if (_view == CurveCalendarView.day) return _monthLabel;
    if (_view == CurveCalendarView.month) return '${_pickerDate.year}年';
    return '全部';
  }

  String get _footerLabel {
    if (_view == CurveCalendarView.day) return '${_pickerDate.month}月';
    if (_view == CurveCalendarView.month) return '${_pickerDate.year}年';
    return '${_pickerDate.month}月';
  }

  String get _footerValue {
    if (_showPercent) {
      if (_view == CurveCalendarView.year) return _yearlyRateMap[_pickerDate.year] ?? '--';
      return _monthlyRateMap[_pickerDate.month] ?? '--';
    }
    if (_view == CurveCalendarView.year) return _yearlyProfitMap[_pickerDate.year] ?? '--';
    return _monthlyProfitMap[_pickerDate.month] ?? '--';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF1F1F3),
      appBar: CustomNavBar(
        title: '盈亏分析',
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
      ),
      body: Stack(
        children: [
          // 背景图 position-bg.png (100% × 630rpx=315，仅浅色；深色 background-image:none)
          if (!isDark)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 315,
              child: Image.asset(
                'assets/images/img/position-bg.png',
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ZPagingRefresh(
            isDark: isDark,
            onRefresh: _loadPageData,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 15), // pages-nav margin-top 30rpx
                _buildBookTabs(isDark),
                const SizedBox(height: 16), // statistics mt-4
                CurveStatsCard(
                  isDark: isDark,
                  amountHidden: _amountHidden,
                  totalMarketValue: _totalMarketValue,
                  principal: _principal,
                  totalProfit: _totalProfit,
                  totalProfitRatio: _totalProfitRatio,
                  todayProfit: _todayProfit,
                  todayProfitRatio: _todayProfitRatio,
                  onToggleHidden: () => setState(() => _amountHidden = !_amountHidden),
                ),
                CurveCalendarCard(
                  isDark: isDark,
                  showPercent: _showPercent,
                  view: _view,
                  switchLabel: _switchLabel,
                  days: _days,
                  selectedDay: _selectedDay,
                  monthCells: _buildMonthCells(),
                  yearCells: _buildYearCells(),
                  footerLabel: _footerLabel,
                  footerValue: _footerValue,
                  maskAmount: _maskAmount,
                  onToggleMode: () => setState(() => _showPercent = !_showPercent),
                  onViewChange: _onViewChange,
                  onOpenPicker: _openPicker,
                  onDayTap: _onDayTap,
                  onMonthTap: _onMonthTap,
                  onYearTap: _onYearTap,
                ),
                CurveDetailCard(
                  isDark: isDark,
                  title: _detailTitle,
                  activeTab: _detailTab,
                  items: _detailTab == '盈利TOP5' ? _profitList : _lossList,
                  amountHidden: _amountHidden,
                  onTabChange: (tab) {
                    if (_detailTab == tab) return;
                    setState(() => _detailTab = tab);
                  },
                  onShowAll: _goToProfitDetail,
                ),
                CurvePieCard(
                  isDark: isDark,
                  fundData: _fundData,
                  sectorData: _sectorData,
                  typeData: _typeData,
                  onMore: _goToDistribution,
                ),
                const SizedBox(height: 20), // page-content padding-bottom 40rpx
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 账本横向 Tab — `.pages-taber`
  Widget _buildBookTabs(bool isDark) {
    _syncTabKeys();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // mr-4 ml-4
      child: SingleChildScrollView(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _tabList.length; i++)
              GestureDetector(
                key: _tabKeys[i],
                behavior: HitTestBehavior.opaque,
                onTap: () => _onBookTabTap(i),
                child: Container(
                  color: Colors.transparent,
                  padding: EdgeInsets.only(top: 4, bottom: 9, right: i == _tabList.length - 1 ? 0 : 24), // 8rpx 0 18rpx, mr 48rpx
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tabList[i].name,
                        style: AppTextStyles.cn(
                          _tabIndex == i ? 17 : 15, // 34rpx / 30rpx
                          color: _tabIndex == i
                              ? (isDark ? AppColors.darkText : const Color(0xFF452008))
                              : (isDark ? AppColors.darkTextSecondary : const Color(0xFF9A7A61)),
                          weight: _tabIndex == i ? FontWeight.w700 : FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 27, // 54rpx
                        height: 4, // 8rpx
                        decoration: BoxDecoration(
                          color: _tabIndex == i ? (isDark ? AppColors.upColor : AppColors.primary) : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
