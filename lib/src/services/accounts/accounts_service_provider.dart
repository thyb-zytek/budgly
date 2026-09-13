import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'accounts_service_provider.g.dart';

/// Riverpod-facing exposure of [AccountsService] (issue M3).
///
/// Not rewritten: 8 call sites across `lib/` still read
/// `AccountsService.instance` directly (mostly not-yet-migrated ViewModels —
/// issue M4). Same reasoning as `profileService` (issue M1b): a future
/// migrated `Notifier` depends on this provider instead of `.instance`, and
/// tests override it directly instead of subclassing the service.
///
/// `AccountsService` holds no state of its own beyond `AccountsStore`
/// (already mirrored by `accountsSessionProvider`, issue M2) — no listener
/// wiring needed here, this is a plain pass-through.
@Riverpod(keepAlive: true)
AccountsService accountsService(Ref ref) => AccountsService.instance;
