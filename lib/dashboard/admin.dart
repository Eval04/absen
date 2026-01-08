import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _namaController = TextEditingController();
  final _nipController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _namaController.dispose();
    _nipController.dispose();
    super.dispose();
  }

  // Fungsi untuk mendaftarkan user baru
  Future<void> _registerUser() async {
    if (_emailController.text.isEmpty || _namaController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // 1. Buat user di Firebase Auth (sementara menggunakan instance sekunder atau admin SDK idealnya)
      // Catatan: Di Flutter client side, mendaftarkan user lain akan membuat admin logout.
      // Untuk testing web, kita gunakan cara Firestore-first atau Firebase Admin SDK di Backend.
      // Di sini kita simpan datanya ke Firestore saja sebagai simulasi pendaftaran oleh Admin.

      await FirebaseFirestore.instance.collection('users').add({
        'nama': _namaController.text.trim(),
        'nip': _nipController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User berhasil ditambahkan ke database!"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _namaController.clear();
    _nipController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard - Dishub Makassar"),
        backgroundColor: const Color(0xFF0B5FA5),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // build sidebar form
          final sidebar = Container(
            width: constraints.maxWidth >= 600 ? 400 : double.infinity,
            color: Colors.grey[100],
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tambah Pegawai Baru",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: "Nama Lengkap",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nipController,
                    decoration: const InputDecoration(
                      labelText: "NIP",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email Login",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("SIMPAN PEGAWAI"),
                    ),
                  ),
                ],
              ),
            ),
          );

          final listArea = Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Daftar Pegawai Terdaftar",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                      builder:
                          (
                            context,
                            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                            snapshot,
                          ) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text('No users found'),
                              );
                            }

                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data();
                                final nama = data['nama'] ?? '';
                                final nip = data['nip'] ?? '';
                                final email = data['email'] ?? '';
                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person),
                                    ),
                                    title: Text(nama),
                                    subtitle: Text("NIP: $nip | $email"),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => doc.reference.delete(),
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

          if (constraints.maxWidth < 600) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  sidebar,
                  const SizedBox(height: 12),
                  SizedBox(height: 600, child: listArea),
                ],
              ),
            );
          }

          return Row(children: [sidebar, listArea]);
        },
      ),
    );
  }
}
