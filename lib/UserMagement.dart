
import 'package:flutter/material.dart';
import 'package:gom_tss/user_model.dart';
import 'ApiServes/UsersApi.dart';

class AdminUsersScreen extends StatefulWidget {
  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService apiService = ApiService();
  late Future<List<User>> _usersFuture;
  TextEditingController _searchController = TextEditingController();
  List<User> _filteredUsers = [];
  List<User> _allUsers = [];
  bool _isSearching = false;
  FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshUsers() {
    setState(() {
      _usersFuture = apiService.getUsers().then((users) {
        _allUsers = users;
        _filteredUsers = users;
        return users;
      });
    });
  }

  void _searchUsers(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((user) {
          return user.name.toLowerCase().contains(query.toLowerCase()) ||
              user.badgeNumber.contains(query) ||
              user.department.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
      _filteredUsers = _allUsers;
      _searchFocusNode.unfocus();
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_searchFocusNode);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "ابحث باسم أو رقم البادج...",
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(Icons.close, size: 20),
              onPressed: _clearSearch,
              color: Colors.white,
            ),
          ),
          style: TextStyle(color: Colors.white, fontSize: 16),
          onChanged: _searchUsers,
        )
            : Row(
          children: [
            Icon(Icons.radio, color: Colors.blue[50]),
            SizedBox(width: 10),
            Text(
              "المستخدمين",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[800],
        elevation: 4,
        actions: [
          if (_isSearching)
            IconButton(
              icon: Icon(Icons.clear_all, color: Colors.white),
              onPressed: _clearSearch,
              tooltip: "إلغاء البحث",
            )
          else
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: _startSearch,
              tooltip: "بحث",
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshUsers,
            tooltip: "تحديث القائمة",
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_isSearching) {
            _clearSearch();
            return false;
          }
          return true;
        },
        child: FutureBuilder<List<User>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 15),
                    Text(
                      "جاري تحميل بيانات المستخدمين...",
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group,
                      size: 80,
                      color: Colors.blue[200],
                    ),
                    SizedBox(height: 20),
                    Text(
                      "لا يوجد مستخدمين",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "انقر على + لإضافة مستخدم جديد",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            final usersToShow = _isSearching ? _filteredUsers : snapshot.data!;

            if (_isSearching && usersToShow.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: Colors.blue[200],
                    ),
                    SizedBox(height: 20),
                    Text(
                      "لم يتم العثور على نتائج",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "حاول البحث باسم آخر أو رقم بادج مختلف",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _clearSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text("عرض جميع المستخدمين"),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // شريط نتائج البحث
                if (_isSearching && usersToShow.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(12),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.blue[700], size: 20),
                        SizedBox(width: 8),
                        Text(
                          "تم العثور على ${usersToShow.length} نتيجة",
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        TextButton(
                          onPressed: _clearSearch,
                          child: Text(
                            "مسح البحث",
                            style: TextStyle(color: Colors.blue[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: usersToShow.length,
                    itemBuilder: (context, index) {
                      final user = usersToShow[index];
                      Color deptColor = Colors.blue;

                      // تخصيص لون حسب القسم
                      switch (user.department) {
                        case 'الاتصالات':
                          deptColor = Colors.blue;
                          break;
                        case 'حفظ النظام':
                          deptColor = Colors.green;
                          break;
                        case 'رعاية الحرم':
                          deptColor = Colors.orange;
                          break;
                        case 'الادارة':
                          deptColor = Colors.purple;
                          break;
                        case 'الدعم':
                          deptColor = Colors.red;
                          break;
                      }

                      return Card(
                        elevation: 3,
                        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(color: deptColor, width: 4),
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: deptColor.withOpacity(0.2),
                              foregroundColor: deptColor,
                              child: Text(
                                user.name[0],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            title: Text(
                              user.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.badge,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      user.badgeNumber,
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.groups,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      user.department,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: deptColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // زر التعديل
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.blue[700],
                                    ),
                                    onPressed: () => _showUserDialog(context, user: user),
                                    padding: EdgeInsets.all(4),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // زر الحذف
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red[700],
                                    ),
                                    onPressed: () async {
                                      bool? confirm = await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text("تأكيد الحذف"),
                                          content: Text("هل تريد حذف المستخدم ${user.name}؟"),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text("لا"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              child: Text("نعم"),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        bool success = await apiService.deleteUser(user.id);
                                        if (success) {
                                          _refreshUsers();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("تم حذف المستخدم بنجاح"),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    padding: EdgeInsets.all(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(context),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 4,
        child: Icon(Icons.add, size: 28),
      ),
    );
  }

  void _showUserDialog(BuildContext context, {User? user}) {
    final isEdit = user != null;
    final departments = ['الاتصالات', 'حفظ النظام', 'رعاية الحرم', 'الادارة', 'الدعم'];

    TextEditingController nameCtrl = TextEditingController(text: isEdit ? user.name : '');
    TextEditingController badgeCtrl = TextEditingController(text: isEdit ? user.badgeNumber : '');
    TextEditingController passCtrl = TextEditingController();
    String selectedDept = isEdit ? user.department : departments.first;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      isEdit ? Icons.edit : Icons.person_add,
                      color: Colors.blue[800],
                      size: 28,
                    ),
                    SizedBox(width: 10),
                    Text(
                      isEdit ? "تعديل المستخدم" : "إضافة مستخدم جديد",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Form Fields
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: "الاسم الكامل",
                    prefixIcon: Icon(Icons.person, color: Colors.blue[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 15),

                TextField(
                  controller: badgeCtrl,
                  decoration: InputDecoration(
                    labelText: "رقم البادج",
                    prefixIcon: Icon(Icons.badge, color: Colors.blue[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  enabled: !isEdit,
                ),
                SizedBox(height: 15),

                TextField(
                  controller: passCtrl,
                  decoration: InputDecoration(
                    labelText: isEdit ? "كلمة المرور الجديدة (اختياري)" : "كلمة المرور",
                    prefixIcon: Icon(Icons.lock, color: Colors.blue[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 15),

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: selectedDept,
                    isExpanded: true,
                    underline: SizedBox(),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
                    items: departments.map((dept) {
                      return DropdownMenuItem(
                        value: dept,
                        child: Row(
                          children: [
                            Icon(
                              Icons.group_work,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(dept),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDept = value!;
                      });
                    },
                  ),
                ),
                SizedBox(height: 25),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(color: Colors.grey),
                        ),
                        child: Text(
                          "إلغاء",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Map<String, dynamic> data = {
                            "name": nameCtrl.text,
                            "badge_number": badgeCtrl.text,
                            "department": selectedDept,
                            "role": isEdit ? user.role : "user"
                          };

                          // إضافة كلمة المرور فقط إذا تم إدخالها
                          if (passCtrl.text.isNotEmpty) {
                            data["password"] = passCtrl.text;
                          }

                          bool success;
                          if (isEdit) {
                            success = await apiService.updateUser(user.id, data);
                          } else {
                            success = await apiService.addUser(data);
                          }

                          if (success) {
                            Navigator.pop(context);
                            _refreshUsers();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit ? "تم تحديث بيانات المستخدم" : "تم إضافة المستخدم بنجاح",
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: Text(isEdit ? "تحديث" : "إضافة"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}