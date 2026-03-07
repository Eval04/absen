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
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: darkBlue,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/Logo_no_bg.png'),
        ),
        title: const Text(
          'SIMAGANG Dishub',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // ✅ FITUR #9: Tombol halaman profil
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
                // HEADER INFO USER
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Selamat Datang, ${userData['nama'] ?? 'Pegawai'}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text("NIP : ${userData['nip'] ?? '-'}",
                          style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text("Asal Kampus : ${userData['univ'] ?? '-'}",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

                // ✅ FITUR #6: BANNER NOTIFIKASI STATUS IZIN
                _buildNotifIzin(),

                // BANNER TANGGAL
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      "$hariIni  $jamSekarang",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),

                // KARTU STATUS DINAMIS
                _buildStatusCard(),
                const SizedBox(height: 20),

                // TOMBOL ABSEN DINAMIS
                _buildTombolAbsen(),
                const SizedBox(height: 12),

                // TOMBOL AJUKAN IZIN
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.assignment_outlined, color: accentOrange),
                      label: Text(
                        "Ajukan Izin / Sakit",
                        style: TextStyle(fontWeight: FontWeight.bold, color: accentOrange),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentOrange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                _buildRiwayatSection(),
                const SizedBox(height: 20),
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
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentOrange.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentOrange,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Text("Status Kehadiran Hari Ini:",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  padding: EdgeInsets.all(16),
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
                statusTeks = "Selesai";
                subTeks = "Masuk: $jamMasuk  |  Pulang: $jamPulang";
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
              } else if (sudahMasuk) {
                statusTeks = "Sudah Absen Masuk";
                subTeks = "Jam masuk: $jamMasuk — Jangan lupa absen pulang!";
                statusColor = Colors.blue;
                statusIcon = Icons.access_time;
              } else {
                statusTeks = "Belum Absen";
                subTeks = "Anda belum melakukan absen masuk.";
                statusColor = Colors.orange;
                statusIcon = Icons.warning_amber;
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(statusTeks,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor)),
                          const SizedBox(height: 4),
                          Text(subTeks, style: const TextStyle(color: Colors.black54)),
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
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login, color: Colors.white),
                  label: Text(
                    sudahMasuk ? "Sudah Absen Masuk ✓" : "Absen Masuk",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: (isLoading || sudahMasuk) ? null : () => submitAbsen("Masuk"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sudahMasuk ? Colors.grey : darkBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.logout,
                      color: (sudahPulang || !sudahMasuk) ? Colors.grey : Colors.black87),
                  label: Text(
                    sudahPulang ? "Sudah Absen Pulang ✓" : "Absen Pulang",
                    style: TextStyle(
                      color: (sudahPulang || !sudahMasuk) ? Colors.grey : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: (isLoading || sudahPulang || !sudahMasuk) ? null : () => submitAbsen("Pulang"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
              if (isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text("Riwayat Absen",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(height: 1),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('absensi')
                .where('uid', isEqualTo: currentUser?.uid)
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 50);
              if (snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text("Belum ada riwayat absen.")),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data();
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      data['tipe'] == 'Masuk' ? Icons.login : Icons.logout,
                      color: data['tipe'] == 'Masuk' ? Colors.green : Colors.red,
                    ),
                    title: Text(data['tanggal'],
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text("Jam: ${data['jam']}"),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: data['tipe'] == "Masuk" ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        data['tipe'],
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ✅ FITUR #6: Banner notifikasi status izin terbaru
  Widget _buildNotifIzin() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('izin')
          .where('uid', isEqualTo: currentUser?.uid)
          .where('status', whereIn: ['approved', 'rejected'])
          .orderBy('created_at', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();

        var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';
        String tanggal = data['tanggal'] ?? '';
        String jenis = data['jenis'] ?? 'Izin';
        bool sudahDibaca = data['sudah_dibaca'] ?? false;

        if (sudahDibaca) return const SizedBox();

        bool approved = status == 'approved';
        Color bgColor = approved ? Colors.green.shade50 : Colors.red.shade50;
        Color borderColor = approved ? Colors.green : Colors.red;
        IconData icon = approved ? Icons.check_circle : Icons.cancel;
        String pesanStatus = approved ? "disetujui" : "ditolak";

        return GestureDetector(
          onTap: () async {
            // Tandai sudah dibaca
            await FirebaseFirestore.instance
                .collection('izin')
                .doc(snapshot.data!.docs.first.id)
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
                Icon(icon, color: borderColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pengajuan $jenis Anda $pesanStatus",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: borderColor,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        "Tanggal: $tanggal  •  Ketuk untuk tutup",
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
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
