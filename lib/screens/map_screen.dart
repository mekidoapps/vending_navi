import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/machine_provider.dart';
import '../services/location_service.dart';
import 'machine_create_screen.dart';
import 'machine_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  // デフォルト：東京駅
  static const LatLng _defaultPosition = LatLng(35.6812, 139.7671);

  LatLng _currentPosition = _defaultPosition;
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final LocationService locationService = LocationService();
      final position = await locationService.getCurrentPosition();

      // nullチェック
      if (!mounted || position == null) {
        if (mounted) {
          setState(() => _locationLoaded = true);
          _loadNearbyMachines();
        }
        return;
      }

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _locationLoaded = true;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 15),
      );

      _loadNearbyMachines();
    } catch (e) {
      // 位置情報取得失敗時はデフォルト位置を使用
      if (mounted) {
        setState(() => _locationLoaded = true);
        _loadNearbyMachines();
      }
    }
  }

  void _loadNearbyMachines() {
    context.read<MachineProvider>().loadNearbyMachines(
      lat: _currentPosition.latitude,
      lng: _currentPosition.longitude,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_locationLoaded) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 15),
      );
    }
  }

  Set<Marker> _buildMarkers(MachineProvider machineProvider) {
    return machineProvider.nearbyMachines.map((machine) {
      return Marker(
        markerId: MarkerId(machine.id),
        position: LatLng(machine.latitude, machine.longitude), // ← 修正
        infoWindow: InfoWindow(
          title: machine.name,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MachineDetailScreen(machineId: machine.id),
              ),
            );
          },
        ),
      );
    }).toSet();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Consumer<MachineProvider>(
        builder: (context, machineProvider, _) {
          return Stack(
            children: [
              // マップ本体
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _currentPosition,
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                markers: _buildMarkers(machineProvider),
                zoomControlsEnabled: false,
              ),

              // ローディングオーバーレイ
              if (machineProvider.isLoading)
                const Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('自販機を読み込み中…'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 現在地ボタン
              Positioned(
                right: 16,
                bottom: 100,
                child: FloatingActionButton.small(
                  heroTag: 'location',
                  onPressed: () {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_currentPosition, 15),
                    );
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          );
        },
      ),

      // ログイン済みの場合のみ自販機追加ボタンを表示
      floatingActionButton: authProvider.isLoggedIn
          ? FloatingActionButton(
        heroTag: 'add_machine',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const MachineCreateScreen(),
            ),
          );
        },
        child: const Icon(Icons.add_location_alt_outlined),
      )
          : null,
    );
  }
}
