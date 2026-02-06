import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormTambahMagang extends StatefulWidget {
  const FormTambahMagang({super.key});

  @override
  State<FormTambahMagang> createState() => _FormTambahMagangState();
}

class _FormTambahMagangState extends State<FormTambahMagang> {
  final _namaController = TextEditingController();
  final _nipController = TextEditingController();
  bool _isLoading = false;

  Future<void> _simpanData() async {
    if (_namaController.text.isEmpty || _nipController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'nama': _namaController.text.trim(),
        'nip': _nipController.text.trim(),
        'role': 'intern', // Default role
        'email': '${_nipController.text.trim()}@dishub.com',
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
      });
      _namaController.clear();
      _nipController.clear();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data Berhasil Disimpan")));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _namaController,
          decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nipController,
          decoration: const InputDecoration(labelText: "NIP / ID", border: OutlineInputBorder(), isDense: true),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _simpanData,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: _isLoading 
              ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("SIMPAN DATA", style: TextStyle(color: Colors.white)),
          ),
        )
      ],
    );
  }
}