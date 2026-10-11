import 'dart:async';

import 'package:budgly/src/core/dependencies/backend_clients_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// SDK client overrides for tests that only need to construct services.
///
/// Service provider tests must not require a real Firebase app or an initialized
/// Supabase singleton merely to prove that Riverpod can construct a service.
/// These clients are in-memory/test-only and must never be used by production
/// composition.
List<Override> testBackendClientOverrides() {
  final supabaseClient = supabase.SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    // Supabase enables auth token auto-refresh by default. Its periodic timer
    // remains pending inside flutter_test's FakeAsync zone and makes otherwise
    // unrelated widget tests fail during teardown. These tests never refresh
    // real Supabase sessions, so disable the timer and dispose the client.
    authOptions: const supabase.AuthClientOptions(autoRefreshToken: false),
  );
  addTearDown(() {
    // SupabaseClient spawns a YAJsonIsolate. Inside flutter_test's FakeAsync
    // zone that isolate's handshake never completes, so awaiting dispose()
    // would hang the test process forever (the isolate dispose awaits a port
    // message that FakeAsync never delivers). The client is test-only, has auth
    // auto-refresh disabled and performs no real network I/O, so disposal is
    // fire-and-forget.
    unawaited(supabaseClient.dispose());
  });

  return [
    firebaseAuthClientProvider.overrideWithValue(MockFirebaseAuth()),
    firestoreClientProvider.overrideWithValue(FakeFirebaseFirestore()),
    supabaseClientProvider.overrideWithValue(supabaseClient),
    googleSignInClientProvider.overrideWithValue(GoogleSignIn.instance),
  ];
}
