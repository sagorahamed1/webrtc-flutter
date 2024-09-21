import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC',
      home: AuthScreen(),
    );
  }
}

// Authentication Screen (Sign Up & Sign In)
class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isSignIn = true; // Toggle between SignIn and SignUp

  Future<void> _signUp() async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text, password: _passwordController.text);
      if (userCredential.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => VideoCallScreen()),
        );
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _signIn() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text, password: _passwordController.text);
      if (userCredential.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => VideoCallScreen()),
        );
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isSignIn ? 'Sign In' : 'Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSignIn ? _signIn : _signUp,
              child: Text(isSignIn ? 'Sign In' : 'Sign Up'),
            ),
            TextButton(
              onPressed: () => setState(() => isSignIn = !isSignIn),
              child: Text(isSignIn
                  ? "Don't have an account? Sign Up"
                  : "Already have an account? Sign In"),
            ),
          ],
        ),
      ),
    );
  }
}

// Video Call Screen
class VideoCallScreen extends StatefulWidget {
  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final TextEditingController roomIdController = TextEditingController();
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  bool _isCaller = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _createRoom(String roomId) async {
    _isCaller = true;
    _peerConnection = await _createPeerConnection();

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _sendIceCandidate(roomId, candidate);
    };

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    });

    FirebaseFirestore.instance.collection('rooms').doc(roomId).snapshots().listen((snapshot) async {
      if (snapshot.data() != null && snapshot.data()!['answer'] != null) {
        RTCSessionDescription answer = RTCSessionDescription(
          snapshot.data()!['answer']['sdp'],
          snapshot.data()!['answer']['type'],
        );
        await _peerConnection!.setRemoteDescription(answer);
      }
    });
  }

  Future<void> _joinRoom(String roomId) async {
    DocumentSnapshot roomSnapshot = await FirebaseFirestore.instance.collection('rooms').doc(roomId).get();

    if (roomSnapshot.exists) {
      Map<String, dynamic> roomData = roomSnapshot.data() as Map<String, dynamic>;
      RTCSessionDescription offer = RTCSessionDescription(roomData['offer']['sdp'], roomData['offer']['type']);

      _peerConnection = await _createPeerConnection();
      await _peerConnection!.setRemoteDescription(offer);
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendIceCandidate(roomId, candidate);
      };

      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      });

      FirebaseFirestore.instance.collection('rooms').doc(roomId).snapshots().listen((snapshot) {
        // Handle ICE candidates
      });
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    };

    RTCPeerConnection peerConnection = await createPeerConnection(configuration);

    MediaStream localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });

    localStream.getTracks().forEach((track) {
      peerConnection.addTrack(track, localStream);
    });

    _localRenderer.srcObject = localStream;

    peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
      }
    };

    return peerConnection;
  }

  void _sendIceCandidate(String roomId, RTCIceCandidate candidate) {
    FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('candidates').add({
      'candidate': candidate.toMap(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Call')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _createRoom(roomIdController.text),
                child: Text('Create Room'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _joinRoom(roomIdController.text),
                child: Text('Join Room'),
              ),
            ],
          ),
          Expanded(
            child: RTCVideoView(_localRenderer),
          ),
          Expanded(
            child: RTCVideoView(_remoteRenderer),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }
}
