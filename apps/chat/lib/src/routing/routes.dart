/// Path builders, so widgets never hand-assemble URL strings.
abstract final class Routes {
  static const root = '/';
  static const channelPattern = '/servers/:serverId/channels/:channelId';

  static String channel(String serverId, String channelId) =>
      '/servers/$serverId/channels/$channelId';
}
