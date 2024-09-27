




import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallPage extends StatefulWidget {
  final String? receiverId;

  VideoCallPage({required this.receiverId});

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isCallOngoing = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _listenForCalls();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _localStream = await _createLocalStream();
    _localRenderer.srcObject = _localStream;
  }

  Future<MediaStream> _createLocalStream() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });
    return stream;
  }

  void _listenForCalls() {
    FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.receiverId!)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        if (data['offer'] != null && !_isCallOngoing) {
          _handleIncomingCall(data['offer']);
        }
        if (data['candidate'] != null) {
          _addIceCandidate(data['candidate']);
        }
      }
    });
  }

  Future<void> _handleIncomingCall(Map<String, dynamic> offer) async {
    // Set up PeerConnection
    // _peerConnection = await createPeerConnection();

    // Set remote description and create an answer
    RTCSessionDescription description = RTCSessionDescription(offer['sdp'], offer['type']);
    await _peerConnection!.setRemoteDescription(description);

    // Create and send an answer back
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    FirebaseFirestore.instance.collection('calls').doc(widget.receiverId!).update({
      'answer': answer.toMap(),
      'isCalling': false,
    });

    _isCallOngoing = true;
  }

  Future<RTCPeerConnection> createPeerConnection(Map<String, dynamic> configuration) async {
    // STUN server configuration
    Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    RTCPeerConnection peerConnection = await createPeerConnection(configuration);

    // Add local stream tracks to the peer connection
    _localStream?.getTracks().forEach((track) {
      peerConnection.addTrack(track, _localStream!);
    });

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null) {
        // Send the candidate to the other peer
        FirebaseFirestore.instance.collection('calls').doc(widget.receiverId!).update({
          'candidate': candidate.toMap(),
        });
      }
    };

    peerConnection.onAddStream = (MediaStream stream) {
      _remoteRenderer.srcObject = stream;
    };

    return peerConnection;
  }

  void _addIceCandidate(Map<String, dynamic> candidateData) {
    RTCIceCandidate candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
    );
    _peerConnection?.addCandidate(candidate);
  }

  Future<void> _endCall() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calling ${widget.receiverId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end),
            onPressed: _endCall,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: RTCVideoView(_localRenderer)),
          Expanded(child: RTCVideoView(_remoteRenderer)),
        ],
      ),
    );
  }
}
