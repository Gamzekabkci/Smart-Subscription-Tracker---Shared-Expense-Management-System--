import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/notification_service.dart';
import '../services/db_helper.dart';
import '../models/subscription_model.dart';

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? subscription;

  const AddSubscriptionScreen({super.key, this.subscription});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;

  String _selectedCategory = 'Eğlence';
  DateTime _selectedDate = DateTime.now();
  bool _isTrial = false;
  int _trialDuration = 1;

  bool _isShared = false;
  List<SharedMember> _selectedMembers = [];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.subscription?.name ?? "",
    );

    _priceController = TextEditingController(
      text: widget.subscription != null
          ? widget.subscription!.price.toString()
          : "",
    );

    if (widget.subscription != null) {
      _selectedCategory = widget.subscription!.category;
      _selectedDate = widget.subscription!.billingDate;
      _isTrial = widget.subscription!.isTrial;
      _isShared = widget.subscription!.isShared;
      _selectedMembers = widget.subscription!.sharedMembers;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
      BuildContext context,
      Color primaryColor,
      Color cardColor,
      Color textColor,
      ) async {
    final theme = Theme.of(context);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: primaryColor,
              onPrimary:
              theme.brightness == Brightness.dark ? Colors.black : Colors.white,
              surface: cardColor,
              onSurface: textColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _openContactSelector() async {
    final result = await Navigator.push<List<SharedMember>>(
      context,
      MaterialPageRoute(
        builder: (context) => ContactSelectionScreen(
          initiallySelectedMembers: _selectedMembers,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedMembers = result;
      });
    }
  }

  Future<void> _saveSubscription() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı oturumu bulunamadı. Lütfen tekrar giriş yapın.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uid = currentUser.uid;

    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim().replaceAll(',', '.');

    if (name.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm alanları doldurun!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final parsedPrice = double.tryParse(priceText);

    if (parsedPrice == null || parsedPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir ücret girin!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isShared && _selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ortak abonelik için rehberden en az 1 kişi seçmelisin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DateTime finalDate = _selectedDate;

    if (_isTrial && widget.subscription == null) {
      final now = DateTime.now();
      finalDate = DateTime(now.year, now.month + _trialDuration, now.day);
    }

    try {
      final abonelikVerisi = Subscription(
        id: widget.subscription?.id,
        userId: uid,
        name: name,
        price: parsedPrice,
        category: _selectedCategory,
        billingDate: finalDate,
        currency: 'TL',
        isShared: _isShared,
        isTrial: _isTrial,
        personCount: _isShared ? _selectedMembers.length + 1 : 1,
        packageName: "",
        sharedMembersJson:
        _isShared ? Subscription.encodeMembers(_selectedMembers) : null,
      );

      if (widget.subscription == null) {
        await DbHelper.instance.insertSubscription(abonelikVerisi);
      } else {
        await DbHelper.instance.updateSubscription(abonelikVerisi);
      }
      await NotificationService.instance.rescheduleAll();
      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.subscription != null;

    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.colorScheme.surface;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = theme.colorScheme.primary;
    final buttonTextColor =
    theme.brightness == Brightness.dark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Aboneliği Düzenle' : 'Yeni Abonelik',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? "Mevcut Abonelik Bilgileri" : "Abonelik Detayları",
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 20),

            _buildTextField(
              _nameController,
              'Abonelik Adı',
              Icons.subscriptions_outlined,
              primaryColor,
              cardColor,
              textColor,
            ),

            const SizedBox(height: 20),

            _buildTextField(
              _priceController,
              'Aylık Ücret (TL)',
              Icons.payments_outlined,
              primaryColor,
              cardColor,
              textColor,
              isNumber: true,
            ),

            const SizedBox(height: 20),

            const Text(
              "Kategori",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: textColor.withValues(alpha: 0.1)),
              ),
              child: DropdownButton<String>(
                value: _selectedCategory,
                dropdownColor: cardColor,
                isExpanded: true,
                underline: const SizedBox(),
                style: TextStyle(color: textColor, fontSize: 16),
                items: <String>[
                  'Eğlence',
                  'Yazılım',
                  'Eğitim',
                  'Spor',
                  'Diğer',
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _selectedCategory = val);
                },
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Ödeme / Bitiş Tarihi",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 8),

            InkWell(
              onTap: () => _selectDate(
                context,
                primaryColor,
                cardColor,
                textColor,
              ),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: textColor.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                    Icon(Icons.calendar_month, color: primaryColor),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            SwitchListTile(
              title: Text(
                "Ücretsiz Deneme Süresi",
                style: TextStyle(color: textColor, fontSize: 16),
              ),
              subtitle: const Text(
                "Ücret çekilmeden önce hatırlatıcı oluşturur",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              value: _isTrial,
              activeThumbColor: primaryColor,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _isTrial = val),
            ),

            if (_isTrial && !isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Deneme Süresi Kaç Ay?",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: DropdownButton<int>(
                        value: _trialDuration,
                        dropdownColor: cardColor,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: TextStyle(color: textColor, fontSize: 16),
                        icon: Icon(
                          Icons.arrow_drop_down_circle_outlined,
                          color: primaryColor,
                        ),
                        items: [1, 2, 3, 6, 12].map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text("$value Ay Ücretsiz Kullanım"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _trialDuration = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            SwitchListTile(
              title: Text(
                "Ortak Abonelik",
                style: TextStyle(color: textColor, fontSize: 16),
              ),
              subtitle: const Text(
                "Bu aboneliği başkalarıyla paylaşıyorum",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              value: _isShared,
              activeThumbColor: primaryColor,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  _isShared = val;
                  if (!val) {
                    _selectedMembers.clear();
                  }
                });
              },
            ),

            if (_isShared) _buildSelectedMembersSection(cardColor, textColor, primaryColor),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _saveSubscription,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 8,
              ),
              child: Text(
                isEditing ? 'DEĞİŞİKLİKLERİ KAYDET' : 'SİSTEME EKLE',
                style: TextStyle(
                  color: buttonTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedMembersSection(
      Color cardColor,
      Color textColor,
      Color primaryColor,
      ) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ortak Kullanıcılar",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),

          const SizedBox(height: 10),

          InkWell(
            onTap: _openContactSelector,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.contacts_rounded, color: primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedMembers.isEmpty
                          ? "Rehberden kişi seç"
                          : "${_selectedMembers.length} kişi seçildi",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: primaryColor, size: 16),
                ],
              ),
            ),
          ),

          if (_selectedMembers.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._selectedMembers.map(
                  (member) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                      child: Text(
                        member.name.isNotEmpty ? member.name[0].toUpperCase() : "?",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        member.name,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedMembers.removeWhere(
                                (item) => item.phone == member.phone,
                          );
                        });
                      },
                      icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon,
      Color primaryColor,
      Color cardColor,
      Color textColor, {
        bool isNumber = false,
      }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: primaryColor),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: cardColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}


