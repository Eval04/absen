import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Jika Anda memiliki file edit_user.dart, biarkan import ini.
// Jika tidak, hapus baris ini agar tidak error.
// import 'edit_user.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // --- KONEKSI FIREBASE ---
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // --- STATE VARIABLES ---
  String _adminName = "Memuat..."; // Default sebelum data diambil
  String _selectedRole = 'intern'; // Default pilihan role di form

  // Loading state untuk peta
  bool _isLoadingMap = false;

  // --- CONTROLLERS (Input Form) ---
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nipController = TextEditingController();
  final TextEditingController _jamMasukController = TextEditingController();
  final TextEditingController _jamPulangController = TextEditingController();

  // --- VARIABLES MAPS ---
  LatLng _selectedLocation = const LatLng(-5.147665, 119.432732);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Load setting jam & lokasi
    _loadAdminData(); // Load nama admin yang login
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nipController.dispose();
    _jamMasukController.dispose();
    _jamPulangController.dispose();
    super.dispose();
  }

  // --- LOGIC FUNCTIONS ---

  // 1. Ambil Nama Admin yang sedang Login
  void _loadAdminData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Cari data user di Firestore berdasarkan email auth yang login
      var query = await _firestore
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        setState(() {
          _adminName = query.docs.first.data()['nama'] ?? "Admin";
        });
      } else {
        setState(() {
          _adminName = user.displayName ?? "Administrator";
        });
      }
    }
  }

  // 2. Load Settings (Lokasi & Jam)
  void _loadSettings() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('settings')
          .doc('kantor')
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _jamMasukController.text = data['jam_masuk'] ?? "08:00";
          _jamPulangController.text = data['jam_pulang'] ?? "17:00";

          if (data['lat'] != null && data['lng'] != null) {
            _selectedLocation = LatLng(data['lat'], data['lng']);
            Future.delayed(const Duration(milliseconds: 500), () {
              _mapController.move(_selectedLocation, 15.0);
            });
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
  }

  // 3. Simpan Pegawai Baru
  Future<void> _addPegawai() async {
    if (_namaController.text.isEmpty || _nipController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama dan NIP wajib diisi!")),
      );
      return;
    }

    try {
      await _firestore.collection('users').add({
        'nama': _namaController.text.trim(),
        'nip': _nipController.text.trim(),
        'role': _selectedRole, // Menggunakan role yang dipilih dari Dropdown
        'email': '${_nipController.text.trim()}@dishub.com', // Dummy email
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
      });

      _namaController.clear();
      _nipController.clear();
      // Reset dropdown ke intern
      setState(() {
        _selectedRole = 'intern';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Data $_selectedRole berhasil ditambahkan")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 4. Simpan Lokasi & Jam
  Future<void> _saveSettings() async {
    setState(() => _isLoadingMap = true);
    try {
      await _firestore.collection('settings').doc('kantor').set({
        'jam_masuk': _jamMasukController.text,
        'jam_pulang': _jamPulangController.text,
        'lat': _selectedLocation.latitude,
        'lng': _selectedLocation.longitude,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lokasi & Jam Berhasil Disimpan!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
    } finally {
      setState(() => _isLoadingMap = false);
    }
  }

  Future<void> _updateIzin(String docId, String status) async {
    await _firestore.collection('izin').doc(docId).update({'status': status});
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        children: [
          // A. SIDEBAR KIRI
          SizedBox(width: 280, child: _buildSidebar()),

          // B. KONTEN KANAN
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Fitur Pembimbing",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // --- GRID FITUR PEMBIMBING ---
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      // List Anak Magang
                      DashboardCard(
                        title: "Daftar Anak Magang",
                        child: _buildMagangList(),
                      ),
                      // Filter Absensi
                      const DashboardCard(
                        title: "Lihat Kehadiran Harian",
                        child: Center(
                          child: Text("Fitur filter kehadiran (Coming Soon)"),
                        ),
                      ),
                      // Rekap Otomatis
                      const DashboardCard(
                        title: "Rekap Otomatis",
                        child: Center(
                          child: Text("Fitur Export Excel (Coming Soon)"),
                        ),
                      ),
                      // Validasi Izin
                      DashboardCard(
                        title: "Validasi Izin & Sakit",
                        child: _buildValidasiIzin(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                  const Text(
                    "Fitur Admin",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // --- GRID FITUR ADMIN ---
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      // Form Tambah Pegawai (User/Admin)
                      DashboardCard(
                        title: "Tambah Pegawai Baru",
                        child: _buildAdminForm(),
                      ),
                      // Form Jam Absen
                      DashboardCard(
                        title: "Atur Jam Absen",
                        child: _buildAturJam(),
                      ),
                      // Peta Lokasi
                      DashboardCard(
                        title: "Atur Titik Lokasi Dishub",
                        child: _buildMapWidget(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET SIDEBAR ---
  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFF0B5FA5),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // --- LOGO IMAGE ---
          Container(
            height: 80,
            width: 80,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Image.asset(
              'assets/Logo_no_bg.png', // Pastikan nama file ini benar di folder assets Anda
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.public, color: Colors.yellow, size: 40),
            ),
          ),

          const SizedBox(height: 10),
          const Text(
            "SiMagang Dishub",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Kota Makassar",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 40),

          // --- TANGGAL ---
          Text(
            DateFormat('dd.MM.yyyy').format(DateTime.now()),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 30),

          // --- PROFIL ADMIN ---
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 35, color: Colors.white),
          ),
          const SizedBox(height: 10),
          const Text(
            "Admin :",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            _adminName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // --- MENU ITEMS ---
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.white),
            title: const Text(
              "Dashboard",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {},
          ),

          Theme(
            data: ThemeData(dividerColor: Colors.transparent),
            child: const ExpansionTile(
              collapsedIconColor: Colors.white,
              iconColor: Colors.white,
              leading: Icon(Icons.people, color: Colors.white),
              title: Text(
                "Fitur Pembimbing",
                style: TextStyle(color: Colors.white),
              ),
              children: [
                ListTile(
                  title: Text(
                    "    • Daftar Magang",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                ListTile(
                  title: Text(
                    "    • Rekap Absensi",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          Theme(
            data: ThemeData(dividerColor: Colors.transparent),
            child: const ExpansionTile(
              collapsedIconColor: Colors.white,
              iconColor: Colors.white,
              leading: Icon(Icons.admin_panel_settings, color: Colors.white),
              title: Text("Fitur Admin", style: TextStyle(color: Colors.white)),
              children: [
                ListTile(
                  title: Text(
                    "    • Manajemen User",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                ListTile(
                  title: Text(
                    "    • Pengaturan Lokasi",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // --- SIGN OUT ---
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              "Sign Out",
              style: TextStyle(color: Colors.white),
            ),
            onTap: _signOut,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // KOMPONEN 1: LIST MAGANG
  Widget _buildMagangList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('role', isEqualTo: 'intern')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text("Error: ${snapshot.error}");
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "Belum ada data intern.\nTambah via form dengan role 'intern'.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          );
        }

        return Column(
          children: [
            // Header Tabel
            Container(
              color: const Color(0xFF0B5FA5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Nama",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "NIP",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    "Act",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Isi Tabel
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return Container(
                    color: index % 2 == 0 ? Colors.blue[50] : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(data['nama'] ?? '-')),
                        Expanded(child: Text(data['nip'] ?? '-')),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Hapus Pegawai?"),
                                content: Text(
                                  "Yakin ingin menghapus ${data['nama']}?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Batal"),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _firestore
                                          .collection('users')
                                          .doc(docs[index].id)
                                          .delete();
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      "Hapus",
                                      style: TextStyle(color: Colors.red),
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
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // KOMPONEN 2: VALIDASI IZIN
  Widget _buildValidasiIzin() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('izin')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("Tidak ada permintaan izin pending"));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['nama'] ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "${data['keterangan']} - ${data['tanggal']}",
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _updateIzin(docs[index].id, 'approved'),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          color: Colors.green,
                          child: const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _updateIzin(docs[index].id, 'rejected'),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          color: Colors.red,
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // KOMPONEN 3: FORM ADMIN
  Widget _buildAdminForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _namaController,
          decoration: const InputDecoration(
            labelText: "Nama Lengkap",
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nipController,
          decoration: const InputDecoration(
            labelText: "NIP",
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        // DROPDOWN
        DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: const InputDecoration(
            labelText: "Role / Jabatan",
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: 'intern',
              child: Text("Anak Magang (Intern)"),
            ),
            DropdownMenuItem(value: 'admin', child: Text("Administrator")),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedRole = value);
            }
          },
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addPegawai,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              "SIMPAN DATA",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // KOMPONEN 4: ATUR JAM
  Widget _buildAturJam() {
    return Column(
      children: [
        TextField(
          controller: _jamMasukController,
          decoration: const InputDecoration(
            labelText: "Jam Masuk (08:00)",
            suffixIcon: Icon(Icons.access_time),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _jamPulangController,
          decoration: const InputDecoration(
            labelText: "Jam Pulang (17:00)",
            suffixIcon: Icon(Icons.access_time),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  // KOMPONEN 5: MAPS
  Widget _buildMapWidget() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    color: Colors.white.withOpacity(0.9),
                    child: Text(
                      "Lat: ${_selectedLocation.latitude.toStringAsFixed(4)}\nLng: ${_selectedLocation.longitude.toStringAsFixed(4)}",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoadingMap ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B5FA5),
            ),
            icon: _isLoadingMap
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: const Text(
              "SIMPAN LOKASI",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// --- WIDGET HELPER ---
class DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;
  const DashboardCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}
