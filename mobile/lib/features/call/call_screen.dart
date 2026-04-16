import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import '../../core/e2ee/crypto_service.dart';
import '../../core/network/ws_client.dart';
import '../../core/providers.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String calleeId;
  final String calleeName;
  final String callType;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.callId,
    required this.calleeId,
    required this.calleeName,
    required this.callType,
    this.isIncoming = false,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with TickerProviderStateMixin {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  bool _isMuted = false;
  bool _isSpeaker = true;
  bool _isFrontCamera = true;
  late bool _isVideoEnabled;
  String _status = 'Вызов...';
  String? _activeCallId;
  Timer? _durationTimer;
  int _duration = 0;
  bool _isIncomingPending = false;
  bool _callEnded = false;
  int? _wsSubId;
  late AnimationController _ringController;
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;
  bool _swappedVideo = false;
  final _crypto = E2eeCryptoService();
  bool _isE2eeActive = false;
  String? _peerId;

  static String _statusRu(String en) {
    switch (en) {
      case 'Вызов...':
        return 'Вызов...';
      case 'Ожидание ответа...':
        return 'Ожидание ответа...';
      case 'Подключение...':
        return 'Подключение...';
      case 'Устанавливаем соединение...':
        return 'Устанавливаем соединение...';
      case 'Ожидание собеседника...':
        return 'Ожидание собеседника...';
      case 'Соединение потеряно...':
        return 'Соединение потеряно...';
      case 'Звонок завершён':
        return 'Звонок завершён';
      case 'Connected':
        return 'Connected';
      case 'Ringing...':
        return 'Ожидание ответа...';
      case 'Connecting...':
        return 'Подключение...';
      case 'Failed to initiate call':
        return 'Соединение потеряно...';
      case 'Failed to accept call':
        return 'Соединение потеряно...';
      default:
        return en;
    }
  }

  String get _displayStatus {
    if (_status == 'Connected') return _status;
    return _statusRu(_status);
  }

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.callType == 'VIDEO';
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _init();
  }

  Future<void> _init() async {
    _peerId = widget.calleeId;
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    if (widget.isIncoming) {
      _activeCallId = widget.callId;
      _listenForCallEvents();
      if (mounted) {
        setState(() {
          _isIncomingPending = true;
          _status = 'Входящий вызов';
        });
      }
    } else {
      await _setupWebRTC(initOffer: false);
      await _initiateCall();
    }
  }

  Future<void> _initiateCall() async {
    try {
      _listenForCallEvents();

      debugPrint('[CALL] Sending call.init to ${widget.calleeId}, type=${widget.callType}');
      await WsClient().send(
        '/app/call.init',
        body: jsonEncode({
          'calleeId': widget.calleeId,
          'callType': widget.callType,
        }),
      );
      if (mounted) setState(() => _status = 'Ожидание ответа...');
    } catch (e) {
      debugPrint('[CALL] initiateCall error: $e');
      if (mounted) setState(() => _status = 'Соединение потеряно...');
    }
  }

  Future<void> _acceptCall() async {
    if (mounted) {
      setState(() {
        _isIncomingPending = false;
        _status = 'Подключение...';
      });
    }
    try {
      await _setupWebRTC(initOffer: false);

      if (_wsSubId == null) {
        _listenForCallEvents();
      }

      debugPrint('[CALL] Sending call.accept for callId=$_activeCallId');
      await WsClient().send(
        '/app/call.accept',
        body: jsonEncode({'callId': _activeCallId}),
      );
    } catch (e) {
      debugPrint('[CALL] acceptCall error: $e');
      if (mounted) {
        setState(() => _status = 'Соединение потеряно...');
      }
    }
  }

  Future<void> _rejectCall() async {
    if (_activeCallId != null) {
      try {
        await WsClient().send(
          '/app/call.reject',
          body: jsonEncode({'callId': _activeCallId}),
        );
      } catch (_) {}
    }
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        // Открыто через push (context.go) — pop невозможен, идём на главную
        context.go('/');
      }
    }
  }

  Future<void> _setupWebRTC({bool initOffer = true}) async {
    if (_localStream != null) return; // Уже инициализировано

    final isVideo = widget.callType == 'VIDEO';

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    });

    if (isVideo) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = _isVideoEnabled;
      });
    }
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
      track.enableSpeakerphone(_isSpeaker);
    });

    _localRenderer.srcObject = _localStream;

    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {
          'urls': ['turn:31.130.150.246:3478?transport=udp', 'turn:31.130.150.246:3478?transport=tcp'],
          'username': 'turnuser',
          'credential': 'turn_pass_2024',
        },
      ],
    };

    _pc = await createPeerConnection(config);

    _localStream!.getTracks().forEach((track) {
      _pc!.addTrack(track, _localStream!);
    });

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        if (mounted) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
          });
        }
      }
    };

    _pc!.onIceCandidate = (candidate) {
      final candidateStr = candidate.candidate ?? '';
      debugPrint('[CALL-E2EE] ICE candidate: ${candidateStr.length > 50 ? candidateStr.substring(0, 50) : candidateStr}...');
      if (_activeCallId != null) {
        _sendEncryptedIce(candidate);
      }
    };

    _pc!.onIceConnectionState = (state) {
      debugPrint('[CALL] ICE connection state: $state');
    };

    _pc!.onConnectionState = (state) {
      debugPrint('[CALL] Peer connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (mounted) {
          _ringController.stop();
          setState(() => _status = 'Connected');
        }
        _startTimer();
      } else if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (mounted) {
          setState(() => _status = 'Соединение потеряно...');
        }
        _endCall(sendToServer: true);
      }
    };

    if (initOffer && !widget.isIncoming && _activeCallId != null) {
      await _createAndSendOffer();
    }
  }

  Future<void> _createAndSendOffer() async {
    if (_pc == null || _activeCallId == null) {
      debugPrint('[CALL-E2EE] Cannot create offer: pc=$_pc, callId=$_activeCallId');
      return;
    }
    try {
      debugPrint('[CALL-E2EE] Creating SDP offer...');
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      final sdpStr = offer.sdp ?? '';
      if (_peerId != null) {
        final encrypted = await _crypto.encryptMessage(_peerId!, sdpStr);
        if (encrypted != null) {
          debugPrint('[CALL-E2EE] SDP offer encrypted, sending');
          await WsClient().send(
            '/app/call.sdpOffer',
            body: jsonEncode({
              'callId': _activeCallId,
              'sdp': '${encrypted.messageType}:${encrypted.ciphertextBase64}',
              'encrypted': true,
            }),
          );
          if (mounted) setState(() => _isE2eeActive = true);
          return;
        }
      }
      debugPrint('[CALL-E2EE] Fallback: sending SDP offer unencrypted');
      await WsClient().send(
        '/app/call.sdpOffer',
        body: jsonEncode({'callId': _activeCallId, 'sdp': sdpStr, 'encrypted': false}),
      );
    } catch (e) {
      debugPrint('[CALL-E2EE] Error sending offer: $e');
    }
  }

  void _listenForCallEvents() {
    if (_wsSubId != null) return; // Уже подписаны
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return;

    _wsSubId = WsClient().subscribe('/user/$userId/queue/call', (frame) async {
      if (_callEnded || frame.body == null) return;
      final data = jsonDecode(frame.body!);
      final type = data['type'] as String?;
      debugPrint('[CALL] WS event received: $type');

      switch (type) {
        case 'CALL_INCOMING':
          final eventCallId = data['callId'] as String?;
          final callerId = data['callerId'] as String?;

          if (!widget.isIncoming && callerId == userId) {
            if (eventCallId != null && _activeCallId == null) {
              _activeCallId = eventCallId;
              debugPrint('[CALL] Got callId: $_activeCallId, waiting for CALL_ACCEPTED to send offer');
            }
          } else if (widget.isIncoming) {
            if (eventCallId != null && _activeCallId == null) {
              _activeCallId = eventCallId;
            }
          }
          break;
        case 'CALL_ACCEPTED':
          debugPrint('[CALL] CALL_ACCEPTED received, isIncoming=${widget.isIncoming}');
          if (mounted) {
            setState(() => _status = 'Подключение...');
          }
          if (!widget.isIncoming && _activeCallId != null) {
            await _createAndSendOffer();
          }
          break;
        case 'CALL_BLOCKED':
          if (mounted) {
            final reason = data['data']?['reason'] as String? ?? 'Пользователь не принимает звонки';
            setState(() => _status = reason);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
          }
          _endCall(sendToServer: false);
          break;
        case 'CALL_ENDED':
        case 'CALL_REJECTED':
          if (mounted) {
            setState(() => _status = 'Звонок завершён');
          }
          _endCall(sendToServer: false);
          break;
        case 'ICE_CANDIDATE':
          debugPrint('[CALL-E2EE] Received ICE_CANDIDATE');
          if (data['data'] != null && data['data']['candidate'] != null) {
            final isEnc = data['data']['encrypted'] == true;
            String candidateRaw = data['data']['candidate'];
            if (isEnc && _peerId != null) {
              final decrypted = await _decryptSignaling(candidateRaw);
              if (decrypted != null) {
                candidateRaw = decrypted;
              } else {
                debugPrint('[CALL-E2EE] Failed to decrypt ICE candidate');
                break;
              }
            }
            final candidateMap = candidateRaw is String
                ? jsonDecode(candidateRaw)
                : candidateRaw;
            final iceCandidate = RTCIceCandidate(
              candidateMap['candidate'],
              candidateMap['sdpMid'],
              candidateMap['sdpMLineIndex'],
            );
            if (_remoteDescriptionSet && _pc != null) {
              _pc!.addCandidate(iceCandidate);
            } else {
              debugPrint('[CALL-E2EE] Buffering ICE candidate (remote desc not set yet)');
              _pendingCandidates.add(iceCandidate);
            }
          }
          break;
        case 'SDP_ANSWER':
          debugPrint('[CALL-E2EE] Received SDP_ANSWER');
          if (data['data'] != null && data['data']['sdp'] != null) {
            final isEnc = data['data']['encrypted'] == true;
            String sdp = data['data']['sdp'];
            if (isEnc && _peerId != null) {
              final decrypted = await _decryptSignaling(sdp);
              if (decrypted != null) {
                sdp = decrypted;
                if (mounted) setState(() => _isE2eeActive = true);
              } else {
                debugPrint('[CALL-E2EE] Failed to decrypt SDP answer');
                break;
              }
            }
            await _pc?.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
            _remoteDescriptionSet = true;
            _flushPendingCandidates();
          }
          break;
        case 'SDP_OFFER':
          debugPrint('[CALL-E2EE] Received SDP_OFFER');
          if (data['data'] != null && data['data']['sdp'] != null) {
            final isEnc = data['data']['encrypted'] == true;
            String sdp = data['data']['sdp'];
            if (isEnc && _peerId != null) {
              final decrypted = await _decryptSignaling(sdp);
              if (decrypted != null) {
                sdp = decrypted;
                if (mounted) setState(() => _isE2eeActive = true);
              } else {
                debugPrint('[CALL-E2EE] Failed to decrypt SDP offer');
                break;
              }
            }
            await _handleOffer(sdp);
          }
          break;
      }
    });
  }

  Future<void> _handleOffer(String sdp) async {
    if (_pc == null) {
      debugPrint('[CALL-E2EE] _handleOffer: PeerConnection is null!');
      return;
    }
    debugPrint('[CALL-E2EE] Setting remote description (offer)...');
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    _remoteDescriptionSet = true;
    _flushPendingCandidates();

    debugPrint('[CALL-E2EE] Creating SDP answer...');
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    final answerSdp = answer.sdp ?? '';
    if (_peerId != null) {
      final encrypted = await _crypto.encryptMessage(_peerId!, answerSdp);
      if (encrypted != null) {
        debugPrint('[CALL-E2EE] SDP answer encrypted, sending');
        await WsClient().send(
          '/app/call.sdpAnswer',
          body: jsonEncode({
            'callId': _activeCallId,
            'sdp': '${encrypted.messageType}:${encrypted.ciphertextBase64}',
            'encrypted': true,
          }),
        );
        if (mounted) setState(() => _isE2eeActive = true);
        return;
      }
    }
    debugPrint('[CALL-E2EE] Fallback: sending SDP answer unencrypted');
    await WsClient().send(
      '/app/call.sdpAnswer',
      body: jsonEncode({'callId': _activeCallId, 'sdp': answerSdp, 'encrypted': false}),
    );
  }

  Future<void> _sendEncryptedIce(RTCIceCandidate candidate) async {
    final candidateJson = jsonEncode(candidate.toMap());
    if (_peerId != null) {
      final encrypted = await _crypto.encryptMessage(_peerId!, candidateJson);
      if (encrypted != null) {
        await WsClient().send(
          '/app/call.ice',
          body: jsonEncode({
            'callId': _activeCallId,
            'candidate': '${encrypted.messageType}:${encrypted.ciphertextBase64}',
            'encrypted': true,
          }),
        );
        return;
      }
    }
    await WsClient().send(
      '/app/call.ice',
      body: jsonEncode({
        'callId': _activeCallId,
        'candidate': candidateJson,
        'encrypted': false,
      }),
    );
  }

  Future<String?> _decryptSignaling(String payload) async {
    if (_peerId == null) return null;
    try {
      final colonIdx = payload.indexOf(':');
      if (colonIdx < 0) return null;
      final messageType = int.tryParse(payload.substring(0, colonIdx));
      final ciphertext = payload.substring(colonIdx + 1);
      if (messageType == null) return null;
      return await _crypto.decryptMessage(_peerId!, ciphertext, messageType);
    } catch (e) {
      debugPrint('[CALL-E2EE] Decrypt signaling error: $e');
      return null;
    }
  }

  void _flushPendingCandidates() {
    if (_pc == null || _pendingCandidates.isEmpty) return;
    debugPrint('[CALL] Flushing ${_pendingCandidates.length} pending ICE candidates');
    for (final candidate in _pendingCandidates) {
      _pc!.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration++);
    });
  }

  String get _formattedDuration {
    final m = (_duration ~/ 60).toString().padLeft(2, '0');
    final s = (_duration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleMute() {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = _isMuted;
    });
    if (mounted) setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaker() {
    _localStream?.getAudioTracks().forEach((track) {
      track.enableSpeakerphone(!_isSpeaker);
    });
    if (mounted) setState(() => _isSpeaker = !_isSpeaker);
  }

  void _toggleCamera() {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isVideoEnabled;
    });
    if (mounted) setState(() => _isVideoEnabled = !_isVideoEnabled);
  }

  void _flipCamera() {
    _localStream?.getVideoTracks().forEach((track) {
      Helper.switchCamera(track);
    });
    if (mounted) setState(() => _isFrontCamera = !_isFrontCamera);
  }

  void _endCall({bool sendToServer = true}) {
    if (_callEnded) return;
    _callEnded = true;

    _durationTimer?.cancel();
    _durationTimer = null;

    if (_wsSubId != null) {
      WsClient().unsubscribeById(_wsSubId!);
      _wsSubId = null;
    }

    // Важно: сначала отправить call.end — сервер разошлёт CALL_ENDED обоим участникам
    if (sendToServer && _activeCallId != null) {
      final callId = _activeCallId;
      WsClient().send(
        '/app/call.end',
        body: jsonEncode({'callId': callId}),
      ).catchError((_) {});
    }

    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        // Открыто через push (context.go) — pop невозможен, идём на главную
        context.go('/');
      }
    }
  }

  void _showE2eeInfo() {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null || _peerId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B2838),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<String?>(
          future: _crypto.getSafetyNumber(userId, _peerId!),
          builder: (ctx, snap) {
            final safetyNumber = snap.data;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(Icons.lock, color: Color(0xFF34C759), size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Сквозное шифрование',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Сигналинг этого звонка (SDP, ICE) зашифрован через Signal Protocol. '
                    'Сервер не может перехватить медиапоток.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  ),
                  if (safetyNumber != null) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Код безопасности',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Сравните этот код вслух во время звонка:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatSafetyNumber(safetyNumber),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatSafetyNumber(String number) {
    final clean = number.replaceAll(RegExp(r'\s'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i += 5) {
      if (buffer.isNotEmpty) buffer.write('  ');
      buffer.write(clean.substring(i, (i + 5).clamp(0, clean.length)));
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _durationTimer?.cancel();

    if (_wsSubId != null) {
      WsClient().unsubscribeById(_wsSubId!);
      _wsSubId = null;
    }

    // Отвязываем stream от renderers
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;

    final stream = _localStream;
    _localStream = null;
    final pc = _pc;
    _pc = null;

    // Отложенная очистка — track.stop() и pc.close() могут блокировать на Android
    if (stream != null || pc != null) {
      Future(() {
        stream?.getTracks().forEach((track) => track.stop());
        stream?.dispose();
        pc?.close();
      });
    }

    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'VIDEO';
    final isConnected = _status == 'Connected';

    return Scaffold(
      backgroundColor: isVideo ? Colors.black : null,
      body: _isIncomingPending
          ? _buildIncomingUI()
          : isVideo
              ? _buildVideoCallUI(isConnected)
              : _buildAudioCallUI(isConnected),
    );
  }

  // ── Incoming Call ──────────────────────────────────────────────────

  Widget _buildIncomingUI() {
    final isVideo = widget.callType == 'VIDEO';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2838), Color(0xFF0F1923)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            _PulsingAvatar(animation: _ringController, name: widget.calleeName),
            const SizedBox(height: 24),
            Text(
              widget.calleeName,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'Входящий видеозвонок' : 'Входящий аудиозвонок',
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(
                    icon: Icons.call_end,
                    label: 'Отклонить',
                    bg: const Color(0xFFFF3B30),
                    onTap: _rejectCall,
                  ),
                  _RoundButton(
                    icon: Icons.call,
                    label: 'Принять',
                    bg: const Color(0xFF34C759),
                    onTap: _acceptCall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── Video Call (VK-style: fullscreen remote + PiP local) ──────────

  Widget _buildVideoCallUI(bool isConnected) {
    return Stack(
      children: [
        // Fullscreen video (remote by default, local when swapped)
        Positioned.fill(
          child: _swappedVideo
              ? (_isVideoEnabled
                  ? RTCVideoView(
                      _localRenderer,
                      mirror: _isFrontCamera,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: const Color(0xFF1B2838),
                      child: const Center(
                        child: Icon(Icons.videocam_off, color: Colors.white38, size: 64),
                      ),
                    ))
              : RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
        ),

        // PiP video (local by default, remote when swapped) — tap to swap
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          width: 110,
          height: 160,
          child: GestureDetector(
            onTap: () => setState(() => _swappedVideo = !_swappedVideo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: _swappedVideo
                    ? RTCVideoView(
                        _remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : (_isVideoEnabled
                        ? RTCVideoView(
                            _localRenderer,
                            mirror: _isFrontCamera,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          )
                        : Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.videocam_off, color: Colors.white70, size: 28),
                            ),
                          )),
              ),
            ),
          ),
        ),

        // Top bar — name + timer
        Positioned(
          top: 0,
          left: 0,
          right: 130,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.calleeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_isE2eeActive) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _showE2eeInfo,
                        child: const Icon(Icons.lock, color: Color(0xFF34C759), size: 16),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected ? _formattedDuration : _displayStatus,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _VkCallBtn(
                  icon: Icons.flip_camera_ios,
                  label: 'Камера',
                  active: false,
                  onTap: _flipCamera,
                ),
                _VkCallBtn(
                  icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  label: 'Видео',
                  active: !_isVideoEnabled,
                  onTap: _toggleCamera,
                ),
                _VkCallBtn(
                  icon: _isSpeaker ? Icons.volume_up : Icons.volume_off,
                  label: 'Динамик',
                  active: !_isSpeaker,
                  onTap: _toggleSpeaker,
                ),
                _VkCallBtn(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: 'Микрофон',
                  active: _isMuted,
                  onTap: _toggleMute,
                ),
                _VkCallBtn(
                  icon: Icons.call_end,
                  label: 'Завершить',
                  isEnd: true,
                  onTap: _endCall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Audio Call ─────────────────────────────────────────────────────

  Widget _buildAudioCallUI(bool isConnected) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2838), Color(0xFF0F1923)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            if (!isConnected)
              _PulsingAvatar(animation: _ringController, name: widget.calleeName)
            else
              _RoundedAvatar(
                size: 112,
                name: widget.calleeName,
              ),
            const SizedBox(height: 24),
            Text(
              widget.calleeName,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            isConnected
                ? Text(_formattedDuration,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF34C759), fontWeight: FontWeight.w500))
                : Text(_displayStatus,
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.6))),
            if (_isE2eeActive) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showE2eeInfo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Color(0xFF34C759), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Сквозное шифрование',
                        style: TextStyle(color: Color(0xFF34C759), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _VkCallBtn(
                    icon: _isSpeaker ? Icons.volume_up : Icons.volume_off,
                    label: 'Динамик',
                    active: !_isSpeaker,
                    onTap: _toggleSpeaker,
                    light: true,
                  ),
                  _VkCallBtn(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: 'Микрофон',
                    active: _isMuted,
                    onTap: _toggleMute,
                    light: true,
                  ),
                  _VkCallBtn(
                    icon: Icons.call_end,
                    label: 'Завершить',
                    isEnd: true,
                    onTap: _endCall,
                    light: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────

class _PulsingAvatar extends StatelessWidget {
  final Animation<double> animation;
  final String name;

  const _PulsingAvatar({required this.animation, required this.name});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(3, (i) {
              final delay = i * 0.33;
              final t = ((animation.value + delay) % 1.0);
              final scale = 1.0 + t * 0.45;
              final opacity = (1 - t) * 0.4;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF5B7FFF).withValues(alpha: opacity),
                      width: 2,
                    ),
                  ),
                ),
              );
            }),
            _RoundedAvatar(size: 112, name: name),
          ],
        );
      },
    );
  }
}

class _RoundedAvatar extends StatelessWidget {
  final double size;
  final String name;

  const _RoundedAvatar({required this.size, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF5B7FFF).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(size * 0.14),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.4,
            color: const Color(0xFF5B7FFF),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.label, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(radius: 34, backgroundColor: bg, child: Icon(icon, color: Colors.white, size: 30)),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: bg, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _VkCallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool isEnd;
  final bool light;

  const _VkCallBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.isEnd = false,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (isEnd) {
      bg = const Color(0xFFFF3B30);
      fg = Colors.white;
    } else if (active) {
      bg = Colors.white.withValues(alpha: light ? 0.25 : 0.3);
      fg = Colors.white;
    } else {
      bg = Colors.white.withValues(alpha: light ? 0.12 : 0.15);
      fg = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
            child: Icon(icon, color: fg, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
