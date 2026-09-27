class Env {
  const Env._({required this.name, required this.appTitle});

  final String name;
  final String appTitle;

  static const dev = Env._(name: 'dev', appTitle: 'POC CICD [DEV]');
  static const uat = Env._(name: 'uat', appTitle: 'POC CICD [UAT]');
  static const prod = Env._(name: 'prod', appTitle: 'POC CICD');
}
