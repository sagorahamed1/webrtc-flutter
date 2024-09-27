import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_app/video_call.dart';

import 'log_in_sign_up_screeb.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC App',
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/home': (context) => HomePage(),
        '/video-call': (context) => VideoCallPage(receiverId: ModalRoute.of(context)!.settings.arguments as String?),
      },
    );
  }
}









class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _firebaseMessaging.requestPermission();
    _firebaseMessaging.getToken().then((token) {
      // Save the user's FCM token in Firestore
      _saveTokenToDatabase(token);
    });
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle the incoming notification
      _showNotification(message);
    });
  }

  void _saveTokenToDatabase(String? token) async {
    if (token != null) {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      print("FCM Token saved: $token"); // Debug: print token
    }
  }

  void _showNotification(RemoteMessage message) {
    // Display a dialog or a snackbar with the message data
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Incoming Call'),
        content: Text('${message.data['title']}: ${message.data['body']}'),
        actions: [
          TextButton(
            child: Text('Accept'),
            onPressed: () {
              Navigator.pushNamed(context, '/video-call', arguments: message.data['callerId']);
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Decline'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          var users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index];
              return ListTile(
                title: Text(user['email']),
                trailing: IconButton(
                  icon: const Icon(Icons.video_call),
                  onPressed: () {
                    // Start a call with the selected user
                    startCall(context, user.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void startCall(BuildContext context, String receiverId) async {
    // Create a new call document for the receiver
    await FirebaseFirestore.instance.collection('calls').doc(receiverId).set({
      'offer': null,
      'isCalling': true,
      'callerId': FirebaseAuth.instance.currentUser!.uid,
    });

    // Send a notification to the receiver
    sendCallNotification(receiverId);

    // Navigate to VideoCallPage
    Navigator.pushNamed(context, '/video-call', arguments: receiverId);
  }

  void sendCallNotification(String receiverId) async {
    // Get the FCM token of the receiver from Firestore
    DocumentSnapshot receiverDoc = await _firestore.collection('users').doc(receiverId).get();
    String? receiverToken = (receiverDoc.data() as Map<String, dynamic>?)?['fcmToken'];
    if (receiverToken != null) {
      // Send notification using your server or cloud function
      await sendNotificationToServer(receiverToken, 'Incoming Call', 'You have an incoming call!', receiverId);
    }
  }

  Future<void> sendNotificationToServer(String token, String title, String body, String callerId) async {
    // Implement your server logic here, possibly using HTTP POST request to your server endpoint
    print('Send notification to: $token, Title: $title, Body: $body, CallerId: $callerId');
    // Example HTTP call to your server goes here
  }
}












