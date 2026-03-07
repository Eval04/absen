import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'Login.dart';
import 'IzinPage.dart';
import 'ProfilPage.dart';

class UserAbsenPage extends StatefulWidget {
  const UserAbsenPage({super.key});

  @override
  State<UserAbsenPage> createState() => _UserAbsenPageState();
}

class _UserAbsenPageState extends State<UserAbsenPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool isLoading = false;

  // Koordinat kantor — diambil dari Firestore (bukan hardcoded)
  double officeLat = -5.1476;
  double officeLng = 119.4327;
  double maxRadius = 100;

  final Color primaryBlue = const Color(0xFF0D61B1);
  final Color darkBlue = const Color(0xFF03254C);
  final Color accentOrange = const Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    _loadOfficeLocation();
  }

  // ✅ FIX: Baca koordinat kantor dari Firestore
  Future<void> _loadOfficeLocation() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('kantor')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          officeLat = (doc.data()?['lat'] ?? officeLat).toDouble();
          officeLng = (doc.data()?['lng'] ?? officeLng).toDouble();
          maxRadius = (doc.data()?['radius'] ?? maxRadius).toDouble();
        });
      }
    } catch (e) {
      debugPrint("Gagal load lokasi kantor: $e");
    }
  }

  // ✅ FIX #2: Validasi jam absen — baca dari Firestore settings
  Future<bool> _cekJamAbsen(String tipe) async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('kantor')
          .get();
      if (!doc.exists) return true; // jika belum diatur, izinkan

      String jamMasukStr = doc.data()?['jam_masuk'] ?? '08:00';
      String jamPulangStr = doc.data()?['jam_pulang'] ?? '17:00';

      final now = TimeOfDay.now();
      final nowMenit = now.hour * 60 + now.minute;

      final masukParts = jamMasukStr.split(':');
      final pulangParts = jamPulangStr.split(':');
      final masukMenit = int.parse(masukParts[0]) * 60 + int.parse(masukParts[1]);
      final pulangMenit = int.parse(pulangParts[0]) * 60 + int.parse(pulangParts[1]);

      // Toleransi 30 menit sebelum jam masuk & sesudah jam pulang
      const toleransi = 30;

      if (tipe == 'Masuk') {
        if (nowMenit < masukMenit - toleransi) {
          _showSnackbar(
            "Terlalu awal! Absen masuk mulai ${_menitKeJam(masukMenit - toleransi)}.",
            Colors.orange,
          );
          return false;
        }
        if (nowMenit > pulangMenit) {
          _showSnackbar("Jam kerja sudah selesai.", Colors.red);
          return false;
        }
      } else if (tipe == 'Pulang') {
        if (nowMenit < pulangMenit - toleransi) {
          _showSnackbar(
            "Belum waktunya pulang. Jam pulang: $jamPulangStr.",
            Colors.orange,
          );
          return false;
        }
      }
      return true;
    } catch (e) {
      return true; // jika error, izinkan absen
    }
  }

  String _menitKeJam(int totalMenit) {
    final jam = totalMenit ~/ 60;
    final menit = totalMenit % 60;
    return '${jam.toString().padLeft(2, '0')}:${menit.toString().padLeft(2, '0')}';
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<bool> checkLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackbar("GPS tidak aktif. Mohon aktifkan GPS.", Colors.red);
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackbar("Izin lokasi ditolak permanen.", Colors.red);
      return false;
    }
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude, position.longitude, officeLat, officeLng,
      );
      if (distanceInMeters > maxRadius) {
        _showSnackbar("Terlalu jauh dari kantor! Jarak: ${distanceInMeters.toInt()}m", Colors.orange);
        return false;
      }
      return true;
    } catch (e) {
      _showSnackbar("Gagal mendapatkan lokasi.", Colors.red);
      return false;
    }
  }

  // ✅ FIX: Cek duplikat — 1x Masuk + 1x Pulang per hari
  Future<Map<String, bool>> _getStatusAbsenHariIni() async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    QuerySnapshot result = await FirebaseFirestore.instance
        .collection('absensi')
        .where('uid', isEqualTo: currentUser?.uid)
        .where('tanggal', isEqualTo: today)
        .get();
    bool sudahMasuk = result.docs.any((d) => d['tipe'] == 'Masuk');
    bool sudahPulang = result.docs.any((d) => d['tipe'] == 'Pulang');
    return {'masuk': sudahMasuk, 'pulang': sudahPulang};
  }

  Future<void> submitAbsen(String tipe) async {
    setState(() => isLoading = true);
    try {
      // Cek duplikat dulu sebelum GPS (lebih efisien)
      Map<String, bool> status = await _getStatusAbsenHariIni();
      if (tipe == 'Masuk' && status['masuk'] == true) {
        _showSnackbar("Anda sudah absen Masuk hari ini.", Colors.orange);
        return;
      }
      if (tipe == 'Pulang' && status['pulang'] == true) {
        _showSnackbar("Anda sudah absen Pulang hari ini.", Colors.orange);
        return;
      }
      if (tipe == 'Pulang' && status['masuk'] == false) {
        _showSnackbar("Anda belum absen Masuk hari ini.", Colors.orange);
        return;
      }

      // ✅ FIX #2: Validasi jam kerja dari setting admin
      bool jamValid = await _cekJamAbsen(tipe);
      if (!jamValid) return;

      bool isAtLocation = await checkLocation();
      if (!isAtLocation) return;

      Position pos = await Geolocator.getCurrentPosition();
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users').doc(currentUser?.uid).get();
      String namaUser = userDoc['nama'] ?? "Pegawai";
      String instansiUser = userDoc['univ'] ?? "-";

      DateTime now = DateTime.now();

      // ✅ FIX: Simpan field 'bulan' & 'tahun' untuk query kalender admin
      await FirebaseFirestore.instance.collection('absensi').add({
        'uid': currentUser?.uid,
        'nama': namaUser,
        'univ': instansiUser,
        'tanggal': DateFormat('yyyy-MM-dd').format(now),
        'jam': DateFormat('HH:mm').format(now),
        'tipe': tipe,
        'bulan': now.month,
        'tahun': now.year,
        'lokasi': GeoPoint(pos.latitude, pos.longitude),
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });

      _showSnackbar("Absen $tipe Berhasil! 🎉", Colors.green);
    } catch (e) {
      _showSnackbar("Gagal absen: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    String hariIni = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());
    String jamSekarang = DateFormat('HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: darkBlue,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/Logo_no_bg.png',
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.directions_bus, color: Colors.yellow)),
        ),
        title: const Text(
          'SIMAGANG Dishub',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(currentUser?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData = snapshot.data!.data()!;

          return SingleChildScrollView(
            child: Column(
              children: [
                // ═══ HERO HEADER — gradient dengan info user + tanggal ═══
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [darkBlue, primaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tanggal & jam
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            hariIni,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        jamSekarang,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      // Info user
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white24,
                            child: Text(
                              (userData['nama'] ?? 'U').substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData['nama'] ?? 'Pegawai',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "${userData['univ'] ?? '-'}  •  NIP: ${userData['nip'] ?? '-'}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ═══ NOTIFIKASI IZIN ═══
                _buildNotifIzin(),

                const SizedBox(height: 16),

                // ═══ KARTU STATUS ═══
                _buildStatusCard(),
                const SizedBox(height: 16),

                // ═══ TOMBOL ABSEN ═══
                _buildTombolAbsen(),
                const SizedBox(height: 12),

                // ═══ TOMBOL IZIN ═══
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.assignment_outlined, color: accentOrange, size: 20),
                      label: Text(
                        "Ajukan Izin / Sakit",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: accentOrange, fontSize: 15),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentOrange, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.orange.withOpacity(0.04),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IzinPage(
                            uid: currentUser!.uid,
                            nama: userData['nama'] ?? 'Pegawai',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ═══ RIWAYAT ABSEN ═══
                _buildRiwayatSection(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard() {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Header kartu
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: accentOrange.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.today, size: 16, color: accentOrange),
                const SizedBox(width: 6),
                Text("Status Kehadiran Hari Ini",
                    style: TextStyle(color: accentOrange, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('absensi')
                .where('uid', isEqualTo: currentUser?.uid)
                .where('tanggal', isEqualTo: today)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              bool sudahMasuk = snapshot.data!.docs.any((d) => d['tipe'] == 'Masuk');
              bool sudahPulang = snapshot.data!.docs.any((d) => d['tipe'] == 'Pulang');
              String? jamMasuk, jamPulang;
              for (var doc in snapshot.data!.docs) {
                if (doc['tipe'] == 'Masuk') jamMasuk = doc['jam'];
                if (doc['tipe'] == 'Pulang') jamPulang = doc['jam'];
              }

              String statusTeks;
              String subTeks;
              Color statusColor;
              IconData statusIcon;

              if (sudahPulang) {
                statusTeks = "Selesai Hari Ini";
                subTeks = "Masuk: $jamMasuk  |  Pulang: $jamPulang";
                statusColor = Colors.green;
                statusIcon = Icons.check_circle_rounded;
              } else if (sudahMasuk) {
                statusTeks = "Sedang Bekerja";
                subTeks = "Masuk: $jamMasuk  —  Jangan lupa absen pulang!";
                statusColor = Colors.blue;
                statusIcon = Icons.work_rounded;
              } else {
                statusTeks = "Belum Absen";
                subTeks = "Anda belum melakukan absen masuk hari ini.";
                statusColor = Colors.orange;
                statusIcon = Icons.pending_rounded;
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(statusTeks,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16, color: statusColor)),
                          const SizedBox(height: 3),
                          Text(subTeks,
                              style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  Widget _buildTombolAbsen() {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('absensi')
          .where('uid', isEqualTo: currentUser?.uid)
          .where('tanggal', isEqualTo: today)
          .snapshots(),
      builder: (context, snapshot) {
        bool sudahMasuk = false;
        bool sudahPulang = false;
        if (snapshot.hasData) {
          sudahMasuk = snapshot.data!.docs.any((d) => d['tipe'] == 'Masuk');
          sudahPulang = snapshot.data!.docs.any((d) => d['tipe'] == 'Pulang');
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // TOMBOL MASUK
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: Icon(
                    sudahMasuk ? Icons.check_circle : Icons.login,
                    color: Colors.white,
                    size: 22,
                  ),
                  label: Text(
                    sudahMasuk ? "Sudah Absen Masuk ✓" : "Absen Masuk",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: (isLoading || sudahMasuk) ? null : () => submitAbsen("Masuk"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sudahMasuk ? Colors.grey[400] : darkBlue,
                    elevation: sudahMasuk ? 0 : 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // TOMBOL PULANG
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: Icon(
                    sudahPulang ? Icons.check_circle : Icons.logout,
                    color: (sudahPulang || !sudahMasuk) ? Colors.grey : darkBlue,
                    size: 22,
                  ),
                  label: Text(
                    sudahPulang ? "Sudah Absen Pulang ✓" : "Absen Pulang",
                    style: TextStyle(
                      color: (sudahPulang || !sudahMasuk) ? Colors.grey : darkBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onPressed:
                      (isLoading || sudahPulang || !sudahMasuk) ? null : () => submitAbsen("Pulang"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: (sudahPulang || !sudahMasuk) ? 0 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: (sudahPulang || !sudahMasuk) ? Colors.grey.shade300 : darkBlue,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (isLoading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildRiwayatSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text("Riwayat Absen",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(height: 16),
          // ✅ FIX: Hapus orderBy — sort di client, tidak butuh Firestore index
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('absensi')
                .where('uid', isEqualTo: currentUser?.uid)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 36, color: Colors.grey),
                        SizedBox(height: 8),
                        Text("Belum ada riwayat absen.", style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                );
              }

              // Sort terbaru di sisi client
              var docs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  Timestamp? tA = a.data()['timestamp'] as Timestamp?;
                  Timestamp? tB = b.data()['timestamp'] as Timestamp?;
                  if (tA == null || tB == null) return 0;
                  return tB.compareTo(tA);
                });
              // Ambil 10 terbaru setelah sort
              if (docs.length > 10) docs = docs.sublist(0, 10);

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  var data = docs[index].data();
                  bool isMasuk = data['tipe'] == 'Masuk';
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: (isMasuk ? Colors.green : Colors.red).withOpacity(0.12),
                      child: Icon(
                        isMasuk ? Icons.login : Icons.logout,
                        color: isMasuk ? Colors.green : Colors.red,
                        size: 18,
                      ),
                    ),
                    title: Text(data['tanggal'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text("Jam: ${data['jam'] ?? '-'}",
                        style: const TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMasuk ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        data['tipe'] ?? '-',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ✅ FITUR #6: Banner notifikasi status izin terbaru
  Widget _buildNotifIzin() {
    // ✅ FIX: Hapus orderBy + whereIn — query sederhana, filter di client
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('izin')
          .where('uid', isEqualTo: currentUser?.uid)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();

        // Cari izin yang sudah diproses dan belum dibaca, ambil terbaru
        List<QueryDocumentSnapshot> prosedDocs = snapshot.data!.docs.where((doc) {
          var d = doc.data() as Map<String, dynamic>;
          String status = d['status'] ?? 'pending';
          bool sudahDibaca = d['sudah_dibaca'] ?? false;
          return (status == 'approved' || status == 'rejected') && !sudahDibaca;
        }).toList();

        if (prosedDocs.isEmpty) return const SizedBox();

        var doc = prosedDocs.first;
        var data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';
        String tanggal = data['tanggal'] ?? '';
        String jenis = data['jenis'] ?? 'Izin';

        bool approved = status == 'approved';
        Color bgColor = approved ? Colors.green.shade50 : Colors.red.shade50;
        Color borderColor = approved ? Colors.green : Colors.red;
        IconData icon = approved ? Icons.check_circle : Icons.cancel;
        String pesanStatus = approved ? "disetujui ✓" : "ditolak ✗";

        return GestureDetector(
          onTap: () async {
            await FirebaseFirestore.instance
                .collection('izin')
                .doc(doc.id)
                .update({'sudah_dibaca': true});
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(icon, color: borderColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pengajuan $jenis Anda $pesanStatus",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: borderColor, fontSize: 13),
                      ),
                      Text("Tanggal: $tanggal  •  Ketuk untuk tutup",
                          style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
                Icon(Icons.close, size: 16, color: borderColor),
              ],
            ),
          ),
        );
      },
    );
  }
}
