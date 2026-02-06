import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormTambahMagang extends StatefulWidget {
  const FormTambahMagang({super.key});

  @override
  State<FormTambahMagang> createState() => _FormTambahMagangState();
}

class _FormTambahMagangState extends State<FormTambahMagang> {
  final _namaController = TextEditingController();
  final _nipController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  // Listener: Saat NIP diketik, otomatis isi Email (Opsional, biar cepat)
  @override
  void initState() {
    super.initState();
    _nipController.addListener(() {
      final text = _nipController.text.trim();
      if (text.isNotEmpty) {
        _emailController.text = "$text@dishub.com";
      }
    });
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nipController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _simpanData() async {
    if (_namaController.text.isEmpty || 
        _nipController.text.isEmpty || 
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua kolom wajib diisi!")),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    FirebaseApp? secondaryApp;

    try {
      // --- TEKNIK PENTING: SECONDARY APP ---
      // Kita membuat instance aplikasi kedua agar saat create user, 
      // Admin yang sedang login TIDAK ikut ter-logout.
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // 1. Buat Akun di Authentication (Email & Password)
      UserCredential userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Simpan Data Profil ke Firestore
      // Kita gunakan UID dari akun yang baru dibuat sebagai ID Dokumen
      String uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nama': _namaController.text.trim(),
        'nip': _nipController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'intern', // Role otomatis Anak Magang
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
        // Password tidak perlu disimpan di database demi keamanan, 
        // tapi admin yang set passwordnya pertama kali.
      });

      // Reset Form
      _namaController.clear();
      _nipController.clear();
      _emailController.clear();
      _passwordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Akun Magang Berhasil Dibuat!")),
        );
      }

    } on FirebaseAuthException catch (e) {
      String err = "Gagal membuat akun.";
      if (e.code == 'email-already-in-use') err = "Email/NIP ini sudah terdaftar.";
      if (e.code == 'weak-password') err = "Password minimal 6 karakter.";
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Hapus aplikasi secondary agar hemat memori
      await secondaryApp?.delete();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Input Nama
        TextField(
          controller: _namaController,
          decoration: const InputDecoration(
            labelText: "Nama Lengkap", 
            border: OutlineInputBorder(), 
            isDense: true,
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 10),
        
        // Input NIP
        TextField(
          controller: _nipController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "NIP / ID", 
            border: OutlineInputBorder(), 
            isDense: true,
            prefixIcon: Icon(Icons.badge),
          ),
        ),
        const SizedBox(height: 10),

        // Input Email (Otomatis terisi, tapi bisa diedit)
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: "Email Login", 
            border: OutlineInputBorder(), 
            isDense: true,
            prefixIcon: Icon(Icons.email),
          ),
        ),
        const SizedBox(height: 10),

        // Input Password (BARU)
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Password Awal", 
            border: OutlineInputBorder(), 
            isDense: true,
            prefixIcon: Icon(Icons.lock),
          ),
        ),
        
        const Spacer(),
        
        // Tombol Simpan
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _simpanData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B5FA5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("BUAT AKUN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }
}