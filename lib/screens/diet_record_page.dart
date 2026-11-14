import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'record_detail_page.dart';
import 'record_presentation.dart';
import 'meal_slots.dart';
import 'health_insights.dart';

class DietRecordPage extends StatefulWidget {
  final String petId;
  final String petName;

  const DietRecordPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<DietRecordPage> createState() => _DietRecordPageState();
}

class _DietRecordPageState extends State<DietRecordPage> {
  static const Color _green = Color(0xFF1F5B46);
  static const Color _buttonGreen = Color(0xFF2F765A);
  static const Color _border = Color(0xFFE1EBE6);
  static const Color _hint = Color(0xFFA5B8B0);

  final _brandController = TextEditingController();
  final _foodNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _supplementController = TextEditingController();
  final _noteController = TextEditingController();
  final _scrollController = ScrollController();

  DateTime _recordDate = DateTime.now();
  TimeOfDay _mealTime = TimeOfDay.now();
  String _mealType = '早餐';
  String _unit = '公克 (g)';
  String _appetite = '正常';
  String _waterStatus = '正常';
  double _finishedRatio = 75;
  bool _changedFood = false;
  bool _vomited = false;
  bool _isSaving = false;
  String? _aiAnalysis;
  static const _units = ['公克 (g)', '毫升 (ml)', '罐', '包', '份'];
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _favoriteStream;

  @override
  void initState() {
    super.initState();
    _favoriteStream = FirebaseFirestore.instance
        .collection('pets').doc(widget.petId).snapshots();
  }

