import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Centralized access to SDK-owned clients.
///
/// Production composition injects these into adapters/services. Tests can
/// override the providers instead of relying on static Firebase/Supabase
/// singleton access from deep inside the service graph.
final firebaseAuthClientProvider = Provider<fb.FirebaseAuth>(
  (ref) => fb.FirebaseAuth.instance,
);

final firestoreClientProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final supabaseClientProvider = Provider<sb.SupabaseClient>(
  (ref) => sb.Supabase.instance.client,
);

final googleSignInClientProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn.instance,
);
