import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordWidget extends StatefulWidget {
  const ResetPasswordWidget({super.key});

  @override
  State<ResetPasswordWidget> createState() => _ResetPasswordWidgetState();
}

class _ResetPasswordWidgetState extends State<ResetPasswordWidget> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _kirimResetEmail(BuildContext context, String email, String nama) async {
    bool? konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kirim Reset Password?"),
        content: Text(
          "Email reset password akan dikirim ke:\n\n$email\n\nUser ($nama) perlu membuka email tersebut untuk mengatur password baru.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5FA5)),
            child: const Text("Kirim", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Email reset dikirim ke $email"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String pesan = "Gagal mengirim email reset.";
      if (e.code == 'user-not-found') pesan = "Email tidak terdaftar di sistem.";
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(pesan), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.amber),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Sistem akan mengirim email ke user. User mengatur password baru sendiri via email.",
                  style: TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Search
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Cari nama atau NIP...",
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        ),
        const SizedBox(height: 10),

        // List user
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'intern')
                .where('status', isNotEqualTo: 'deleted')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Belum ada data magang", style: TextStyle(fontSize: 11)));
              }

              var docs = snapshot.data!.docs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                var d = doc.data() as Map<String, dynamic>;
                return (d['nama'] ?? '').toLowerCase().contains(_searchQuery) ||
                    (d['nip'] ?? '').toLowerCase().contains(_searchQuery);
              }).toList();

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String email = data['email'] ?? '';
                  String nama = data['nama'] ?? '-';

                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFE8F0FE),
                      child: Icon(Icons.person, size: 16, color: Color(0xFF0B5FA5)),
                    ),
                    title: Text(nama, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: Text(email, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    trailing: SizedBox(
                      height: 28,
                      child: ElevatedButton.icon(
                        onPressed: email.isEmpty
                            ? null
                            : () => _kirimResetEmail(context, email, nama),
                        icon: const Icon(Icons.lock_reset, size: 12, color: Colors.white),
                        label: const Text("Reset", style: TextStyle(fontSize: 10, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
