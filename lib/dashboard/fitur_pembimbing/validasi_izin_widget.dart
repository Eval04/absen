import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ValidasiIzinWidget extends StatelessWidget {
  const ValidasiIzinWidget({super.key});

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance.collection('izin').doc(docId).update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('izin')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Tidak ada izin pending", style: TextStyle(fontSize: 11)));

        return ListView.separated(
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // INFO (Expanded agar mengambil sisa ruang)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Request Pending", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(data['nama'] ?? 'User', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(data['tanggal'] ?? '-', style: const TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                  
                  // TOMBOL APPROVE (Kecil)
                  SizedBox(
                    width: 50, // Lebar fixed kecil
                    height: 25,
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(doc.id, 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.zero, // Hilangkan padding bawaan
                      ),
                      child: const Text("Approve", style: TextStyle(fontSize: 8, color: Colors.white)),
                    ),
                  ),
                  
                  const SizedBox(width: 5),

                  // TOMBOL REJECT (Kecil)
                  SizedBox(
                    width: 50,
                    height: 25,
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(doc.id, 'rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text("Reject", style: TextStyle(fontSize: 8, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}