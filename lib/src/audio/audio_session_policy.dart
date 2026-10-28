// Copyright 2024 LiveKit, Inc.
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

import 'package:meta/meta.dart';

import '../support/native_audio.dart';
import 'audio_session.dart';

@internal
class ResolvedAudioSessionPolicy {
  const ResolvedAudioSessionPolicy({
    required this.options,
    required this.preferSpeakerOutput,
    required this.forceSpeakerOutput,
    required this.automatic,
  });

  final AudioSessionOptions options;
  final bool preferSpeakerOutput;
  final bool forceSpeakerOutput;
  final bool automatic;

  /// Whether native should hard-route to the speaker with
  /// overrideOutputAudioPort. In automatic mode the mode is always voiceChat,
  /// so the override is the only way the speaker preference reaches iOS.
  bool get appleForceSpeakerOutput => automatic ? preferSpeakerOutput : forceSpeakerOutput;

  NativeAudioConfiguration get appleConfiguration {
    if (automatic) {
      return NativeAudioConfiguration(
        appleAudioCategory: AppleAudioCategory.playAndRecord,
        appleAudioCategoryOptions: {
          AppleAudioCategoryOption.allowBluetooth,
          AppleAudioCategoryOption.allowBluetoothA2DP,
          AppleAudioCategoryOption.allowAirPlay,
        },
        // Always voiceChat: the speaker is routed by overrideOutputAudioPort
        // (see appleForceSpeakerOutput), never by the mode. videoChat makes the
        // speaker the default route, which turns a system-level override(.none)
        // (the CallKit speaker button) into a no-op: the route never leaves the
        // speaker and no route change fires.
        appleAudioMode: AppleAudioMode.voiceChat,
      );
    }

    final apple = options.apple;
    return NativeAudioConfiguration(
      appleAudioCategory: apple.category,
      appleAudioCategoryOptions: apple.categoryOptions,
      appleAudioMode: apple.mode,
    );
  }

  AndroidAudioSessionConfiguration get androidConfiguration {
    // In automatic mode LiveKit still owns activation timing, focus/routing
    // lifecycle, and speaker preference. The Android session intent itself is
    // the current AudioSessionOptions value, seeded by LiveKitClient.initialize
    // or replaced explicitly by AudioManager.setAudioSessionOptions.
    return options.android;
  }
}
