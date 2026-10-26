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
import '../mock/peerconnection_mock.dart';

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

  test('a full reconnect releases the frame cryptors before closing the peer connections', () async {
    final engine = container.room.engine;
    final ws = container.wsConnector;
    final publisherPc = engine.publisher!.pc as MockPeerConnection;
    final subscriberPc = engine.subscriber!.pc as MockPeerConnection;

    bool? publisherClosedAtRelease;
    bool? subscriberClosedAtRelease;
    e2eeManager.onDisposeFrameCryptors = () {
      publisherClosedAtRelease = publisherPc.closed;
      subscriberClosedAtRelease = subscriberPc.closed;
    };

    final previousHandlers = ws.handlers;
    engine.fullReconnectOnNext = true;
    ws.onDispose();
    for (var i = 0; i < 200 && identical(ws.handlers, previousHandlers); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ws.uri!.queryParameters['reconnect'], isNull, reason: 'must be a re-join, not a resume');
    await container.answerJoin();
    await container.room.events.waitFor<RoomReconnectedEvent>(duration: const Duration(seconds: 4));

    expect(e2eeManager.disposeFrameCryptorsCount, 1);
    expect(publisherClosedAtRelease, isFalse);
    expect(subscriberClosedAtRelease, isFalse);
    expect(publisherPc.closed, isTrue, reason: 'the restart must have replaced the old peer connections');
    // the manager stays set up, so republished and resubscribed tracks get new cryptors
    expect(e2eeManager.disposeCount, 0);
    expect(container.room.e2eeManager, same(e2eeManager));
    expect(engine.e2eeManager, same(e2eeManager));
  });

  test('dispose without disconnect still disposes the E2EE manager once', () async {
    await container.room.dispose();

    expect(e2eeManager.disposeCount, 1);
    expect(container.room.engine.e2eeManager, isNull);
  });
}
