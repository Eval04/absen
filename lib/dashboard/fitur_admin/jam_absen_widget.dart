import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JamAbsenWidget extends StatefulWidget {
  const JamAbsenWidget({super.key});

  @override
  State<JamAbsenWidget> createState() => _JamAbsenWidgetState();
}

class _JamAbsenWidgetState extends State<JamAbsenWidget> {
  final _jamMasuk = TextEditingController();
  final _jamPulang = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadJam();
  }

  void _loadJam() async {
    var doc = await FirebaseFirestore.instance.collection('settings').doc('kantor').get();
    if (doc.exists && mounted) {
      setState(() {
        _jamMasuk.text = doc.data()?['jam_masuk'] ?? "08:00";
        _jamPulang.text = doc.data()?['jam_pulang'] ?? "17:00";
      });
    }
  }

  Future<void> _simpanJam() async {
    await FirebaseFirestore.instance.collection('settings').doc('kantor').set({
      'jam_masuk': _jamMasuk.text,
      'jam_pulang': _jamPulang.text,
    }, SetOptions(merge: true));
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jam Berhasil Disimpan")));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Start Time", style: TextStyle(fontSize: 12)),
        const SizedBox(height: 5),
        TextField(controller: _jamMasuk, decoration: const InputDecoration(suffixIcon: Icon(Icons.access_time), border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        const Text("End Time", style: TextStyle(fontSize: 12)),
        const SizedBox(height: 5),
        TextField(controller: _jamPulang, decoration: const InputDecoration(suffixIcon: Icon(Icons.access_time), border: OutlineInputBorder(), isDense: true)),
        const Spacer(),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _simpanJam, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("UPDATE JAM", style: TextStyle(color: Colors.white)))),
      ],
    );
  }
}