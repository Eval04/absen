import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ValidasiIzinWidget extends StatelessWidget {
  const ValidasiIzinWidget({super.key});

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance
        .collection('izin')
        .doc(docId)
        .update({
      'status': status,
      'sudah_dibaca': false, // ✅ FITUR #6: trigger notif ke user
      'diproses_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _konfirmasiAksi(BuildContext context, String docId, String status, String nama) async {
    bool? konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'approved' ? "Setujui Izin?" : "Tolak Izin?"),
        content: Text(
          status == 'approved'
              ? "Anda akan menyetujui izin dari $nama."
              : "Anda akan menolak izin dari $nama.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'approved' ? Colors.green : Colors.red,
            ),
            child: Text(
              status == 'approved' ? "Setujui" : "Tolak",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      await _updateStatus(docId, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('izin')
          .where('status', isEqualTo: 'pending')
          .orderBy('created_at', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
                SizedBox(height: 8),
                Text("Tidak ada izin pending",
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String nama = data['nama'] ?? 'User';
            String jenis = data['jenis'] ?? 'Izin';
            String tanggal = data['tanggal'] ?? '-';
            String alasan = data['alasan'] ?? '-';

            // Warna berdasarkan jenis izin
            Color jenisColor;
            IconData jenisIcon;
            switch (jenis) {
              case 'Sakit':
                jenisColor = Colors.red;
                jenisIcon = Icons.local_hospital;
                break;
              case 'Izin':
                jenisColor = Colors.orange;
                jenisIcon = Icons.event_busy;
                break;
              default:
                jenisColor = Colors.purple;
                jenisIcon = Icons.more_horiz;
            }

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BARIS INFO
                  Row(
                    children: [
                      Icon(jenisIcon, size: 14, color: jenisColor),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: jenisColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(jenis,
                            style: TextStyle(
                                fontSize: 10, color: jenisColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(nama,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("📅 $tanggal", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    alasan,
                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // TOMBOL AKSI
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () =>
                                _konfirmasiAksi(context, doc.id, 'approved', nama),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text("✓ Setujui",
                                style: TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () =>
                                _konfirmasiAksi(context, doc.id, 'rejected', nama),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text("✗ Tolak",
                                style: TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
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
