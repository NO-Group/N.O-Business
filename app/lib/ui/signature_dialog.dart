import 'package:flutter/material.dart';

import '../data/auth_store.dart';

/// Returns the signed-in staff identity used to attribute an action.
/// Authorization is provided by the authenticated account and role; there is
/// no secondary signature credential.
Future<StaffUser?> confirmSignature(BuildContext context, {bool force = false}) async {
  final user = AuthStore.instance.current;
  if (user != null) return user;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in before completing this action.')),
    );
  }
  return null;
}
