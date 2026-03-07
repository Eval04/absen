import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // TAMBAHAN: Untuk cek database
import 'UserAbsen.dart';
import '../dashboard/admin_dashboard.dart'; // TAMBAHAN: Import halaman Admin Anda

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showSnackbar("Email dan Password wajib diisi!", Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. Lakukan Login Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      // 2. Ambil data user dari Firestore untuk cek ROLE
      // Asumsi: Nama koleksi di database adalah 'users'
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // Matikan loading — cek mounted dulu sebelum setState
      if (!mounted) return;
      setState(() => isLoading = false);

      // 3. Cek Role dan Arahkan Halaman
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String role = userData['role'] ?? 'intern';

        String status = userData['status'] ?? 'active';
        if (status == 'deleted') {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showSnackbar("Akun Anda telah dinonaktifkan. Hubungi admin.", Colors.red);
          return;
        }

        if (!mounted) return;
        if (role == 'admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const UserAbsenPage()),
            (route) => false,
          );
        }
      } else {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showSnackbar("Akun tidak ditemukan. Hubungi admin.", Colors.red);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      String message = "Terjadi kesalahan login.";
      if (e.code == 'user-not-found')
        message = "Email tidak terdaftar.";
      else if (e.code == 'wrong-password')
        message = "Password salah.";
      else if (e.code == 'invalid-credential')
        message = "Email atau password salah.";
      _showSnackbar(message, Colors.redAccent);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackbar("Error: ${e.toString()}", Colors.red);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible =
        MediaQuery.of(context).viewInsets.bottom != 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B5FA5), Color(0xFF063970)],
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isKeyboardVisible ? 0.0 : 1.0,
              child: Column(
                children: [
                  Image.asset('assets/Logo_no_bg.png', height: 100),
                  const SizedBox(height: 16),
                  const Text(
                    "Dishub Makassar",
                    style: TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isKeyboardVisible
                  ? MediaQuery.of(context).size.height * 0.9
                  : MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                physics: isKeyboardVisible
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Selamat Datang",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B5FA5),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "LOGIN",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (isKeyboardVisible) const SizedBox(height: 300),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
