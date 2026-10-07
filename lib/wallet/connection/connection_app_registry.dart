class ConnectionAppRegistry {
  const ConnectionAppRegistry();

  String? displayNameFor(String identifier) => const {
        'com.negosmint.taskplatform': 'NegosMint Task Platform',
      }[identifier];

  bool isTrusted(String identifier, String displayName) =>
      displayNameFor(identifier) == displayName;
}
