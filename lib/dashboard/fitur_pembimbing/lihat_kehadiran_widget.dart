import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;

// ✅ FIX: Conditional import — hanya load dart:html di Web, stub di Mobile
import 'download_stub.dart'
    if (dart.library.html) 'download_web.dart';

class LihatKehadiranWidget extends StatefulWidget {
  const LihatKehadiranWidget({super.key});

  @override
  State<LihatKehadiranWidget> createState() => _LihatKehadiranWidgetState();
}

class _LihatKehadiranWidgetState extends State<LihatKehadiranWidget> {
  DateTime _focusedDay = DateTime.now();
  String _searchName = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getDaysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;
  int _getFirstDayOffset(DateTime date) => DateTime(date.year, date.month, 1).weekday;

  void _changeMonth(int offset) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + offset, 1);
    });
  }

  // ✅ FIX: Export Excel dengan query yang benar (pakai field 'bulan' & 'tahun')
  Future<void> _exportToExcel({bool perUser = false}) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Export Excel hanya tersedia di Web.")),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      // ✅ Query pakai field 'bulan' & 'tahun' yang sekarang sudah disimpan
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('absensi')
          .where('bulan', isEqualTo: _focusedDay.month)
          .where('tahun', isEqualTo: _focusedDay.year)
          .get();

      var excelFile = Excel.createExcel();
      Sheet sheet = excelFile['Rekap Absensi'];
      excelFile.delete('Sheet1');

      // Header
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Nama'),
        TextCellValue('Asal Kampus'),
        TextCellValue('Tanggal'),
        TextCellValue('Jam'),
        TextCellValue('Keterangan'),
      ]);

      // Sortir & filter
      List<QueryDocumentSnapshot> docs = snapshot.docs;
      if (_searchName.isNotEmpty) {
        docs = docs.where((d) {
          String nama = (d['nama'] ?? '').toString().toLowerCase();
          return nama.contains(_searchName.toLowerCase());
        }).toList();
      }
      docs.sort((a, b) {
        try {
          Timestamp tA = a['timestamp'];
          Timestamp tB = b['timestamp'];
          return tA.compareTo(tB);
        } catch (_) {
          return 0;
        }
      });

      int no = 1;
      for (var doc in docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        sheet.appendRow([
          IntCellValue(no++),
          TextCellValue(data['nama'] ?? '-'),
          TextCellValue(data['univ'] ?? '-'),
          TextCellValue(data['tanggal'] ?? '-'),
          TextCellValue(data['jam'] ?? '-'),
          TextCellValue(data['tipe'] ?? '-'),
        ]);
      }

      var fileBytes = excelFile.save();
      if (fileBytes != null) {
        // ✅ FITUR #8: Nama file berbeda jika export per-user
        String fileName = perUser && _searchName.isNotEmpty
            ? "Rekap_${_searchName}_${DateFormat('MMMM_yyyy', 'id_ID').format(_focusedDay)}.xlsx"
            : "Rekap_Absensi_${DateFormat('MMMM_yyyy', 'id_ID').format(_focusedDay)}.xlsx";
        downloadFile(fileBytes, fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("File berhasil di-download!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal Export: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalDays = _getDaysInMonth(_focusedDay);
    int firstDayOffset = _getFirstDayOffset(_focusedDay);
    int gridOffset = firstDayOffset - 1;

    return Column(
      children: [
        // FILTER NAMA
        Row(
          children: [
            const Text("Filter: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 35,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Ketik Nama...",
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, size: 16),
                      onPressed: () => setState(() => _searchName = _searchController.text),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => setState(() => _searchName = val),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // HEADER BULAN & TOMBOL DOWNLOAD
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => _changeMonth(-1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Text(
              DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => _changeMonth(1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const Spacer(),
            SizedBox(
              height: 30,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportToExcel,
                icon: _isExporting
                    ? const SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.download, size: 14, color: Colors.white),
                label: const Text("Rekap", style: TextStyle(fontSize: 11, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
            // ✅ FITUR #8: Export per-user (hanya tampil jika ada filter nama)
            if (_searchName.isNotEmpty) ...[
              const SizedBox(width: 6),
              SizedBox(
                height: 30,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : () => _exportToExcel(perUser: true),
                  icon: const Icon(Icons.person, size: 12, color: Colors.white),
                  label: const Text("Per-User", style: TextStyle(fontSize: 11, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 10),

        // NAMA HARI
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ["Sn", "Sl", "Rb", "Km", "Jm", "Sb", "Mg"]
              .map((day) => SizedBox(
                    width: 30,
                    child: Text(day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ))
              .toList(),
        ),

        const SizedBox(height: 5),

        // GRID KALENDER
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // ✅ FIX: Query pakai field 'bulan' & 'tahun' yang benar
            stream: FirebaseFirestore.instance
                .collection('absensi')
                .where('bulan', isEqualTo: _focusedDay.month)
                .where('tahun', isEqualTo: _focusedDay.year)
                .snapshots(),
            builder: (context, snapshot) {
              Set<int> hadirDates = {};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (_searchName.isNotEmpty) {
                    String namaUser = (data['nama'] ?? '').toString().toLowerCase();
                    if (!namaUser.contains(_searchName.toLowerCase())) continue;
                  }
                  // ✅ FIX: Baca dari field 'tanggal' string, ambil hari-nya
                  String? tanggalStr = data['tanggal'];
                  if (tanggalStr != null) {
                    try {
                      DateTime tgl = DateTime.parse(tanggalStr);
                      hadirDates.add(tgl.day);
                    } catch (_) {}
                  }
                }
              }

              return GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                itemCount: totalDays + gridOffset,
                itemBuilder: (context, index) {
                  if (index < gridOffset) return const SizedBox();
                  int day = index - gridOffset + 1;
                  bool isHadir = hadirDates.contains(day);
                  bool isToday = day == DateTime.now().day &&
                      _focusedDay.month == DateTime.now().month &&
                      _focusedDay.year == DateTime.now().year;

                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isHadir
                          ? const Color(0xFF0B5FA5)
                          : (isToday ? Colors.blue[100] : Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                      border: isToday ? Border.all(color: Colors.blue) : null,
                    ),
                    child: Text(
                      "$day",
                      style: TextStyle(
                        color: isHadir ? Colors.white : Colors.black87,
                        fontSize: 11,
                        fontWeight: isHadir ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 5),

        // LEGENDA
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 10, height: 10, color: const Color(0xFF0B5FA5)),
            const SizedBox(width: 5),
            const Text("Hadir", style: TextStyle(fontSize: 10)),
            const SizedBox(width: 15),
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue), color: Colors.blue[100]),
            ),
            const SizedBox(width: 5),
            const Text("Hari Ini", style: TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
