import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// ✅ FIX #4: Ubah ke StatefulWidget agar Stream bisa di-dispose (cegah memory leak)
class AdminSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String adminName;
  final VoidCallback onSignOut;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.adminName,
    required this.onSignOut,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // ✅ Pakai Timer yang bisa di-cancel, bukan Stream.periodic yang bocor
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // ✅ Timer di-cancel saat widget dihapus
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isPembimbingActive = widget.selectedIndex == 1;
    bool isAdminActive = widget.selectedIndex == 2;

    return Container(
      color: const Color(0xFF0B5FA5),
      child: ListView(
        children: [
          // HEADER PROFIL
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                  width: 80,
                  child: Image.asset(
                    'assets/Logo_no_bg.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.directions_bus, color: Colors.yellow, size: 50),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "SiMagang Dishub",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const Text("Kota Makassar", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 20),

                // ✅ Jam real-time dari _now state (bukan Stream.periodic)
                Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_now),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  DateFormat('HH:mm:ss').format(_now),
                  style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 20),
                ),

                const SizedBox(height: 20),
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text("Admin :", style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  widget.adminName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // MENU ITEMS
          _buildSingleItem(0, "Dashboard", Icons.dashboard),

          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: isPembimbingActive,
              iconColor: Colors.yellow,
              collapsedIconColor: Colors.white,
              textColor: Colors.yellow,
              collapsedTextColor: Colors.white,
              leading: const Icon(Icons.people, color: Colors.white),
              title: const Text("Fitur Pembimbing"),
              children: [
                _buildSubItem(1, "Manajemen Peserta Magang"),
              ],
            ),
          ),

          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: isAdminActive,
              iconColor: Colors.yellow,
              collapsedIconColor: Colors.white,
              textColor: Colors.yellow,
              collapsedTextColor: Colors.white,
              leading: const Icon(Icons.admin_panel_settings, color: Colors.white),
              title: const Text("Fitur Admin"),
              children: [
                _buildSubItem(2, "Semua Fitur Admin"),
              ],
            ),
          ),

          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
            onTap: widget.onSignOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleItem(int index, String title, IconData icon) {
    bool isSelected = widget.selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.yellow : Colors.white),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.yellow : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => widget.onItemSelected(index),
    );
  }

  Widget _buildSubItem(int index, String title) {
    bool isSelected = widget.selectedIndex == index;
    return Container(
      color: isSelected ? Colors.white.withOpacity(0.1) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 55),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.yellow : Colors.white70,
            fontSize: 13,
          ),
        ),
        onTap: () => widget.onItemSelected(index),
      ),
    );
  }
}
