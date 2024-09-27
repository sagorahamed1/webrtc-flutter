import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  // Local Renderer ইনিশিয়ালাইজ করা
  Future<void> initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _localStream = await _createLocalStream();
    _localRenderer.srcObject = _localStream;
  }

  // Local Stream তৈরি করা (ভিডিও/অডিও)
  Future<MediaStream> _createLocalStream() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });
    return stream;
  }

  // Peer Connection তৈরি করা
  Future createPeerConnection(Map<String, dynamic> configuration) async {
    // STUN সার্ভার যোগ করা
    Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);

    // Add local stream tracks to the peer connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
  }
}
