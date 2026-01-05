import 'package:flutter/material.dart';
import 'package:gom_tss/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ScreeenPTT.dart';
import 'ApiServes/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _badgeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final result = await AuthService.login(
      badgeNumber: _badgeController.text,
      password: _passwordController.text,
    );

    if (result['success'] == true) {
      final User user = result['user'];
      final prefs = await SharedPreferences.getInstance();

      // حفظ بيانات المستخدم
      await prefs.setInt('user_id', user.id);
      await prefs.setString('user_name', user.name);
      await prefs.setString('badge_number', user.badgeNumber);
      await prefs.setString('department', user.department);
      await prefs.setString('channel', user.department);
      await prefs.setString('role', user.role);
      await prefs.setBool('is_logged_in', true);

      // الانتقال لشاشة PTT مباشرة
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PTTDemo(
            department: user.department,
            initialChannel: user.department,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1E3C), // لون ليلي غامق
              Color(0xFF1A3A5F), // أزرق متوسط
              Color(0xFF2D5A8C), // أزرق فاتح
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // رأس التطبيق مع أيقونة اتصال لاسلكي
                _buildHeader(),
                SizedBox(height: 40.0),

                // بطاقة تسجيل الدخول
                Card(
                  elevation: 15.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(30.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Color(0xFFE8F4FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Column(
                      children: [
                        // حقل رقم البطاقة
                        _buildTextField(
                          controller: _badgeController,
                          label: 'رقم البطاقة',
                          icon: Icons.badge,
                          prefixIcon: Icons.radio_button_checked,
                          iconColor: Colors.blueAccent,
                        ),
                        SizedBox(height: 25.0),

                        // حقل كلمة المرور
                        _buildPasswordField(),
                        SizedBox(height: 40.0),

                        // زر تسجيل الدخول
                        _buildLoginButton(),
                      ],
                    ),
                  ),
                ),

                // موجة اتصال في الأسفل
                SizedBox(height: 50.0),
                _buildConnectionWave(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // أيقونة الاتصال اللاسلكي
        Container(
          width: 120.0,
          height: 120.0,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.3),
                blurRadius: 20.0,
                spreadRadius: 5.0,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // موجات اتصال
              Container(
                width: 100.0,
                height: 100.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.6),
                    width: 2.0,
                  ),
                ),
              ),
              Container(
                width: 70.0,
                height: 70.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blueAccent.withOpacity(0.8),
                    width: 2.0,
                  ),
                ),
              ),
              // أيقونة مركزية
              Icon(
                Icons.wifi_tethering,
                size: 40.0,
                color: Colors.white,
              ),
            ],
          ),
        ),
        SizedBox(height: 20.0),

        // عنوان التطبيق
        Text(
          'نظام الاتصال اللاسلكي',
          style: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 8.0),
        Text(
          'PTT Communication System',
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.cyanAccent.withOpacity(0.8),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required IconData prefixIcon,
    required Color iconColor,
  }) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 16.0,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.blueGrey[700],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: iconColor,
          size: 22.0,
        ),
        suffixIcon: Icon(
          icon,
          color: Colors.blueGrey[400],
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: Colors.blueAccent.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: Colors.blueAccent,
            width: 2.0,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 16.0,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 16.0,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: 'كلمة المرور',
        labelStyle: TextStyle(
          color: Colors.blueGrey[700],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          Icons.security,
          color: Colors.greenAccent,
          size: 22.0,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.blueGrey[400],
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: Colors.blueAccent.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: Colors.blueAccent,
            width: 2.0,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 16.0,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        gradient: LinearGradient(
          colors: [
            Color(0xFF1E88E5),
            Color(0xFF0D47A1),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.4),
            blurRadius: 8.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: EdgeInsets.zero,
        ),
        child: _isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.0,
            ),
            SizedBox(width: 15.0),
            Text(
              'جاري الاتصال...',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              color: Colors.white,
              size: 22.0,
            ),
            SizedBox(width: 10.0),
            Text(
              'تسجيل الدخول',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(width: 5.0),
            Icon(
              Icons.settings_input_antenna,
              color: Colors.white,
              size: 22.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionWave() {
    return Column(
      children: [
        // موجة اتصال متحركة
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildWaveDot(0),
            _buildWaveDot(1),
            _buildWaveDot(2),
            _buildWaveDot(3),
            _buildWaveDot(4),
          ],
        ),
        SizedBox(height: 20.0),
        Text(
          'Secure Wireless Connection',
          style: TextStyle(
            fontSize: 14.0,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildWaveDot(int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.0),
      width: 8.0,
      height: 30.0,
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withOpacity(0.3 + (index * 0.15)),
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }
}