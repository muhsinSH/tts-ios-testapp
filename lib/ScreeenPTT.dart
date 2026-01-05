
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ApiServes/department_service.dart';
import 'ServesPTT.dart';
import 'UserMagement.dart';
import 'login_screen.dart';

class PTTDemo extends StatefulWidget {
  final String department;
  final String initialChannel;

  const PTTDemo({
    Key? key,
    required this.department,
    required this.initialChannel,
  }) : super(key: key);

  @override
  _PTTDemoState createState() => _PTTDemoState();
}

class _PTTDemoState extends State<PTTDemo> with WidgetsBindingObserver, TickerProviderStateMixin {
  late PTTService _pttService;
  bool _recorderOpened = false;

  String _status = 'جاري الاتصال بالخادم...';
  String _subscriptionInfo = '';
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isReceivingAudio = false;

  Timer? _audioIndicatorTimer;
  double _audioLevel = 0.0;
  double _dbLevel = 0.0;
  String _currentChannel = '';

  int _selectedIndex = 0;

  List<Map<String, dynamic>> _departments = [];
  bool _loadingDepartments = true;
  String? userRole;
  // ألوان متطورة مع تدرجات
  final List<Gradient> departmentGradients = [
    LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)]),
    LinearGradient(colors: [Color(0xFF43A047), Color(0xFF66BB6A)]),
    LinearGradient(colors: [Color(0xFFFB8C00), Color(0xFFFFB74D)]),
    LinearGradient(colors: [Color(0xFF8E24AA), Color(0xFFBA68C8)]),
    LinearGradient(colors: [Color(0xFF00ACC1), Color(0xFF26C6DA)]),
    LinearGradient(colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)]),
    LinearGradient(colors: [Color(0xFFEC407A), Color(0xFFF48FB1)]),
    LinearGradient(colors: [Color(0xFF7CB342), Color(0xFF9CCC65)]),
    LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]),
    LinearGradient(colors: [Color(0xFFE53935), Color(0xFFEF5350)]),
  ];

  // رسوم متحركة
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _buttonController;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserRole();
    // تهيئة المتحكمات للرسوم المتحركة
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _waveAnimation = Tween(begin: 0.0, end: 1.0).animate(_waveController);

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pttService = PTTService();
    _currentChannel = widget.initialChannel;
    _loadDepartments();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _revertToDefaultChannel();
    }
  }

  Map<String, dynamic> _formatDepartment(String dep, int index) {
    return {
      'name': dep,
      'channel': dep,
      'gradient': departmentGradients[index % departmentGradients.length],
      'icon': Icons.headset_mic,
      'code': dep.length >= 3 ? dep.substring(0, 3).toUpperCase() : dep,
      'color': departmentGradients[index % departmentGradients.length].colors[0],
    };
  }

  void _loadDepartments() async {
    final departments = await DepartmentService.getDepartments();

    setState(() {
      _departments = List.generate(
        departments.length,
            (i) => _formatDepartment(departments[i], i),
      );
      _loadingDepartments = false;

      final index = _departments.indexWhere((d) => d['channel'] == widget.initialChannel);
      _selectedIndex = (index != -1 ? index : 0);
    });

    _initializePTT();
  }

  void _initializePTT() async {
    try {
      await _pttService.initialize();
      await _pttService.connect();

      setState(() {
        _status = 'متصل بالخادم';
        _isConnected = true;
      });

      await _subscribeToChannel(_currentChannel, isTemporary: false);

      _pttService.streamService.isSpeakingStream.listen((isSpeaking) {
        if (isSpeaking) {
          if (_isRecording) {
            _stopRecording();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("تم قطع الإرسال لاستقبال مكالمة"),
                backgroundColor: Colors.orange,
                duration: Duration(milliseconds: 800),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }

          setState(() {
            _isReceivingAudio = true;
          });

          _audioIndicatorTimer?.cancel();
          _audioIndicatorTimer = Timer(Duration(milliseconds: 500), () {
            setState(() {
              _isReceivingAudio = false;
            });
          });
        }
      });

      _pttService.streamService.dbLevelStream.listen((dbLevel) {
        setState(() {
          _dbLevel = dbLevel;
        });
      });

      _pttService.setAudioCallback((data) {
        setState(() {
          _isReceivingAudio = true;
          _audioLevel = (data.length / 10000).clamp(0.0, 1.0);
        });

        _audioIndicatorTimer?.cancel();
        _audioIndicatorTimer = Timer(Duration(milliseconds: 500), () {
          setState(() {
            _isReceivingAudio = false;
            _audioLevel = 0.0;
          });
        });
      });

    } catch (e) {
      setState(() => _status = 'فشل الاتصال: $e');
    }
  }

  Future<void> _subscribeToChannel(String channel, {bool isTemporary = true}) async {
    try {
      await _pttService.subscribe(channel);
      setState(() {
        _subscriptionInfo = "القناة: ${_getCurrentDepartment()['code']}";
        _currentChannel = channel;
      });

      FlutterBackgroundService().invoke('setChannel', {'channel': channel});

    } catch (e) {
      setState(() => _subscriptionInfo = "فشل الاشتراك: $e");
    }
  }

  Map<String, dynamic> _getCurrentDepartment() {
    if (_departments.isEmpty) return {};
    if (_selectedIndex >= _departments.length) return _departments[0];
    return _departments[_selectedIndex];
  }

  void _startRecording() async {
    if (!_isConnected || _isReceivingAudio) return;

    // تشغيل الرسوم المتحركة
    _buttonController.forward();

    try {
      await _pttService.startRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      setState(() => _status = 'خطأ: $e');
      _buttonController.reverse();
    }
  }

  void _stopRecording() async {
    if (!_isConnected) return;

    // إرجاع الرسوم المتحركة
    _buttonController.reverse();

    try {
      await _pttService.stopRecording();
      setState(() => _isRecording = false);
    } catch (e) {
      setState(() => _status = 'خطأ: $e');
    }
  }

  void _onDepartmentTap(int index) {
    if (index == _selectedIndex) return;
    if (_isRecording) _stopRecording();

    setState(() => _selectedIndex = index);
    final newDepartment = _departments[index];
    _subscribeToChannel(newDepartment['channel'], isTemporary: true);
  }

  void _revertToDefaultChannel() {
    FlutterBackgroundService().invoke('setChannel', {'channel': widget.initialChannel});
  }

  Future<void> _reconnectPTT() async {
    try {
      setState(() {
        _status = 'جاري إعادة الاتصال...';
        _isConnected = false;
      });

      _pttService.dispose();
      _pttService = PTTService();

      await _pttService.initialize();
      await _pttService.connect();
      await _subscribeToChannel(_currentChannel, isTemporary: false);

      setState(() {
        _status = 'تمت إعادة الاتصال';
        _isConnected = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إعادة الاتصال بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      setState(() {
        _status = 'فشل إعادة الاتصال';
        _isConnected = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إعادة الاتصال'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // جلب القيمة المخزنة، وإذا لم توجد نجعلها قيمة فارغة
      userRole = prefs.getString('role') ?? '';
    });
  }
  @override
  Widget build(BuildContext context) {
    if (_loadingDepartments || _departments.isEmpty) {
      return Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildWaveAnimation(),
              SizedBox(height: 30),
              Text(
                'جاري تحميل الأقسام...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 10),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      );
    }

    final currentDept = _getCurrentDepartment();
    final gradientColors = currentDept['gradient'].colors;

    return Scaffold(
      backgroundColor: Color(0xFF0A0E21),
      body: Stack(
        children: [
          // خلفية متحركة
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A0E21),
                    Color(0xFF1A1F35),
                    Color(0xFF2D3550),
                  ],
                ),
              ),
            ),
          ),

          // موجات خلفية متحركة
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 150),
                  painter: _WavePainter(
                    animationValue: _waveAnimation.value,
                    color: gradientColors[0].withOpacity(0.05),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(currentDept),
                _buildMainDisplay(currentDept),
                Expanded(child: _buildDepartmentsGrid(currentDept)),
                _buildPTTButton(currentDept),
                SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> currentDept) {
    final gradientColors = currentDept['gradient'].colors;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: currentDept['gradient'],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.wifi_tethering,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PTT نظام ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.only(left: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: _isConnected ? Colors.greenAccent.withOpacity(0.6) : Colors.redAccent.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 5),
                      Text(
                        _isConnected ? 'متصل' : 'غير متصل',
                        style: TextStyle(
                          color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (userRole == 'admin')
              _buildIconButton(
                icon: Icons.add_circle_outlined,
                color: Colors.blueAccent,
                tooltip: 'اضافة مستخدمين',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AdminUsersScreen()),
                  );
                },
              ),
              // SizedBox(width: 8),
              // _buildIconButton(
              //   icon: Icons.history,
              //   color: Colors.blueAccent,
              //   tooltip: 'سجل المحادثات',
              //   onPressed: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (context) => RecordsScreen()),
              //     );
              //   },
              // ),
              SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.refresh,
                color: Colors.orangeAccent,
                tooltip: 'إعادة الاتصال',
                onPressed: _reconnectPTT,
              ),
              SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.logout,
                color: Colors.grey[400]!,
                tooltip: 'تسجيل الخروج',
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 22),
        color: color,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildMainDisplay(Map<String, dynamic> currentDept) {
    final gradientColors = currentDept['gradient'].colors;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: gradientColors[0].withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradientColors[0].withOpacity(0.2),
                  gradientColors[1].withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  currentDept['name'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: currentDept['gradient'],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    'القناة: ${currentDept['name']}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          if (_isRecording)
            Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 100),
                      height: 10,
                      width: (_dbLevel + 80) / 100 * MediaQuery.of(context).size.width * 0.7,
                      decoration: BoxDecoration(
                        gradient: currentDept['gradient'],
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withOpacity(0.5),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),

              ],
            ),

          if (!_isRecording && !_isReceivingAudio)
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'جاهز للبث',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          if (_isReceivingAudio)
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.volume_up,
                    color: Colors.orangeAccent,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'جارٍ استقبال صوت',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDepartmentsGrid(Map<String, dynamic> currentDept) {
    return Container(
      // تحديد ارتفاع ثابت أو استخدام مساحة الشاشة يمنع الـ Overflow
      height: 350,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Icon(Icons.group_work, color: Colors.grey[400], size: 20),
              SizedBox(width: 8),
              Text(
                "الأقسام المتاحة",
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),

          // شبكة الأقسام
          Expanded(
            child: GridView.builder(
              // منع التمرير داخل الـ GridView إذا كنت تريد تمرير الصفحة كاملة
              // physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8, // ضبط النسبة لتناسب الأيقونة والنص تحتها
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _departments.length,
              itemBuilder: (context, index) {
                final dept = _departments[index];
                final bool isActive = index == _selectedIndex;
                final gradientColors = dept['gradient'].colors;

                return GestureDetector(
                  onTap: () => _onDepartmentTap(index),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? dept['gradient']
                          : LinearGradient(
                        colors: [Colors.grey[800]!, Colors.grey[900]!],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? gradientColors[0] : Colors.transparent,
                        width: isActive ? 2 : 0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isActive
                              ? gradientColors[0].withOpacity(0.4)
                              : Colors.black.withOpacity(0.2),
                          blurRadius: isActive ? 12 : 5,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // دائرة الأيقونة
                        Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(isActive ? 0.2 : 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isActive ? Colors.white : Colors.grey[600],
                            size: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        // نص القسم
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            dept['name'],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey[400],
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPTTButton(Map<String, dynamic> currentDept) {
    final gradientColors = currentDept['gradient'].colors;

    return GestureDetector(
      onTapDown: (_) => !_isReceivingAudio ? _startRecording() : null,
      onTapUp: (_) => _isRecording ? _stopRecording() : null,
      onTapCancel: () => _isRecording ? _stopRecording() : null,
      child: AnimatedBuilder(
        animation: _buttonController,
        builder: (context, child) {
          final scale = 1 + (_buttonController.value * 0.1);

          return Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // موجات متحركة حول الزر
                if (_isRecording)
                  ...List.generate(3, (index) {
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 800),
                      width: 200 + (index * 40) + (_waveAnimation.value * 20),
                      height: 200 + (index * 40) + (_waveAnimation.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: gradientColors[0].withOpacity(0.3 - (index * 0.1)),
                          width: 2,
                        ),
                      ),
                    );
                  }),

                // الزر الرئيسي
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isRecording
                        ? LinearGradient(
                      colors: [
                        Colors.redAccent,
                        Colors.deepOrangeAccent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : (_isReceivingAudio
                        ? LinearGradient(
                      colors: [Colors.grey[700]!, Colors.grey[900]!],
                    )
                        : currentDept['gradient']),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording
                            ? Colors.redAccent
                            : gradientColors[0]).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isRecording
                            ? Icons.mic
                            : (_isReceivingAudio ? Icons.block : Icons.mic_none),
                        size: 50,
                        color: Colors.white,
                      ),
                      SizedBox(height: 10),
                      Text(
                        _isRecording
                            ? 'جاري البث'
                            : _isReceivingAudio
                            ? 'مشغول'
                            : 'اضغط للتحدث',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (_isRecording)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'حرر لإيقاف البث',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // مؤشر تسجيل متحرك
                if (_isRecording)
                  Positioned(
                    top: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaveAnimation() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(100, 100),
          painter: _WavePainter(
            animationValue: _waveAnimation.value,
            color: Colors.blueAccent.withOpacity(0.3),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revertToDefaultChannel();
    _audioIndicatorTimer?.cancel();
    _waveController.dispose();
    _buttonController.dispose();
    _pttService.dispose();
    super.dispose();
  }
}

// رسام للموجات المتحركة
class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavePainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    final baseHeight = size.height / 2;
    final waveLength = size.width;
    final amplitude = 20.0;

    path.moveTo(0, baseHeight);

    for (double i = 0; i < size.width; i++) {
      final y = baseHeight +
          amplitude *
              sin((i / waveLength * 2 * pi) + (animationValue * 2 * pi));
      path.lineTo(i, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}