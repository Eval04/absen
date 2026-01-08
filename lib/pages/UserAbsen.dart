import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'Login.dart'; // Pastikan import ini sesuai dengan nama file Login Anda

class UserAbsenPage extends StatefulWidget {
  const UserAbsenPage({super.key});

  @override
  State<UserAbsenPage> createState() => _UserAbsenPageState();
}

class _UserAbsenPageState extends State<UserAbsenPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool isLoading = false;

  // KONFIGURASI LOKASI KANTOR
  final double officeLat = -5.1476;
  final double officeLng = 119.4327;
  final double maxRadius = 100;

  // Skema Warna
  final Color primaryBlue = const Color(0xFF0D61B1);
  final Color darkBlue = const Color(0xFF03254C);
  final Color accentOrange = const Color(0xFFFF9800);

  // --- FUNGSI LOGOUT ---
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  // --- FUNGSI CEK LOKASI ---
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
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );

      if (distanceInMeters > maxRadius) {
        _showSnackbar(
          "Terlalu jauh! Jarak: ${distanceInMeters.toInt()}m",
          Colors.orange,
        );
        return false;
      }
      return true;
    } catch (e) {
      _showSnackbar("Gagal mendapatkan lokasi.", Colors.red);
      return false;
    }
  }

  // --- FUNGSI SUBMIT ABSEN ---
  Future<void> submitAbsen(String tipe) async {
    setState(() => isLoading = true);

    bool isAtLocation = await checkLocation();
    if (!isAtLocation) {
      setState(() => isLoading = false);
      return;
    }

    try {
      Position pos = await Geolocator.getCurrentPosition();

      // Ambil data user terbaru untuk disimpan di history
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get();
      String namaUser = userDoc['nama'] ?? "Pegawai";
      String instansiUser = userDoc['univ'] ?? "-";

      await FirebaseFirestore.instance.collection('absensi').add({
        'uid': currentUser?.uid,
        'nama': namaUser,
        'univ': instansiUser, // Simpan asal kampus di riwayat absen
        'tanggal': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'jam': DateFormat('HH:mm').format(DateTime.now()),
        'tipe': tipe,
        'lokasi': GeoPoint(pos.latitude, pos.longitude),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackbar("Absen $tipe Berhasil!", Colors.green);
    } catch (e) {
      _showSnackbar("Gagal absen: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    String hariIni = DateFormat(
      'EEEE, d MMMM yyyy',
      'id_ID',
    ).format(DateTime.now());
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
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: CircularProgressIndicator());
          final userData = snapshot.data!.data()!;

          // Ambil data 'univ', jika tidak ada tampilkan '-'
          String userUniv = userData['univ'] ?? '-';

          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. HEADER INFO USER (Putih)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama User
                      Text(
                        "Selamat Datang, ${userData['nama'] ?? 'Pegawai'}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // NIP
                      Text(
                        "NIP : ${userData['nip'] ?? '-'}",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),

                      // Asal Kampus (Field Baru di Bawah NIP)
                      const SizedBox(height: 4),
                      Text(
                        "Asal Kampus : $userUniv",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. BANNER TANGGAL
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
                      "$hariIni  $jamSekarang WIB",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                // 3. KARTU STATUS
                Container(
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
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Status Kehadiran:",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Belum Absen",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Anda belum melakukan absen masuk.",
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. TOMBOL ABSEN
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildActionButton(
                        "Absen Masuk",
                        darkBlue,
                        () => submitAbsen("Masuk"),
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        "Absen Pulang",
                        Colors.white,
                        () => submitAbsen("Pulang"),
                        isOutlined: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 5. RIWAYAT ABSEN
                _buildRiwayatSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    Color color,
    VoidCallback onPressed, {
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isOutlined
                ? BorderSide(color: Colors.grey.shade400)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: isOutlined ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
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
            child: Text(
              "Riwayat Absen",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const Divider(height: 1),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('absensi')
                .where('uid', isEqualTo: currentUser?.uid)
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 50);
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data();
                  return ListTile(
                    dense: true,
                    title: Text(
                      data['tanggal'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: _buildStatusBadge(data['tipe']),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: status == "Masuk" ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status == "Masuk" ? "Hadir" : "Pulang",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
