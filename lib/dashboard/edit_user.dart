import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditUserPage extends StatefulWidget {
  final String uid;
  final String currentNama;
  final String currentNip;
  final String currentUniv;

  const EditUserPage({
    super.key,
    required this.uid,
    required this.currentNama,
    required this.currentNip,
    required this.currentUniv,
  });

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  late TextEditingController _namaController;
  late TextEditingController _nipController;
  late TextEditingController _univController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Isi form dengan data yang dikirim dari halaman Admin
    _namaController = TextEditingController(text: widget.currentNama);
    _nipController = TextEditingController(text: widget.currentNip);
    _univController = TextEditingController(text: widget.currentUniv);
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nipController.dispose();
    _univController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (_namaController.text.isEmpty ||
        _nipController.text.isEmpty ||
        _univController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua kolom wajib diisi!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update data ke Firestore berdasarkan UID
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'nama': _namaController.text.trim(),
        'nip': _nipController.text.trim(),
        'univ': _univController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(), // Opsional: catat waktu update
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Data berhasil diperbarui!"),
          ),
        );
        Navigator.pop(context); // Kembali ke halaman Admin
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Error: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Data Pegawai"),
        backgroundColor: const Color(0xFF0B5FA5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.edit_note, size: 80, color: Color(0xFF0B5FA5)),
            const SizedBox(height: 20),
            TextField(
              controller: _namaController,
              decoration: const InputDecoration(
                labelText: "Nama Lengkap",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nipController,
              decoration: const InputDecoration(
                labelText: "NIP",
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _univController,
              decoration: const InputDecoration(
                labelText: "Asal Universitas",
                prefixIcon: Icon(Icons.school),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B5FA5),
                  foregroundColor: Colors.white,
                ),
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SIMPAN PERUBAHAN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}