class ContactSelectionScreen extends StatefulWidget {
  final List<SharedMember> initiallySelectedMembers;

  const ContactSelectionScreen({
    super.key,
    required this.initiallySelectedMembers,
  });

  @override
  State<ContactSelectionScreen> createState() => _ContactSelectionScreenState();
}

class _ContactSelectionScreenState extends State<ContactSelectionScreen> {
  bool _isLoading = true;
  List<Contact> _contacts = [];
  final Map<String, SharedMember> _selectedMembers = {};

  @override
  void initState() {
    super.initState();

    for (final member in widget.initiallySelectedMembers) {
      _selectedMembers[member.phone] = member;
    }

    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    if (status != PermissionStatus.granted) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Rehber izni verilmedi."),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.name,
        ContactProperty.phone,
      },
    );

    contacts.removeWhere((contact) => contact.phones.isEmpty);

    contacts.sort((a, b) {
      final aName = a.displayName ?? "";
      final bName = b.displayName ?? "";
      return aName.compareTo(bName);
    });

    if (!mounted) return;

    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });
  }

  String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  SharedMember _memberFromContact(Contact contact) {
    final rawPhone = contact.phones.isNotEmpty
        ? contact.phones.first.number
        : "";

    final cleanPhone = _cleanPhone(rawPhone);
    final displayName = contact.displayName ?? "";

    return SharedMember(
      name: displayName.isNotEmpty ? displayName : cleanPhone,
      phone: cleanPhone,
    );
  }

  void _toggleContact(Contact contact) {
    final member = _memberFromContact(contact);

    if (member.phone.isEmpty) return;

    setState(() {
      if (_selectedMembers.containsKey(member.phone)) {
        _selectedMembers.remove(member.phone);
      } else {
        _selectedMembers[member.phone] = member;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = theme.colorScheme.primary;
    final cardColor = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Rehberden Kişi Seç",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedMembers.values.toList());
            },
            child: Text(
              "Tamam",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(color: primaryColor),
      )
          : _contacts.isEmpty
          ? const Center(
        child: Text(
          "Telefon numarası olan kişi bulunamadı.",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          final member = _memberFromContact(contact);
          final isSelected =
          _selectedMembers.containsKey(member.phone);

          final displayName = contact.displayName ?? "";

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              onTap: () => _toggleContact(contact),
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? primaryColor
                    : Colors.grey.withValues(alpha: 0.2),
                child: Text(
                  displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : "?",
                  style: TextStyle(
                    color: isSelected ? Colors.black : textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                displayName.isNotEmpty
                    ? displayName
                    : "İsimsiz Kişi",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                member.phone,
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: isSelected ? primaryColor : Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }
}