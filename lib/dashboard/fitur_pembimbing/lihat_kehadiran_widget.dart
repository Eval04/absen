import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// PENTING: Gunakan 'hide Border' agar tidak bentrok dengan Border Flutter
import 'package:excel/excel.dart' hide Border; 

// KHUSUS WEB: Kita pakai library html bawaan Dart
import 'dart:html' as html; 

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

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _getFirstDayOffset(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + offset, 1);
    });
  }

  // --- FITUR EXPORT EXCEL (KHUSUS WEB) ---
  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      // 1. Ambil Data
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('absensi')
          .where('bulan', isEqualTo: _focusedDay.month)
          .where('tahun', isEqualTo: _focusedDay.year)
          .get();

      // 2. Siapkan Excel
      var excel = Excel.createExcel();
      Sheet sheet = excel['Rekap Absensi'];
      excel.delete('Sheet1');

      // Header
      CellStyle headerStyle = CellStyle(
        bold: true, 
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.blueGrey200
      );

      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Nama Magang'),
        TextCellValue('Tanggal'),
        TextCellValue('Waktu Absen'),
        TextCellValue('Status'),
      ]);

      // 3. Masukkan Data
      int no = 1;
      List<QueryDocumentSnapshot> docs = snapshot.docs;
      
      // Sortir data berdasarkan waktu
      docs.sort((a, b) {
        Timestamp tA = a['created_at'];
        Timestamp tB = b['created_at'];
        return tA.compareTo(tB);
      });

      for (var doc in docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Filter Nama
        if (_searchName.isNotEmpty) {
          String namaUser = (data['nama'] ?? '').toString().toLowerCase();
          if (!namaUser.contains(_searchName.toLowerCase())) continue;
        }

        DateTime tgl = (data['created_at'] as Timestamp).toDate();
        String tanggalStr = DateFormat('dd MMMM yyyy', 'id_ID').format(tgl);
        String jamStr = DateFormat('HH:mm').format(tgl);

        sheet.appendRow([
          IntCellValue(no++),
          TextCellValue(data['nama'] ?? '-'),
          TextCellValue(tanggalStr),
          TextCellValue(jamStr),
          TextCellValue('Hadir'),
        ]);
      }

      // 4. SIMPAN FILE (LOGIKA WEB DOWNLOAD)
      var fileBytes = excel.save();

      if (fileBytes != null) {
        // Buat BLOB (Binary Large Object) untuk browser
        final blob = html.Blob([fileBytes]);
        
        // Buat URL sementara
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        // Buat elemen <a> palsu untuk memicu download
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "Rekap_Absensi_${DateFormat('MMMM_yyyy', 'id_ID').format(_focusedDay)}.xlsx")
          ..click(); // Klik otomatis
          
        // Bersihkan URL agar hemat memori
        html.Url.revokeObjectUrl(url);

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

            // TOMBOL DOWNLOAD EXCEL
            SizedBox(
              height: 30,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportToExcel,
                icon: _isExporting 
                  ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download, size: 14, color: Colors.white),
                label: const Text("Rekap", style: TextStyle(fontSize: 11, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700], 
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            )
          ],
        ),

        const SizedBox(height: 10),

        // NAMA HARI
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ["Sn", "Sl", "Rb", "Km", "Jm", "Sb", "Mg"]
              .map((day) => SizedBox(
                    width: 30, 
                    child: Text(
                      day, 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
                    )
                  ))
              .toList(),
        ),

        const SizedBox(height: 5),

        // GRID KALENDER
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
                  
                  if (data['created_at'] != null) {
                     DateTime tgl = (data['created_at'] as Timestamp).toDate();
                     hadirDates.add(tgl.day); 
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
                      color: isHadir ? const Color(0xFF0B5FA5) : (isToday ? Colors.blue[100] : Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                      // Aman karena kita sudah 'hide Border' dari excel
                      border: isToday ? Border.all(color: Colors.blue) : null,
                    ),
                    child: Text(
                      "$day",
                      style: TextStyle(
                        color: isHadir ? Colors.white : Colors.black87,
                        fontSize: 11,
                        fontWeight: isHadir ? FontWeight.bold : FontWeight.normal
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        
        // LEGENDA
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 10, height: 10, color: const Color(0xFF0B5FA5)),
            const SizedBox(width: 5),
            const Text("Hadir", style: TextStyle(fontSize: 10)),
            const SizedBox(width: 15),
            Container(width: 10, height: 10, decoration: BoxDecoration(border: Border.all(color: Colors.blue), color: Colors.blue[100])),
            const SizedBox(width: 5),
            const Text("Hari Ini", style: TextStyle(fontSize: 10)),
          ],
        )
      ],
    );
  }
}