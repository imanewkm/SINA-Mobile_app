import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/labels.dart';
import '../controller/app_controller.dart';
import '../models/alert.dart';

/// Family dashboard — OpenStreetMap with last known position + alert log.
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  static const _pink = Color(0xFFE879F9);
  static const _text = Color(0xFFF0EAFF);

  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final hasFix = c.gps.hasFix;
        final center = LatLng(c.gps.lat ?? 33.57, c.gps.lng ?? -7.59);
        return Scaffold(
          backgroundColor: const Color(0xFF0A0612),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0A0612),
            foregroundColor: _text,
            title: Text(pick(lblFamilyTracking, c.curLang)),
          ),
          body: Column(
            children: [
              SizedBox(
                height: 280,
                child: FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 14),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sina.mobility',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), _pink],
                              ),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.person,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _liveStatus(c, hasFix),
              Expanded(child: _alertList(c.alerts.alerts, c.curLang)),
            ],
          ),
        );
      },
    );
  }

  Widget _liveStatus(AppController c, bool hasFix) {
    final lang = c.curLang;
    final age = c.gps.lastUpdate == null
        ? '—'
        : '${DateTime.now().difference(c.gps.lastUpdate!).inSeconds}s';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: const Color(0x1A8B5CF6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasFix ? const Color(0xFF4ADE80) : Colors.grey,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                hasFix ? pick(lblOnline, lang) : pick(lblWaitingGps, lang),
                style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasFix
                ? 'Lat: ${c.gps.lat!.toStringAsFixed(5)}   Lng: ${c.gps.lng!.toStringAsFixed(5)}'
                : pick(lblNoLocationYet, lang),
            style: const TextStyle(color: _text, fontSize: 14),
          ),
          Text('${pick(lblLastUpdate, lang)}: $age',
              style: const TextStyle(color: Color(0x99F0EAFF), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _alertList(List<SinaAlert> alerts, String lang) {
    if (alerts.isEmpty) {
      return Center(
        child: Text(pick(lblNoAlertsYet, lang),
            style: const TextStyle(color: Color(0x99F0EAFF))),
      );
    }
    final items = alerts.take(20).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final a = items[i];
        final loc = (a.lat != null && a.lng != null)
            ? '📍 ${a.lat!.toStringAsFixed(5)}, ${a.lng!.toStringAsFixed(5)}'
            : '';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x14E879F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x40E879F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🚨 ${a.message}',
                  style: const TextStyle(
                      color: Color(0xFFF0ABFC), fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(_fmtTime(a.timestamp),
                  style:
                      const TextStyle(color: Color(0x99F0EAFF), fontSize: 12)),
              if (loc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(loc,
                      style: const TextStyle(
                          color: Color(0x99F0EAFF), fontSize: 12)),
                ),
            ],
          ),
        );
      },
    );
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
