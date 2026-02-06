import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DaftarMagangWidget extends StatelessWidget {
  const DaftarMagangWidget({super.key});

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
              Expanded(child: Text("Nama", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(child: Text("NIP", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              Text("Hapus", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                        Expanded(child: Text(data['nama'] ?? '-', style: const TextStyle(fontSize: 11))),
                        Expanded(child: Text(data['nip'] ?? '-', style: const TextStyle(fontSize: 11))),
                        InkWell(
                          onTap: () {
                            // Logika Hapus User
                            FirebaseFirestore.instance.collection('users').doc(docs[index].id).delete();
                          },
                          child: const Icon(Icons.delete, color: Colors.red, size: 16),
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