import 'package:hive_flutter/hive_flutter.dart';

/// Central Hive box manager for offline data.
/// Boxes:
///   - portfolio_cache:     property + unit data
///   - contacts_cache:       tenant + landlord contacts
///   - reports_cache:        financial report snapshots
///   - message_outbox:       pending chat messages
///   - operation_queue:      pending building operations
///   - transaction_queue:    pending financial transactions
///   - meta:                 cache timestamps, sync state
class OfflineStorage {
  static const String _boxPortfolio = 'portfolio_cache';
  static const String _boxContacts = 'contacts_cache';
  static const String _boxReports = 'reports_cache';
  static const String _boxMediaCache = 'media_cache';       // ✅ EKLENDI — PRD §5.1
  static const String _boxOutbox = 'message_outbox';
  static const String _boxOpQueue = 'operation_queue';
  static const String _boxTxQueue = 'transaction_queue';
  static const String _boxMeta = 'meta';

  static final OfflineStorage _instance = OfflineStorage._internal();
  factory OfflineStorage() => _instance;
  OfflineStorage._internal();

  late Box<Map> _portfolioBox;
  late Box<Map> _contactsBox;
  late Box<Map> _reportsBox;
  late Box<Map> _mediaCacheBox;                             // ✅ EKLENDI
  late Box<Map> _outboxBox;
  late Box<Map> _opQueueBox;
  late Box<Map> _txQueueBox;
  late Box<dynamic> _metaBox;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await Hive.initFlutter();

    _portfolioBox = await Hive.openBox<Map>(_boxPortfolio);
    _contactsBox = await Hive.openBox<Map>(_boxContacts);
    _reportsBox = await Hive.openBox<Map>(_boxReports);
    _mediaCacheBox = await Hive.openBox<Map>(_boxMediaCache);  // ✅ EKLENDI
    _outboxBox = await Hive.openBox<Map>(_boxOutbox);
    _opQueueBox = await Hive.openBox<Map>(_boxOpQueue);
    _txQueueBox = await Hive.openBox<Map>(_boxTxQueue);
    _metaBox = await Hive.openBox<Map>(_boxMeta);

    _initialized = true;
  }

  // ─── Portfolio Cache ──────────────────────────────────────────

  Box<Map> get portfolioBox => _portfolioBox;
  Box<Map> get contactsBox => _contactsBox;
  Box<Map> get reportsBox => _reportsBox;
  Box<Map> get mediaCacheBox => _mediaCacheBox;              // ✅ EKLENDI
  Box<Map> get outboxBox => _outboxBox;
  Box<Map> get opQueueBox => _opQueueBox;
  Box<Map> get txQueueBox => _txQueueBox;
  Box<dynamic> get metaBox => _metaBox;

  Future<void> cachePortfolio(String key, Map<String, dynamic> data) async {
    await _portfolioBox.put(key, data);
    await _metaBox.put('portfolio_ts', DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? getPortfolio(String key) {
    final val = _portfolioBox.get(key);
    if (val == null) return null;
    return Map<String, dynamic>.from(val);
  }

  List<Map<String, dynamic>> getAllPortfolio() {
    return _portfolioBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> clearPortfolio() async {
    await _portfolioBox.clear();
  }

  Future<void> invalidatePortfolio() async {
    await _portfolioBox.clear();
    await _metaBox.delete('portfolio_ts');
  }

  // ─── Contacts Cache ──────────────────────────────────────────

  Future<void> cacheContact(String key, Map<String, dynamic> data) async {
    await _contactsBox.put(key, data);
    await _metaBox.put('contacts_ts', DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? getContact(String key) {
    final val = _contactsBox.get(key);
    if (val == null) return null;
    return Map<String, dynamic>.from(val);
  }

  List<Map<String, dynamic>> getAllContacts() {
    return _contactsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> clearContacts() async {
    await _contactsBox.clear();
  }

  // ─── Reports Cache ──────────────────────────────────────────

  Future<void> cacheReport(String key, Map<String, dynamic> data) async {
    await _reportsBox.put(key, data);
    await _metaBox.put('reports_ts', DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? getReport(String key) {
    final val = _reportsBox.get(key);
    if (val == null) return null;
    return Map<String, dynamic>.from(val);
  }

  List<Map<String, dynamic>> getAllReports() {
    return _reportsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ─── Media Cache — PRD §5.1 ─────────────────────────────────
  // Sadece daha önce açılmış medya önbellekte saklanır (cache-first)
  // Not: Bu,tam bir offline medya indirme sistemi DEĞİLDİR —
  // sadece ön belleğe alınmış medya URL'lerini kaydeder.

  Future<void> cacheMedia(String url, Map<String, dynamic> metadata) async {
    await _mediaCacheBox.put(url, metadata);
    await _metaBox.put('media_cache_ts', DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? getCachedMedia(String url) {
    final val = _mediaCacheBox.get(url);
    if (val == null) return null;
    return Map<String, dynamic>.from(val);
  }

  bool isMediaCached(String url) => _mediaCacheBox.containsKey(url);

  Future<void> clearMediaCache() async {
    await _mediaCacheBox.clear();
    await _metaBox.delete('media_cache_ts');
  }

  int get mediaCacheCount => _mediaCacheBox.length;

  // ─── Meta ──────────────────────────────────────────────────

  DateTime? getPortfolioCacheTime() {
    final ts = _metaBox.get('portfolio_ts') as String?;
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  DateTime? getContactsCacheTime() {
    final ts = _metaBox.get('contacts_ts') as String?;
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  DateTime? getReportsCacheTime() {
    final ts = _metaBox.get('reports_ts') as String?;
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  // ─── Outbox (Chat Messages) ─────────────────────────────────

  Future<void> addToOutbox(String id, Map<String, dynamic> msg) async {
    await _outboxBox.put(id, msg);
  }

  Map<String, dynamic>? getOutboxMessage(String id) {
    final val = _outboxBox.get(id);
    if (val == null) return null;
    return Map<String, dynamic>.from(val);
  }

  List<Map<String, dynamic>> getAllOutboxMessages() {
    return _outboxBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> removeFromOutbox(String id) async {
    await _outboxBox.delete(id);
  }

  int get outboxCount => _outboxBox.length;

  // ─── Operation Queue ────────────────────────────────────────

  Future<void> addToOpQueue(String id, Map<String, dynamic> op) async {
    await _opQueueBox.put(id, op);
  }

  List<Map<String, dynamic>> getAllOpQueue() {
    return _opQueueBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> removeFromOpQueue(String id) async {
    await _opQueueBox.delete(id);
  }

  int get opQueueCount => _opQueueBox.length;

  // ─── Transaction Queue ──────────────────────────────────────

  Future<void> addToTxQueue(String id, Map<String, dynamic> tx) async {
    await _txQueueBox.put(id, tx);
  }

  List<Map<String, dynamic>> getAllTxQueue() {
    return _txQueueBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> removeFromTxQueue(String id) async {
    await _txQueueBox.delete(id);
  }

  int get txQueueCount => _txQueueBox.length;

  /// Returns total pending items across all queues.
  int get totalPendingCount => outboxCount + opQueueCount + txQueueCount;
}