  String _amountText(dynamic value) {
    if (value is! num) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  void _applyFavorite(Map<String, dynamic> favorite) {
    setState(() {
      _brandController.text = (favorite['brand'] ?? '').toString();
      _foodNameController.text = (favorite['foodName'] ?? '').toString();
      _amountController.text = _amountText(favorite['amount']);
      final unit = (favorite['unit'] ?? '').toString();
      _unit = _units.contains(unit) ? unit : _units.first;
    });
  }

  void _resetAfterSave() {
    _brandController.clear();
    _foodNameController.clear();
    _amountController.clear();
    _supplementController.clear();
    _noteController.clear();
    setState(() {
      _recordDate = DateTime.now();
      _mealTime = TimeOfDay.now();
      _mealType = '早餐';
      _unit = _units.first;
      _appetite = '正常';
      _waterStatus = '正常';
      _finishedRatio = 75;
      _changedFood = false;
      _vomited = false;
      _aiAnalysis = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut);
    }
  }

  Future<void> _editFavorite([Map<String, dynamic>? existing]) async {
    final brand = TextEditingController(
      text: (existing?['brand'] ?? _brandController.text).toString(),
    );
    final food = TextEditingController(
      text: (existing?['foodName'] ?? _foodNameController.text).toString(),
    );
    final amount = TextEditingController(
      text: existing == null
          ? _amountController.text
          : _amountText(existing['amount']),
    );
    var unit = (existing?['unit'] ?? _unit).toString();
    if (!_units.contains(unit)) unit = _units.first;
    var saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            title: Text(existing == null ? '新增常用餐點' : '修改常用餐點'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: brand,
                    decoration: const InputDecoration(labelText: '品牌（選填）'),
                  ),
                  TextField(
                    controller: food,
                    decoration: const InputDecoration(labelText: '食物名稱'),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '預設份量（選填）'),
                  ),
                  DropdownButtonFormField<String>(
                    value: unit,
                    decoration: const InputDecoration(labelText: '單位'),
                    items: _units
                        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => updateDialog(() => unit = value ?? _units.first),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: saving ? null : () async {
                  final name = food.text.trim();
                  final rawAmount = amount.text.trim();
                  final parsed = rawAmount.isEmpty ? null : double.tryParse(rawAmount);
                  if (name.isEmpty || (rawAmount.isNotEmpty &&
                      (parsed == null || !parsed.isFinite || parsed <= 0))) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請填食物名稱；份量若有填，須大於 0')),
                    );
                    return;
                  }
                  updateDialog(() => saving = true);
                  try {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) throw StateError('請先登入');
                    final petRef = FirebaseFirestore.instance
                        .collection('pets').doc(widget.petId);
                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                      final pet = await transaction.get(petRef);
                      if (!pet.exists || pet.data()?['owner_uid'] != uid) {
                        throw StateError('無法存取此寵物的常用餐點');
                      }
                      final favorites = (pet.data()?['favoriteMeals'] as List? ?? [])
                          .whereType<Map>()
                          .map((item) => Map<String, dynamic>.from(item))
                          .toList();
                      final id = (existing?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString();
                      final updated = <String, dynamic>{
                        'id': id,
                        'brand': brand.text.trim(),
                        'foodName': name,
                        'amount': parsed,
                        'unit': unit,
                      };
                      final index = favorites.indexWhere((item) => item['id'] == id);
                      if (existing != null && index < 0) {
                        throw StateError('常用餐點已被刪除，請重新整理');
                      }
                      if (index >= 0) {
                        favorites[index] = updated;
                      } else {
                        if (favorites.length >= 20) throw StateError('最多可儲存 20 筆常用餐點');
                        favorites.add(updated);
                      }
                      transaction.update(petRef, {'favoriteMeals': favorites});
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('儲存常用餐點失敗：$error')),
                      );
                    }
                    if (dialogContext.mounted) updateDialog(() => saving = false);
                  }
                },
                child: const Text('儲存'),
              ),
            ],
          ),
        ),
      );
    } finally {
      brand.dispose();
      food.dispose();
      amount.dispose();
    }
  }

  Future<void> _deleteFavorite(Map<String, dynamic> favorite) async {
    final name = (favorite['foodName'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除常用餐點？'),
        content: Text('刪除「$name」？已存的飲食紀錄不會受影響。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('請先登入');
      final petRef = FirebaseFirestore.instance.collection('pets').doc(widget.petId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final pet = await transaction.get(petRef);
        if (!pet.exists || pet.data()?['owner_uid'] != uid) {
          throw StateError('無法存取此寵物的常用餐點');
        }
        final favorites = (pet.data()?['favoriteMeals'] as List? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['id'] != favorite['id'])
            .toList();
        transaction.update(petRef, {'favoriteMeals': favorites});
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除常用餐點失敗：$error')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _recordDate = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _mealTime,
    );
    if (selected != null) setState(() => _mealTime = selected);
  }

  String get _dateText =>
      '${_recordDate.year}-${_recordDate.month.toString().padLeft(2, '0')}-${_recordDate.day.toString().padLeft(2, '0')}';

  String _makeLocalAnalysis() {
    final warnings = <String>[];
    if (_appetite == '不佳') warnings.add('食慾不佳');
    if (_waterStatus == '不足') warnings.add('飲水量不足');
    if (_finishedRatio < 40) warnings.add('進食完成比例偏低');
    if (_changedFood) warnings.add('本次有更換食物');
    if (_vomited) warnings.add('進食後出現嘔吐');

    if (warnings.isEmpty) {
      return '根據本次紀錄，${widget.petName}的進食與飲水狀況大致正常。建議持續維持固定餵食時間，並觀察食慾與精神狀態。';
    }
    return '根據本次紀錄，發現${warnings.join('、')}。建議先補充飲水並持續觀察；若嘔吐、拒食或精神不佳持續超過 24 小時，請諮詢獸醫。';
  }

  Future<void> _saveRecord() async {
    if (_isSaving) return;
    final rawAmount = _amountController.text.trim();
    final amount = rawAmount.isEmpty ? null : double.tryParse(rawAmount);
    if (rawAmount.isNotEmpty && (amount == null || amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('若填寫份量，請輸入大於 0 的數字')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final recordDateTime = DateTime(
        _recordDate.year,
        _recordDate.month,
        _recordDate.day,
        _mealTime.hour,
        _mealTime.minute,
      );

      final records = FirebaseFirestore.instance.collection('health_records');
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('請先登入');
      final pet = await FirebaseFirestore.instance.collection('pets').doc(widget.petId).get();
      if (pet.data()?['owner_uid'] != uid) throw StateError('沒有新增紀錄的權限');
      if (MealSlots.isFixed(_mealType)) {
        // 舊紀錄使用隨機 ID，先查詢同日餐別；固定 ID 在下方交易中再檢查一次。
        final existing = await records.where('petId', isEqualTo: widget.petId).get();
        final duplicate = existing.docs.any((doc) {
          final data = doc.data();
          if (HealthInsights.type(data) != 'diet') return false;
          final value = data['recordDate'] ?? data['createdAt'];
          final date = value is Timestamp ? value.toDate()
              : DateTime.tryParse(value?.toString() ?? '');
          return date != null && MealSlots.sameDay(date, recordDateTime) &&
              MealSlots.normalize(data['mealType']) == _mealType;
        });
        if (duplicate) {
          throw StateError('$_dateText 的 $_mealType 已記錄。請到「歷史紀錄」點開該筆修改；點心可新增多筆。');
        }
      }
      final data = <String, dynamic>{
        'petId': widget.petId,
        'petName': widget.petName,
        'recordType': 'diet',
        // 保留舊欄位，避免健康存摺原本的讀取程式失效。
        'foodType': _foodNameController.text.trim(),
        'amount': amount,
        'unit': _unit,
        'note': _noteController.text.trim(),
        // 新版飲食紀錄欄位。
        'recordDate': Timestamp.fromDate(recordDateTime),
        'mealType': _mealType,
        'brand': _brandController.text.trim(),
        'foodName': _foodNameController.text.trim(),
        'supplement': _supplementController.text.trim(),
        'appetite': _appetite,
        'waterStatus': _waterStatus,
        'finishedRatio': _finishedRatio.round(),
        'changedFood': _changedFood,
        'vomited': _vomited,
        'createdAt': FieldValue.serverTimestamp(),
        'owner_uid': uid,
      };
      if (MealSlots.isFixed(_mealType)) {
        // 固定文件 ID + 交易讓兩台裝置同時新增也只能成功一次。
        final slot = records.doc('diet_${widget.petId}_${MealSlots.dateKey(recordDateTime)}_$_mealType');
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          if ((await transaction.get(slot)).exists) {
            throw StateError('$_dateText 的 $_mealType 已記錄，請到歷史紀錄修改。');
          }
          transaction.set(slot, data);
        });
      } else {
        await records.add(data);
      }

      if (!mounted) return;
      final reminder = _makeLocalAnalysis();
      _resetAfterSave();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('飲食紀錄已儲存。$reminder'),
            duration: const Duration(seconds: 6)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .68,
        child: Column(
          children: [
            const Text('飲食紀錄歷史',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _green)),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('health_records')
                    .where('petId', isEqualTo: widget.petId)
                    .where('recordType', isEqualTo: 'diet')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('讀取紀錄失敗'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final aDate = (a.data()['recordDate'] ?? a.data()['createdAt']) as Timestamp?;
                      final bDate = (b.data()['recordDate'] ?? b.data()['createdAt']) as Timestamp?;
                      return (bDate?.millisecondsSinceEpoch ?? 0)
                          .compareTo(aDate?.millisecondsSinceEpoch ?? 0);
                    });
                  if (docs.isEmpty) return const Center(child: Text('目前沒有飲食紀錄'));
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final timestamp = (data['recordDate'] ?? data['createdAt']) as Timestamp?;
                      final date = timestamp?.toDate();
                      final dateText = date == null
                          ? '日期未記錄'
                          : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      return ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RecordDetailPage(reference: doc.reference,
                            petId: widget.petId))),
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEAF4EC),
                          child: Icon(Icons.restaurant, color: _green),
                        ),
                        title: Text(RecordPresentation.title(data)),
                        subtitle: Text('$dateText ・ ${RecordPresentation.subtitle(data)}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _brandController.dispose();
    _foodNameController.dispose();
    _amountController.dispose();
    _supplementController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('飲食紀錄',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _green)),
            ),
            IconButton(
              tooltip: '歷史紀錄',
              onPressed: _showHistory,
              icon: const Icon(Icons.history, color: _green, size: 30),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _label('紀錄日期'),
        _tapField(_dateText, Icons.calendar_month_outlined, _pickDate),
        const SizedBox(height: 24),
        _label('進食時間'),
        _tapField(_mealTime.format(context), Icons.keyboard_arrow_down, _pickTime),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 300,
            child: _dropDown(
              label: '餐點類型',
              value: _mealType,
              items: MealSlots.choices,
              onChanged: (value) => setState(() => _mealType = value!),
            ),
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('health_records')
              .where('petId', isEqualTo: widget.petId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('無法檢查當天餐別；儲存前仍會再次確認');
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final filled = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
            for (final doc in snapshot.data!.docs) {
              final data = doc.data();
              if (HealthInsights.type(data) != 'diet') continue;
              final value = data['recordDate'] ?? data['createdAt'];
              final day = value is Timestamp ? value.toDate()
                  : DateTime.tryParse(value?.toString() ?? '');
              final slot = MealSlots.normalize(data['mealType']);
              if (day != null && MealSlots.sameDay(day, _recordDate) &&
                  MealSlots.isFixed(slot)) filled[slot] = doc;
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final slot in MealSlots.fixed)
                  ActionChip(
                    avatar: Icon(filled.containsKey(slot)
                        ? Icons.check_circle : Icons.add_circle_outline, size: 18),
                    label: Text('$slot${filled.containsKey(slot) ? ' 已填' : ' 未填'}'),
                    onPressed: filled[slot] == null ? () => setState(() => _mealType = slot)
                        : () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => RecordDetailPage(
                                reference: filled[slot]!.reference, petId: widget.petId))),
                  ),
              ]),
              const Text('早餐／午餐／晚餐每天各一筆；點心可多筆。已填餐別請點開修改。',
                  style: TextStyle(color: _green, fontSize: 13)),
            ]);
          },
        ),
        const SizedBox(height: 28),
        _label('常用餐點'),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _favoriteStream,
          builder: (context, snapshot) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) return const Text('請先登入以使用常用餐點');
            if (snapshot.hasError) return const Text('讀取常用餐點失敗，仍可手動填寫');
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final data = snapshot.data!.data();
            if (data == null || data['owner_uid'] != uid) {
              return const Text('無法讀取此寵物的常用餐點');
            }
            final favorites = (data['favoriteMeals'] as List? ?? [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (favorites.isEmpty)
                  const Text('尚未設定。可在下方填寫餐點，再按「加入常用」。',
                      style: TextStyle(color: _green)),
                for (final favorite in favorites)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.star, color: _buttonGreen),
                      title: Text('${favorite['brand'] ?? ''} ${favorite['foodName'] ?? ''}'.trim()),
                      subtitle: Text(favorite['amount'] is num
                          ? '預設 ${_amountText(favorite['amount'])} ${favorite['unit'] ?? _units.first}'
                          : '份量可於本餐填寫'),
                      onTap: () => _applyFavorite(favorite),
                      trailing: PopupMenuButton<String>(
                        tooltip: '管理常用餐點',
                        onSelected: (action) {
                          if (action == 'edit') {
                            _editFavorite(favorite);
                          } else {
                            _deleteFavorite(favorite);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('修改')),
                          PopupMenuItem(value: 'delete', child: Text('刪除')),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: favorites.length >= 20 ? null : () => _editFavorite(),
                  icon: const Icon(Icons.add),
                  label: const Text('加入常用餐點'),
                ),
                const Text('點選常用餐點即可帶入；本餐份量仍可修改。',
                    style: TextStyle(fontSize: 13, color: _green)),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _input('食物品牌（選填）', _brandController, '例如：皇家')),
            const SizedBox(width: 16),
            Expanded(child: _input('食物名稱（選填）', _foodNameController, '例如：犬糧A')),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _input('本餐份量（選填）', _amountController, '例如：50',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _dropDown(
                label: '單位',
                value: _unit,
                items: const ['公克 (g)', '毫升 (ml)', '罐', '包', '份'],
                onChanged: (value) => setState(() => _unit = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _input('補充品', _supplementController, '例如：魚油、化毛膏'),
        const SizedBox(height: 28),
        _label('食慾與飲水'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _dropDown(
                label: '食慾',
                value: _appetite,
                items: const ['良好', '正常', '不佳'],
                onChanged: (value) => setState(() => _appetite = value!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _dropDown(
                label: '飲水狀況',
                value: _waterStatus,
                items: const ['充足', '正常', '不足'],
                onChanged: (value) => setState(() => _waterStatus = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _label('吃完比例'),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _buttonGreen,
                  inactiveTrackColor: _border,
                  thumbColor: _buttonGreen,
                  overlayColor: _buttonGreen.withOpacity(.12),
                  trackHeight: 6,
                ),
                child: Slider(
                  value: _finishedRatio,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_finishedRatio.round()}%',
                  onChanged: (value) => setState(() => _finishedRatio = value),
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('幾乎沒吃', style: TextStyle(color: _green)), Text('全部吃完', style: TextStyle(color: _green))],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _switchCard('是否更換食物', '本次飲食與上次品牌或類型不同', _changedFood,
                (value) => setState(() => _changedFood = value)),
        const SizedBox(height: 20),
        _switchCard('是否有嘔吐', '進食後是否有異常', _vomited,
                (value) => setState(() => _vomited = value)),
        const SizedBox(height: 28),
        _input('補充說明', _noteController, '記錄任何關於飲食的細節...', maxLines: 3),
        const SizedBox(height: 28),
        SizedBox(
          height: 62,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveRecord,
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonGreen,
              disabledBackgroundColor: _buttonGreen.withOpacity(.55),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: _isSaving
                ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Text('儲存紀錄', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
        ),
        if (_aiAnalysis != null) ...[
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              border: Border.all(color: const Color(0xFFD2E8B9)),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _buttonGreen,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.auto_awesome),
                    ),
                    SizedBox(width: 12),
                    Text('AI 營養分析', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _buttonGreen)),
                  ],
                ),
                const SizedBox(height: 20),
                Text(_aiAnalysis!, style: const TextStyle(fontSize: 16, height: 1.75, color: _green)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _green)),
  );

  Widget _tapField(String text, IconData icon, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(28),
    onTap: onTap,
    child: Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: _fieldDecoration(28),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 18, color: _green))),
          Icon(icon, color: _buttonGreen),
        ],
      ),
    ),
  );

  Widget _input(String label, TextEditingController controller, String hint,
      {TextInputType? keyboardType, int maxLines = 1,
      ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _hint),
            prefixIcon: const Icon(Icons.edit_note_rounded, color: _green),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _buttonGreen, width: 1.8)),
          ),
        ),
      ],
    );
  }

  Widget _dropDown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: _buttonGreen),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: _buttonGreen, width: 1.8)),
          ),
        ),
      ],
    );
  }

  Widget _switchCard(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => Container(
    padding: const EdgeInsets.fromLTRB(20, 22, 12, 22),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, color: _green)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: _buttonGreen)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: Colors.white, activeTrackColor: _buttonGreen, inactiveTrackColor: _border),
      ],
    ),
  );

  BoxDecoration _fieldDecoration(double radius) => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _border),
    borderRadius: BorderRadius.circular(radius),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _border),
    borderRadius: BorderRadius.circular(28),
  );
}

