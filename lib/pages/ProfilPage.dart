import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final _namaController = TextEditingController();
  final _univController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  final Color darkBlue = const Color(0xFF03254C);
  final Color primaryBlue = const Color(0xFF0D61B1);

  @override
  void dispose() {
    _namaController.dispose();
    _univController.dispose();
    super.dispose();
  }

  Future<void> _simpanProfil() async {
    if (_namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama tidak boleh kosong!"), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .update({
        'nama': _namaController.text.trim(),
        'univ': _univController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil berhasil diperbarui!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Profil Saya",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: darkBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data()!;

          if (!_isEditing) {
            _namaController.text = data['nama'] ?? '';
            _univController.text = data['univ'] ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // AVATAR
                CircleAvatar(
                  radius: 48,
                  backgroundColor: primaryBlue,
                  child: Text(
                    (data['nama'] ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['nama'] ?? '-',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  data['email'] ?? '',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),

                // KARTU INFO / FORM EDIT
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
                      Row(
                        children: [
                          const Text("Informasi Pribadi",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          if (_isEditing)
                            TextButton(
                              onPressed: () => setState(() => _isEditing = false),
                              child: const Text("Batal"),
                            ),
                        ],
                      ),
                      const Divider(height: 20),

                      _buildInfoRow("NIP", data['nip'] ?? '-', Icons.badge, editable: false),
                      const SizedBox(height: 12),

                      _isEditing
                          ? TextField(
                              controller: _namaController,
                              decoration: const InputDecoration(
                                labelText: "Nama Lengkap",
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                            )
                          : _buildInfoRow("Nama", data['nama'] ?? '-', Icons.person),
                      const SizedBox(height: 12),

                      _isEditing
                          ? TextField(
                              controller: _univController,
                              decoration: const InputDecoration(
                                labelText: "Asal Universitas",
                                prefixIcon: Icon(Icons.school),
                                border: OutlineInputBorder(),
                              ),
                            )
                          : _buildInfoRow("Asal Kampus", data['univ'] ?? '-', Icons.school),

                      if (_isEditing) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _simpanProfil,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : const Text("SIMPAN PERUBAHAN",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // STATISTIK KEHADIRAN
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
                      const Text("Statistik Bulan Ini",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const Divider(height: 20),
                      _buildStatistikBulanIni(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool editable = true}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryBlue),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatistikBulanIni() {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('absensi')
          .where('uid', isEqualTo: currentUser?.uid)
          .where('bulan', isEqualTo: now.month)
          .where('tahun', isEqualTo: now.year)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        int totalMasuk = snapshot.data!.docs.where((d) => d['tipe'] == 'Masuk').length;
        int totalPulang = snapshot.data!.docs.where((d) => d['tipe'] == 'Pulang').length;
        String bulanIni = DateFormat('MMMM yyyy', 'id_ID').format(now);

        return Column(
          children: [
            Text(bulanIni, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Hadir",
                    "$totalMasuk hari",
                    Icons.login,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Tepat Pulang",
                    "$totalPulang hari",
                    Icons.logout,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}
