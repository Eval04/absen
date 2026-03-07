import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JamAbsenWidget extends StatefulWidget {
  const JamAbsenWidget({super.key});

  @override
  State<JamAbsenWidget> createState() => _JamAbsenWidgetState();
}

class _JamAbsenWidgetState extends State<JamAbsenWidget> {
  TimeOfDay _jamMasuk = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _jamPulang = const TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadJam();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _loadJam() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('kantor')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _jamMasuk = _parseTime(doc.data()?['jam_masuk'] ?? '08:00');
          _jamPulang = _parseTime(doc.data()?['jam_pulang'] ?? '17:00');
        });
      }
    } catch (e) {
      debugPrint("Error load jam: $e");
    }
  }

  Future<void> _pilihJam(bool isMasuk) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isMasuk ? _jamMasuk : _jamPulang,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isMasuk) {
          _jamMasuk = picked;
        } else {
          _jamPulang = picked;
        }
      });
    }
  }

  Future<void> _simpanJam() async {
    // Validasi jam masuk < jam pulang
    final masukMenit = _jamMasuk.hour * 60 + _jamMasuk.minute;
    final pulangMenit = _jamPulang.hour * 60 + _jamPulang.minute;
    if (masukMenit >= pulangMenit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Jam masuk harus lebih awal dari jam pulang!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('kantor')
          .set({
        'jam_masuk': _formatTime(_jamMasuk),
        'jam_pulang': _formatTime(_jamPulang),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Jam absen berhasil disimpan!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal simpan: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildJamPicker(String label, TimeOfDay jam, bool isMasuk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pilihJam(isMasuk),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isMasuk ? Icons.login : Icons.logout,
                  size: 18,
                  color: isMasuk ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  _formatTime(jam),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.edit, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blue),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Anak magang hanya bisa absen dalam rentang jam ini.",
                    style: TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _buildJamPicker("Jam Masuk (Start)", _jamMasuk, true),
          const SizedBox(height: 12),
          _buildJamPicker("Jam Pulang (End)", _jamPulang, false),

          const SizedBox(height: 8),
          Center(
            child: Text(
              "Durasi: ${((_jamPulang.hour * 60 + _jamPulang.minute) - (_jamMasuk.hour * 60 + _jamMasuk.minute)) ~/ 60} jam ${((_jamPulang.hour * 60 + _jamPulang.minute) - (_jamMasuk.hour * 60 + _jamMasuk.minute)) % 60} menit",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _simpanJam,
              icon: _isLoading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 16, color: Colors.white),
              label: const Text("SIMPAN JAM", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
