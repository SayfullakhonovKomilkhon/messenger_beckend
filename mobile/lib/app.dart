import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/providers.dart';
import 'core/widgets/app_lock_wrapper.dart';
import 'core/widgets/notification_handler.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'features/conversation/conversation_screen.dart';
import 'features/call/call_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/privacy_settings_screen.dart';
import 'features/settings/notifications_settings_screen.dart';
import 'features/settings/conversations_settings_screen.dart';
import 'features/settings/appearance_settings_screen.dart';
import 'features/settings/blocked_contacts_screen.dart';
import 'features/settings/message_requests_screen.dart';
import 'features/settings/edit_profile_screen.dart';
import 'features/profile/user_profile_screen.dart';
import 'features/group/create_group_screen.dart';
import 'features/group/group_info_screen.dart';
import 'features/bots/bots_list_screen.dart';
import 'features/bots/create_bot_screen.dart';
import 'features/bots/bot_detail_screen.dart';

class MessengerApp extends ConsumerWidget {
  const MessengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final authState = ref.watch(authStateProvider);
    final locale = ref.watch(localeProvider);
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final effectiveType = themeState.followSystemTheme
        ? (systemBrightness == Brightness.light
            ? AppThemeType.light
            : AppThemeType.dark)
        : themeState.type;
    final themeData = AppTheme.getTheme(
      effectiveType,
      AppColors.accentColors[themeState.accentIndex],
    );

    final router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        if (authState.isLoading) return null;
        final isAuth = authState.isAuthenticated;
        final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/onboarding';

        if (!isAuth && !isAuthRoute) return '/onboarding';
        if (isAuth && isAuthRoute) return '/';
        return null;
      },
      routes: [
        ShellRoute(
          builder: (context, state, child) => NotificationHandler(
            isAuthenticated: authState.isAuthenticated,
            child: child,
          ),
          routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const HomeScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const LoginScreen(),
        ),
        GoRoute(
          path: '/conversation/:id',
          builder: (_, state) => ConversationScreen(
            conversationId: state.pathParameters['id']!,
            participantName: state.uri.queryParameters['name'] ?? '',
            participantAvatar: state.uri.queryParameters['avatar'],
            participantId: state.uri.queryParameters['participantId'] ?? '',
            isGroup: state.uri.queryParameters['isGroup'] == 'true',
          ),
        ),
        GoRoute(
          path: '/call',
          builder: (_, state) => CallScreen(
            callId: state.uri.queryParameters['callId'] ?? '',
            calleeId: state.uri.queryParameters['calleeId'] ?? '',
            calleeName: state.uri.queryParameters['calleeName'] ?? '',
            callType: state.uri.queryParameters['callType'] ?? 'AUDIO',
            isIncoming: state.uri.queryParameters['incoming'] == 'true',
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/privacy',
          builder: (_, _) => const PrivacySettingsScreen(),
        ),
        GoRoute(
          path: '/settings/notifications',
          builder: (_, _) => const NotificationsSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/conversations',
          builder: (_, _) => const ConversationsSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/appearance',
          builder: (_, _) => const AppearanceSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/blocked',
          builder: (_, _) => const BlockedContactsScreen(),
        ),
        GoRoute(
          path: '/settings/edit-profile',
          builder: (_, _) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/settings/message-requests',
          builder: (_, _) => const MessageRequestsScreen(),
        ),
        GoRoute(
          path: '/profile/:id',
          builder: (_, state) => UserProfileScreen(
            userId: state.pathParameters['id']!,
            conversationId: state.uri.queryParameters['conversationId'],
            participantName: state.uri.queryParameters['name'],
            participantAvatar: state.uri.queryParameters['avatar'],
          ),
        ),
        GoRoute(
          path: '/groups/create',
          builder: (_, _) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: '/groups/:id/info',
          builder: (_, state) => GroupInfoScreen(
            groupId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/settings/bots',
          builder: (_, _) => const BotsListScreen(),
        ),
        GoRoute(
          path: '/settings/bots/create',
          builder: (_, _) => const CreateBotScreen(),
        ),
        GoRoute(
          path: '/settings/bots/:id',
          builder: (_, state) => BotDetailScreen(
            botId: state.pathParameters['id']!,
          ),
        ),
          ],
        ),
      ],
    );

    return AppLockWrapper(
      child: MaterialApp.router(
        title: 'Demos',
        theme: themeData,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
  }
}
