import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapLokasiWidget extends StatefulWidget {
  const MapLokasiWidget({super.key});

  @override
  State<MapLokasiWidget> createState() => _MapLokasiWidgetState();
}

class _MapLokasiWidgetState extends State<MapLokasiWidget> {
  LatLng _selectedLocation = const LatLng(-5.147665, 119.432732); // Default Makassar
  final MapController _mapController = MapController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLokasi();
  }

  void _loadLokasi() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('settings').doc('kantor').get();
      if (doc.exists && mounted) {
        var data = doc.data()!;
        if (data['lat'] != null && data['lng'] != null) {
          setState(() {
            _selectedLocation = LatLng(data['lat'], data['lng']);
          });
          // Pindahkan kamera ke lokasi database dengan zoom dekat
          Future.delayed(const Duration(seconds: 1), () {
             _mapController.move(_selectedLocation, 17.0); 
          });
        }
      }
    } catch (e) {
      debugPrint("Error load lokasi: $e");
    }
  }

  Future<void> _simpanLokasi() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('kantor').set({
        'lat': _selectedLocation.latitude,
        'lng': _selectedLocation.longitude,
      }, SetOptions(merge: true));
      
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lokasi Kantor Disimpan")));
    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal simpan: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.0, 
                    // PERBAIKAN DI SINI:
                    maxZoom: 19.0, // Izinkan zoom sampai level jalan/rumah
                    minZoom: 5.0,  // Batas zoom out
                    
                    // Pastikan interaksi (cubit/scroll) aktif
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    
                    onTap: (pos, point) => setState(() => _selectedLocation = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app', // Good practice untuk OSM
                      maxZoom: 19, // Pastikan tile layer juga support zoom 19
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation, 
                          width: 40, 
                          height: 40, 
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          alignment: Alignment.topCenter, // Agar ujung pin pas di titik
                        )
                      ]
                    ),
                  ],
                ),
                
                // Indikator Zoom (Opsional, visual feedback)
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(4)),
                    child: const Text("Cubit/Scroll untuk Zoom", style: TextStyle(fontSize: 8)),
                  ),
                ),

                // Tombol Simpan Melayang
                Positioned(
                  bottom: 10, right: 10,
                  child: FloatingActionButton.small(
                    onPressed: _simpanLokasi,
                    backgroundColor: Colors.blue,
                    child: _isLoading 
                      ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white)) 
                      : const Icon(Icons.save, color: Colors.white),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text("Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}