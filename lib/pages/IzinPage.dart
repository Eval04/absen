import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class IzinPage extends StatefulWidget {
  final String uid;
  final String nama;

  const IzinPage({super.key, required this.uid, required this.nama});

  @override
  State<IzinPage> createState() => _IzinPageState();
}

class _IzinPageState extends State<IzinPage> {
  final _alasanController = TextEditingController();
  String _jenisIzin = 'Izin';
  DateTime _tanggalDipilih = DateTime.now();
  bool _isLoading = false;

  final Color darkBlue = const Color(0xFF03254C);
  final Color accentOrange = const Color(0xFFFF9800);

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tanggalDipilih,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() => _tanggalDipilih = picked);
    }
  }

  Future<void> _ajukanIzin() async {
    if (_alasanController.text.trim().isEmpty) {
      _showSnackbar("Alasan izin wajib diisi!", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String tanggalStr = DateFormat('yyyy-MM-dd').format(_tanggalDipilih);

      // Cek apakah sudah ada pengajuan izin di tanggal yang sama
      QuerySnapshot existing = await FirebaseFirestore.instance
          .collection('izin')
          .where('uid', isEqualTo: widget.uid)
          .where('tanggal', isEqualTo: tanggalStr)
          .get();

      if (existing.docs.isNotEmpty) {
        _showSnackbar("Anda sudah mengajukan izin untuk tanggal ini.", Colors.orange);
        return;
      }

      await FirebaseFirestore.instance.collection('izin').add({
        'uid': widget.uid,
        'nama': widget.nama,
        'jenis': _jenisIzin,
        'tanggal': tanggalStr,
        'bulan': _tanggalDipilih.month,
        'tahun': _tanggalDipilih.year,
        'alasan': _alasanController.text.trim(),
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      _alasanController.clear();
      _showSnackbar("Pengajuan izin berhasil dikirim!", Colors.green);
    } catch (e) {
      _showSnackbar("Gagal mengajukan izin: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Ajukan Izin / Sakit",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: darkBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FORM PENGAJUAN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Form Pengajuan",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),

                  // JENIS IZIN
                  const Text("Jenis Izin", style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildJenisChip("Izin", Icons.event_busy),
                      const SizedBox(width: 10),
                      _buildJenisChip("Sakit", Icons.local_hospital),
                      const SizedBox(width: 10),
                      _buildJenisChip("Keperluan Lain", Icons.more_horiz),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // TANGGAL
                  const Text("Tanggal", style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pilihTanggal,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: darkBlue),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_tanggalDipilih),
                            style: TextStyle(color: darkBlue, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ALASAN
                  const Text("Keterangan / Alasan", style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _alasanController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Tuliskan alasan izin Anda...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // TOMBOL KIRIM
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _ajukanIzin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text(
                              "KIRIM PENGAJUAN",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // RIWAYAT PENGAJUAN IZIN
            const Text("Riwayat Pengajuan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('izin')
                  .where('uid', isEqualTo: widget.uid)
                  .orderBy('created_at', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text("Belum ada pengajuan izin.",
                          style: TextStyle(color: Colors.black54)),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return _buildRiwayatCard(data);
                  },
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildJenisChip(String label, IconData icon) {
    bool isSelected = _jenisIzin == label;
    return InkWell(
      onTap: () => setState(() => _jenisIzin = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? darkBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? darkBlue : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatCard(Map<String, dynamic> data) {
    String status = data['status'] ?? 'pending';
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: darkBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(data['jenis'] ?? '-',
                          style: TextStyle(fontSize: 11, color: darkBlue, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(data['tanggal'] ?? '-',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data['alasan'] ?? '-',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status == 'pending' ? 'Menunggu' : status == 'approved' ? 'Disetujui' : 'Ditolak',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
