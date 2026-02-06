import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DaftarMagangWidget extends StatelessWidget {
  const DaftarMagangWidget({super.key});

  // --- FUNGSI UNTUK MENAMPILKAN POPUP EDIT ---
  void _showEditDialog(BuildContext context, DocumentSnapshot doc) {
    // Ambil data lama untuk ditampilkan di form
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    TextEditingController nameController = TextEditingController(text: data['nama']);
    TextEditingController nipController = TextEditingController(text: data['nip']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Data Magang"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Nama Lengkap"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nipController,
                decoration: const InputDecoration(labelText: "NIP"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Tutup dialog
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                // LOGIKA UPDATE KE FIREBASE
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(doc.id)
                    .update({
                  'nama': nameController.text.trim(),
                  'nip': nipController.text.trim(),
                });
                
                if (context.mounted) {
                  Navigator.pop(context); // Tutup dialog setelah simpan
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Data berhasil diperbarui")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5FA5)),
              child: const Text("Simpan", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar (Visual Saja)
        TextField(
          decoration: InputDecoration(
            hintText: "Cari Nama...", isDense: true,
            suffixIcon: const Icon(Icons.search, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(height: 10),
        
        // Header
        Container(
          color: const Color(0xFF0B5FA5),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text("Nama", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("NIP", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              // Ubah 'Hapus' jadi 'Aksi' karena sekarang ada 2 tombol
              Expanded(flex: 1, child: Text("Aksi", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            ],
          ),
        ),

        // ISI DATA DARI FIREBASE
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'intern')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Belum ada data magang", style: TextStyle(fontSize: 10)));
              }

              var docs = snapshot.data!.docs;
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
                        Expanded(flex: 2, child: Text(data['nama'] ?? '-', style: const TextStyle(fontSize: 11))),
                        Expanded(flex: 2, child: Text(data['nip'] ?? '-', style: const TextStyle(fontSize: 11))),
                        
                        // KOLOM AKSI (EDIT & DELETE)
                        Expanded(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // TOMBOL EDIT
                              InkWell(
                                onTap: () => _showEditDialog(context, docs[index]),
                                child: const Icon(Icons.edit, color: Colors.blue, size: 16),
                              ),
                              const SizedBox(width: 15), // Jarak antar ikon
                              // TOMBOL HAPUS
                              InkWell(
                                onTap: () {
                                  // Konfirmasi Hapus
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Hapus Data?"),
                                      content: Text("Yakin ingin menghapus ${data['nama']}?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
                                        TextButton(
                                          onPressed: () {
                                            FirebaseFirestore.instance.collection('users').doc(docs[index].id).delete();
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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