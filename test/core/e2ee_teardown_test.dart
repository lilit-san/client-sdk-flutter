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

@Timeout(Duration(seconds: 5))
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_client/src/internal/events.dart';
import '../mock/e2e_container.dart';
import '../mock/e2ee_fake_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late E2EContainer container;
  late TestE2EEManager e2eeManager;

  setUp(() async {
    container = E2EContainer();
    e2eeManager = TestE2EEManager();
    container.room.engine.setE2eeManager(e2eeManager);
    await container.connectRoom();
  });

  tearDown(() async {
    await container.dispose();
  });

  test('disconnect disposes the E2EE manager before closing the engine', () async {
    expect(container.room.e2eeManager, same(e2eeManager));

    bool? engineClosedAtDispose;
    e2eeManager.onDispose = () => engineClosedAtDispose = container.room.engine.isClosed;

    // A real engine reports the disconnect once the server closes the socket
    // after the leave request, and Room.disconnect() waits for that report.
    // The mock never does, so the report is fed in until disconnect returns.
    final engine = container.room.engine;
    var done = false;
    final disconnect = container.room.disconnect().whenComplete(() => done = true);
    while (!done) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      engine.events.emit(EngineDisconnectedEvent(reason: DisconnectReason.clientInitiated));
    }
    await disconnect;

    expect(e2eeManager.disposeCount, 1);
    expect(engineClosedAtDispose, isFalse);
    expect(container.room.e2eeManager, isNull);
    expect(container.room.engine.e2eeManager, isNull);
  });

  test('dispose without disconnect still disposes the E2EE manager once', () async {
    await container.room.dispose();

    expect(e2eeManager.disposeCount, 1);
    expect(container.room.engine.e2eeManager, isNull);
  });
}
