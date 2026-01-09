import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_user.dart'; // PENTING: Pastikan file ini sudah dibuat

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Controller untuk form input
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _namaController = TextEditingController();
  final _nipController = TextEditingController();
  final _univController = TextEditingController(); // Controller Univ

  // Loading state
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _namaController.dispose();
    _nipController.dispose();
    _univController.dispose();
    super.dispose();
  }

  // --- FUNGSI UTAMA: REGISTER USER BARU ---
  Future<void> _registerUser() async {
    // 1. Validasi Input
    if (_emailController.text.isEmpty ||
        _namaController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nipController.text.isEmpty ||
        _univController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Semua kolom (termasuk Universitas) wajib diisi!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    FirebaseApp? secondaryApp;

    try {
      // 2. Buat Instance Firebase Kedua (Secondary App)
      // Trik agar Admin tidak ter-logout saat create user baru
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      // 3. Panggil Auth dari Secondary App
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // 4. Proses Create User di Authentication
      UserCredential userCredential =
          await secondaryAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Ambil UID
      String uid = userCredential.user!.uid;

      // 5. Simpan Data Profil ke Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'nama': _namaController.text.trim(),
        'nip': _nipController.text.trim(),
        'univ': _univController.text.trim(), // Simpan Univ
        'email': _emailController.text.trim(),
        'role': 'intern', // Default role
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6. Bersihkan Form & Beri Notifikasi Sukses
      _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Berhasil! User terdaftar di Auth & Database."),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Gagal mendaftar.";
      if (e.code == 'email-already-in-use') {
        message = "Email sudah terdaftar.";
      } else if (e.code == 'weak-password') {
        message = "Password terlalu lemah (min 6 karakter).";
      } else if (e.code == 'invalid-email') {
        message = "Format email salah.";
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
        );
      }
    } finally {
      // 7. Hapus Secondary App agar memori tidak bocor
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _namaController.clear();
    _nipController.clear();
    _univController.clear();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Admin Dashboard - Dishub Makassar",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0B5FA5),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Logout",
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // --- BAGIAN 1: SIDEBAR / FORM INPUT ---
          final sidebar = Container(
            width: constraints.maxWidth >= 800 ? 400 : double.infinity,
            color: Colors.grey[100],
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tambah Pegawai Baru",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0B5FA5)),
                  ),
                  const SizedBox(height: 20),
                  // Input Nama
                  TextField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: "Nama Lengkap",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Input NIP
                  TextField(
                    controller: _nipController,
                    decoration: const InputDecoration(
                      labelText: "NIP",
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Input Universitas
                  TextField(
                    controller: _univController,
                    decoration: const InputDecoration(
                      labelText: "Asal Universitas",
                      prefixIcon: Icon(Icons.school),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Input Email
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email Login",
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Input Password
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B5FA5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isLoading 
                          ? const SizedBox.shrink() 
                          : const Icon(Icons.save),
                      label: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("SIMPAN PEGAWAI", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );

          // --- BAGIAN 2: LIST PEGAWAI ---
          final listArea = Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Daftar Pegawai Terdaftar",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 60, color: Colors.grey),
                                SizedBox(height: 10),
                                Text('Belum ada data pegawai.', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final nama = data['nama'] ?? 'Tanpa Nama';
                            final nip = data['nip'] ?? '-';
                            final email = data['email'] ?? '-';
                            final role = data['role'] ?? 'user';
                            final univ = data['univ'] ?? '-';

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: role == 'admin' ? Colors.orange : Colors.blue,
                                  child: Icon(
                                    role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("NIP: $nip\nUniv: $univ\nEmail: $email"),
                                isThreeLine: true,
                                // TOMBOL AKSI (EDIT & HAPUS)
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Tombol Edit
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: "Edit Data",
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditUserPage(
                                              uid: doc.id,
                                              currentNama: nama,
                                              currentNip: nip,
                                              currentUniv: univ,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Tombol Hapus
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: "Hapus Data User",
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text("Hapus Pegawai"),
                                            content: Text("Yakin ingin menghapus data $nama?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text("Batal"),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  doc.reference.delete();
                                                  Navigator.pop(ctx);
                                                },
                                                child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
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

          // Responsiveness Logic
          if (constraints.maxWidth < 800) {
            return Column(
              children: [
                sidebar,
                const Divider(thickness: 5, color: Colors.grey),
                listArea,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sidebar,
              const VerticalDivider(width: 1, thickness: 1, color: Colors.grey),
              listArea,
            ],
          );
        },
      ),
    );
  }
}