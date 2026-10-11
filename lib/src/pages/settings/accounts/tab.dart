import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/accounts/accounts_settings_provider.dart';
import 'package:budgly/src/pages/settings/accounts/widgets/accounts_tab_content.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:flutter/material.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountsTab extends ConsumerStatefulWidget {
  const AccountsTab({super.key});

  @override
  ConsumerState<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends ConsumerState<AccountsTab>
    with AutomaticKeepAliveClientMixin<AccountsTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  Color _formColor = Colors.primaries.first;
  String? _formPicture;

  @override
  void initState() {
    super.initState();
    if (!ref.read(accountsSessionProvider).hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(accountsSettingsProvider.notifier).loadAccounts();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _confirmDelete(Account account) {
    final tr = AppLocalizations.of(context)!;

    showConfirmDelete(
      context,
      title: tr.confirmDeleteAccount(account.name),
      content: tr.confirmDeleteAccountMessage(account.name),
      onConfirm: () async {
        await ref
            .read(accountsSettingsProvider.notifier)
            .removeAccount(account);
      },
    );
  }

  Future<void> _addAccount() async {
    final notifier = ref.read(accountsSettingsProvider.notifier);
    final draft = await notifier.addAccount();
    if (draft != null) {
      _nameController.text = draft.name;
      _formColor = draft.color ?? Colors.primaries.first;
      _formPicture = draft.pictureUrl;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    ref.listen(accountsSettingsProvider.select((s) => s.editingAccount), (
      previous,
      next,
    ) {
      _nameController.text = next?.name ?? '';
      _formColor = next?.color ?? Colors.primaries.first;
      _formPicture = next?.pictureUrl;
    });

    return AccountsTabContent(
      formKey: _formKey,
      scrollController: _scrollController,
      nameController: _nameController,
      formColor: _formColor,
      formPicture: _formPicture,
      onColorChanged: (color) => setState(() => _formColor = color),
      onPictureChanged: (picture) => setState(() => _formPicture = picture),
      onConfirmDelete: _confirmDelete,
      onAddAccount: _addAccount,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
