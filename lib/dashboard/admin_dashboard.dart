import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/admin_sidebar.dart';
import '../widgets/dashboard_card.dart';

import 'fitur_pembimbing/daftar_magang_widget.dart';
import 'fitur_pembimbing/validasi_izin_widget.dart';
import 'fitur_pembimbing/lihat_kehadiran_widget.dart';

import 'fitur_admin/form_tambah_magang.dart';
import 'fitur_admin/jam_absen_widget.dart';
import 'fitur_admin/map_lokasi_widget.dart';
import 'fitur_admin/reset_password_widget.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  String _adminName = "Memuat...";

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  void _loadAdminData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() => _adminName = doc.data()?['nama'] ?? "Administrator");
        } else if (mounted) {
          setState(() => _adminName = user.email?.split('@')[0] ?? "Admin");
        }
      } catch (e) {
        debugPrint("Err: $e");
      }
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverview();
      case 1:
        return _buildPembimbingOnly();
      case 2:
        return _buildAdminOnly();
      default:
        return _buildOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SIDEBAR — fixed width
          SizedBox(
            width: 260,
            child: AdminSidebar(
              selectedIndex: _selectedIndex,
              adminName: _adminName,
              onItemSelected: (index) => setState(() => _selectedIndex = index),
              onSignOut: () async => await FirebaseAuth.instance.signOut(),
            ),
          ),
          // KONTEN UTAMA
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Overview: tampilkan summary ringkas, bukan semua card sekaligus
  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER GREETING
        _buildGreetingHeader(),
        const SizedBox(height: 24),

        // STAT CARDS RINGKAS
        _buildStatRow(),
        const SizedBox(height: 28),

        // SECTION: PEMBIMBING
        _buildSectionHeader("Manajemen Magang", Icons.people, Colors.blue, 1),
        const SizedBox(height: 12),
        _buildPembimbingCards(),
        const SizedBox(height: 28),

        // SECTION: ADMIN
        _buildSectionHeader("Pengaturan Sistem", Icons.settings, Colors.green, 2),
        const SizedBox(height: 12),
        _buildAdminCards(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGreetingHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B5FA5), Color(0xFF063970)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Selamat Datang, $_adminName",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Dashboard Admin SiMagang Dishub Makassar",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'intern')
          .snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('izin')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, izinSnap) {
            // Hitung user aktif (bukan deleted)
            int totalUser = 0;
            if (userSnap.hasData) {
              totalUser = userSnap.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                return (data['status'] ?? '') != 'deleted';
              }).length;
            }
            int pendingIzin = izinSnap.hasData ? izinSnap.data!.docs.length : 0;

            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Total Magang",
                    "$totalUser orang",
                    Icons.people,
                    const Color(0xFF0B5FA5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Izin Pending",
                    "$pendingIzin pengajuan",
                    Icons.assignment_late,
                    pendingIzin > 0 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, int navIndex) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() => _selectedIndex = navIndex),
          child: Text("Lihat Semua →", style: TextStyle(color: color, fontSize: 12)),
        ),
      ],
    );
  }

  // ✅ Pembimbing: layout responsif dengan LayoutBuilder
  Widget _buildPembimbingCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double available = constraints.maxWidth;
        // Hitung berapa card yang muat per baris
        bool twoPerRow = available >= 700;
        double cardWidth = twoPerRow
            ? (available - 20) / 2
            : available;

        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            DashboardCard(
              title: "Daftar Anak Magang",
              width: cardWidth,
              height: 380,
              child: const DaftarMagangWidget(),
            ),
            DashboardCard(
              title: "Lihat Kehadiran Harian",
              width: cardWidth,
              height: 380,
              child: const LihatKehadiranWidget(),
            ),
            DashboardCard(
              title: "Validasi Izin & Sakit",
              width: cardWidth,
              height: 380,
              child: const ValidasiIzinWidget(),
            ),
          ],
        );
      },
    );
  }

  // ✅ Admin: tinggi card disesuaikan per konten
  Widget _buildAdminCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double available = constraints.maxWidth;
        bool twoPerRow = available >= 700;
        double cardWidth = twoPerRow
            ? (available - 20) / 2
            : available;

        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            DashboardCard(
              title: "Tambah Anak Magang",
              width: cardWidth,
              height: 420, // lebih tinggi karena 5 field
              child: const FormTambahMagang(),
            ),
            DashboardCard(
              title: "Atur Jam Absen",
              width: cardWidth,
              height: 380, // dinaikkan dari 300 → 380
              child: const JamAbsenWidget(),
            ),
            DashboardCard(
              title: "Atur Lokasi Kantor",
              width: cardWidth,
              height: 380,
              child: const MapLokasiWidget(),
            ),
            DashboardCard(
              title: "Reset Password User",
              width: cardWidth,
              height: 380,
              child: const ResetPasswordWidget(),
            ),
          ],
        );
      },
    );
  }

  // Menu Pembimbing penuh (dari sidebar)
  Widget _buildPembimbingOnly({bool showTitle = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text("Menu Pembimbing",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
        ],
        _buildPembimbingCards(),
      ],
    );
  }

  // Menu Admin penuh (dari sidebar)
  Widget _buildAdminOnly({bool showTitle = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text("Menu Admin",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
        ],
        _buildAdminCards(),
      ],
    );
  }
}
