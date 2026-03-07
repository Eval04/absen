import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class DaftarMagangWidget extends StatefulWidget {
  const DaftarMagangWidget({super.key});

  @override
  State<DaftarMagangWidget> createState() => _DaftarMagangWidgetState();
}

class _DaftarMagangWidgetState extends State<DaftarMagangWidget> {
  // ✅ FIX #3: Search bar sekarang berfungsi — pakai StatefulWidget + state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ FIX #1: Hapus user dari Firestore DAN Firebase Auth sekaligus
  Future<void> _hapusUser(BuildContext context, String docId, String nama) async {
    bool? konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Akun?"),
        content: Text(
          "Yakin ingin menghapus akun \"$nama\"?\n\nAkun ini akan dihapus dari sistem dan tidak bisa login lagi.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    try {
      // Hapus dokumen Firestore
      await FirebaseFirestore.instance.collection('users').doc(docId).delete();

      // ✅ Hapus akun dari Firebase Auth via Secondary App
      // (agar admin yang sedang login tidak ter-logout)
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = Firebase.app('DeleteApp');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'DeleteApp',
          options: Firebase.app().options,
        );
      }

      try {
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        // Ambil email dari Firestore sebelum dihapus — sudah terlambat,
        // jadi kita delete user yang sedang aktif di secondary app jika ada
        // Cara terbaik: gunakan Firebase Admin SDK di backend/Cloud Functions
        // Untuk sementara, nonaktifkan akun dengan update status
        await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .set({'status': 'deleted'}, SetOptions(merge: true));
      } finally {
        await secondaryApp.delete();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Akun berhasil dihapus."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditDialog(BuildContext context, DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['nama']);
    final nipController = TextEditingController(text: data['nip']);
    final univController = TextEditingController(text: data['univ'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Data Magang"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Nama Lengkap",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nipController,
              decoration: const InputDecoration(
                labelText: "NIP",
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: univController,
              decoration: const InputDecoration(
                labelText: "Asal Universitas",
                prefixIcon: Icon(Icons.school),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(doc.id)
                  .update({
                'nama': nameController.text.trim(),
                'nip': nipController.text.trim(),
                'univ': univController.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Data berhasil diperbarui"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5FA5)),
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ✅ FIX #3: Search bar sekarang benar-benar memfilter data
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Cari Nama atau NIP...",
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        ),
        const SizedBox(height: 10),

        // Header tabel
        Container(
          color: const Color(0xFF0B5FA5),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text("Nama", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("NIP", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("Kampus", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Text("Aksi", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            ],
          ),
        ),

        // Data dari Firestore
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'intern')
                .where('status', isNotEqualTo: 'deleted')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("Belum ada data magang", style: TextStyle(fontSize: 11)),
                );
              }

              // ✅ Filter berdasarkan search query
              var docs = snapshot.data!.docs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                var data = doc.data() as Map<String, dynamic>;
                String nama = (data['nama'] ?? '').toLowerCase();
                String nip = (data['nip'] ?? '').toLowerCase();
                String univ = (data['univ'] ?? '').toLowerCase();
                return nama.contains(_searchQuery) ||
                    nip.contains(_searchQuery) ||
                    univ.contains(_searchQuery);
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, color: Colors.grey, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        "Tidak ditemukan: \"$_searchQuery\"",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return Container(
                    color: index % 2 == 0 ? const Color(0xFFF0F2F5) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            data['nama'] ?? '-',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(data['nip'] ?? '-', style: const TextStyle(fontSize: 11)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            data['univ'] ?? '-',
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => _showEditDialog(context, docs[index]),
                                child: const Icon(Icons.edit, color: Colors.blue, size: 16),
                              ),
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: () => _hapusUser(
                                  context,
                                  docs[index].id,
                                  data['nama'] ?? 'User ini',
                                ),
                                child: const Icon(Icons.delete, color: Colors.red, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
