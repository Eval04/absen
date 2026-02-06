import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Untuk Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Untuk Cek Database
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';

// --- IMPORT HALAMAN ANDA ---
// Pastikan path/nama file ini sesuai dengan project Anda
import 'pages/SplashScreen.dart';
import 'dashboard/admin_dashboard.dart'; // <--- INI BENAR (Sesuai nama file Anda)
import 'pages/Login.dart'; // File login Anda
import 'pages/UserAbsen.dart'; // File halaman user/intern Anda

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi format tanggal Indonesia
  await initializeDateFormatting('id_ID', null);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Absensi Dishub Makassar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5FA5)),
      ),
      // LOGIKA NAVIGASI UTAMA:
      // Jika Web -> Masuk ke Pengecekan Auth (WebAuthGate)
      // Jika Mobile -> Masuk ke SplashScreen dulu (untuk estetika)
      home: kIsWeb ? const WebAuthGate() : const SplashScreen(),
    );
  }
}

// --- WIDGET PENGATUR ALUR (GATEKEEPER) KHUSUS WEB ---
class WebAuthGate extends StatelessWidget {
  const WebAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Memantau status login secara real-time
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Loading saat memeriksa status login
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Jika USER BELUM LOGIN -> Arahkan ke Login Page
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // 3. Jika USER SUDAH LOGIN -> Cek Role dia di Database
        return RoleCheck(uid: snapshot.data!.uid);
      },
    );
  }
}

// --- WIDGET PENGECEK ROLE KE FIRESTORE ---
class RoleCheck extends StatelessWidget {
  final String uid;
  const RoleCheck({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      // Mengambil data dari koleksi 'users' berdasarkan UID
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        // Sedang mengambil data dari database...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Memeriksa status akun..."),
                ],
              ),
            ),
          );
        }

        // Jika terjadi error koneksi
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }

        // Jika data ditemukan
        if (snapshot.hasData && snapshot.data!.exists) {
          // Ambil field 'role'
          // Menggunakan data() as Map untuk keamanan akses
          Map<String, dynamic>? data =
              snapshot.data!.data() as Map<String, dynamic>?;
          String role =
              data?['role'] ?? 'intern'; // Default ke intern jika null

          // LOGIKA PEMBAGIAN HALAMAN
          if (role == 'admin') {
            return const AdminDashboard();
          } else {
            return const UserAbsenPage();
          }
        }

        // Jika user login di Auth tapi datanya tidak ada di Firestore (Edge Case)
        // Kita arahkan ke User Page atau Login Page, atau logout paksa
        return const UserAbsenPage();
      },
    );
  }
}
