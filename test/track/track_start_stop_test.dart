// Copyright 2026 LiveKit, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import 'package:livekit_client/src/track/track.dart';
import 'package:livekit_client/src/types/other.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _SlowStartTrack createTrack() => _SlowStartTrack(
    _FakeMediaStream('stream-1'),
    _FakeMediaStreamTrack(id: 'audio-1', kind: 'audio'),
  );

  group('Track.stop() during an in-flight start()', () {
    test('waits for the capture to open and then closes it', () async {
      final track = createTrack();

      final start = track.start();
      // stop arrives while startCapture() is still opening the capture, the
      // window in which a call that ends early used to leave the microphone on
      final stop = track.stop();

      track.captureStarted.complete();

      expect(await start, isTrue);
      expect(await stop, isTrue);
      expect(track.startCaptureCount, 1);
      expect(track.stopCaptureCount, 1);
      expect(track.isActive, isFalse);
    });

    test('does not throw when the in-flight start fails', () async {
      final track = createTrack();

      final start = track.start();
      final stop = track.stop();

      track.captureStarted.completeError(StateError('capture failed'));

      await expectLater(start, throwsStateError);
      expect(await stop, isFalse);
      expect(track.stopCaptureCount, 0);
      expect(track.isActive, isFalse);
    });
  });

  test('concurrent start() calls open the capture once', () async {
    final track = createTrack();

    final first = track.start();
    final second = track.start();

    track.captureStarted.complete();

    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(track.startCaptureCount, 1);
    expect(track.isActive, isTrue);
  });
}

class _SlowStartTrack extends Track {
  final captureStarted = Completer<void>();
  int startCaptureCount = 0;
  int stopCaptureCount = 0;

  _SlowStartTrack(rtc.MediaStream stream, rtc.MediaStreamTrack track)
    : super(TrackType.AUDIO, TrackSource.microphone, stream, track);

  @override
  Future<void> startCapture() async {
    startCaptureCount++;
    await captureStarted.future;
  }

  @override
  Future<void> stopCapture() async {
    stopCaptureCount++;
  }

  @override
  Future<bool> monitorStats() async => false;
}

class _FakeMediaStream extends rtc.MediaStream {
  final List<rtc.MediaStreamTrack> _tracks = [];

  _FakeMediaStream(String id) : super(id, 'fake-owner');

  @override
  bool? get active => true;

  @override
  Future<void> addTrack(rtc.MediaStreamTrack track, {bool addToNative = true}) async {
    _tracks.add(track);
  }

  @override
  Future<rtc.MediaStream> clone() async => _FakeMediaStream('${id}_clone');

  @override
  List<rtc.MediaStreamTrack> getAudioTracks() => _tracks.where((t) => t.kind == 'audio').toList();

  @override
  Future<void> getMediaTracks() async {}

  @override
  List<rtc.MediaStreamTrack> getTracks() => List<rtc.MediaStreamTrack>.from(_tracks);

  @override
  List<rtc.MediaStreamTrack> getVideoTracks() => _tracks.where((t) => t.kind == 'video').toList();

  @override
  Future<void> removeTrack(rtc.MediaStreamTrack track, {bool removeFromNative = true}) async {
    _tracks.remove(track);
  }
}

class _FakeMediaStreamTrack implements rtc.MediaStreamTrack {
  @override
  rtc.StreamTrackCallback? onEnded;

  @override
  rtc.StreamTrackCallback? onMute;

  @override
  rtc.StreamTrackCallback? onUnMute;

  @override
  bool enabled;

  @override
  final String id;

  @override
  final String kind;

  @override
  String? get label => '$kind-track';

  @override
  bool? get muted => false;

  _FakeMediaStreamTrack({
    required this.id,
    required this.kind,
    this.enabled = true,
  });

  @override
  Future<void> adaptRes(int width, int height) async {}

  @override
  Future<void> applyConstraints([Map<String, dynamic>? constraints]) async {}

  @override
  Future<ByteBuffer> captureFrame() {
    throw UnimplementedError();
  }

  @override
  Future<rtc.MediaStreamTrack> clone() async => _FakeMediaStreamTrack(id: id, kind: kind, enabled: enabled);

  @override
  Future<void> dispose() async {}

  @override
  Map<String, dynamic> getConstraints() => const {};

  @override
  Map<String, dynamic> getSettings() => const {};

  @override
  Future<bool> hasTorch() async => false;

  @override
  void enableSpeakerphone(bool enable) {}

  @override
  Future<void> setTorch(bool torch) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> switchCamera() async => false;
}
