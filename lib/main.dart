import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PointageApp());
}

class PointageApp extends StatelessWidget {
  const PointageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pointage Chantier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> meState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _statusMessage = '';
  bool _isLoading = false;

  // Coordonnées du Chantier
  final double latChantier = 34.929955826807344;
  final double lngChantier = -1.3663320917200374;
  final double rayonMax = 150.0; // mètres

  Future<String> _getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    return 'unknown_device';
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Vérification en cours...';
    });

    try {
      String username = _usernameController.text.trim().toLowerCase();
      String password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        setState(() {
          _statusMessage = 'Veuillez remplir tous les champs.';
          _isLoading = false;
        });
        return;
      }

      // Connexion à Firebase
      DatabaseReference ref = FirebaseDatabase.instance.ref("utilisateurs/$username");
      DataSnapshot snapshot = await ref.get();

      if (!snapshot.exists) {
        setState(() {
          _statusMessage = 'Identifiant incorrect.';
          _isLoading = false;
        });
        return;
      }

      Map userData = snapshot.value as Map;

      if (userData['mot_de_passe'] != password) {
        setState(() {
          _statusMessage = 'Mot de passe incorrect.';
          _isLoading = false;
        });
        return;
      }

      // Vérification GPS
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      double distance = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        latChantier, lngChantier
      );

      if (distance > rayonMax) {
        setState(() {
          _statusMessage = '❌ Vous êtes hors du chantier ! (${distance.round()}m)';
          _isLoading = false;
        });
        return;
      }

      // Vérification Empreinte Appareil (Android ID)
      String currentDeviceId = await _getDeviceId();
      String savedDeviceId = userData['device_id'] ?? '';

      if (savedDeviceId.isEmpty) {
        // Premier verrouillage de l'appareil
        await ref.update({
          'device_id': currentDeviceId,
          'device_locked': true,
        });
      } else if (savedDeviceId != currentDeviceId) {
        setState(() {
          _statusMessage = '❌ Compte verrouillé sur un autre téléphone !';
          _isLoading = false;
        });
        return;
      }

      // Succès connexion
      setState(() {
        _statusMessage = '✅ Connexion réussie (${userData['nom_affiche']})';
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Erreur : ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pointage Chantier Anti-Fraude')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Nom d\'utilisateur',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Se Connecter & Pointer'),
                  ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _statusMessage.startsWith('✅') ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<StatefulWidget> createState() {
    throw UnimplementedError();
  }
}
