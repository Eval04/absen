import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- IMPORT WIDGETS ---
import '../widgets/admin_sidebar.dart';
import '../widgets/dashboard_card.dart';

// --- IMPORT FITUR ---
import 'fitur_pembimbing/daftar_magang_widget.dart';
import 'fitur_pembimbing/validasi_izin_widget.dart';
// 1. IMPORT FITUR BARU DI SINI
import 'fitur_pembimbing/lihat_kehadiran_widget.dart'; 

import 'fitur_admin/form_tambah_magang.dart';
import 'fitur_admin/jam_absen_widget.dart';
import 'fitur_admin/map_lokasi_widget.dart';

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
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
      case 0: return _buildOverview();
      case 1: return _buildPembimbingOnly();
      case 2: return _buildAdminOnly();
      default: return _buildOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SIDEBAR
          SizedBox(
            width: 260,
            child: AdminSidebar(
              selectedIndex: _selectedIndex,
              adminName: _adminName,
              onItemSelected: (index) => setState(() => _selectedIndex = index),
              onSignOut: () async => await FirebaseAuth.instance.signOut(),
            ),
          ),
          // KONTEN
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Dashboard Overview", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildPembimbingOnly(showTitle: false),
        const SizedBox(height: 40),
        const Divider(),
        const SizedBox(height: 40),
        _buildAdminOnly(showTitle: false),
      ],
    );
  }

  Widget _buildPembimbingOnly({bool showTitle = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text("Menu Pembimbing", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
        ],
        const Text("Manajemen Magang", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        
        Wrap(
          spacing: 20,
          runSpacing: 20,
          // JANGAN PAKAI CONST DI SINI
          children: const [
            DashboardCard(title: "Daftar Anak Magang", width: 350, child: DaftarMagangWidget()),
            
            // 2. PASANG WIDGET BARU DI SINI
            DashboardCard(title: "Lihat Kehadiran Harian", width: 350, child: LihatKehadiranWidget()),
            
            DashboardCard(title: "Validasi Izin & Sakit", width: 350, child: ValidasiIzinWidget()),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminOnly({bool showTitle = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text("Menu Admin", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
        ],
        const Text("Pengaturan Sistem", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: const [
            DashboardCard(title: "Tambah Anak Magang", width: 320, child: FormTambahMagang()),
            DashboardCard(title: "Atur Jam Absen", width: 320, child: JamAbsenWidget()),
            DashboardCard(title: "Atur Lokasi Kantor", width: 320, child: MapLokasiWidget()),
          ],
        ),
      ],
    );
  }
}