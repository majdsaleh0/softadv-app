import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/admin/presentation/screens/admin_listings_screen.dart';
import '../../features/admin/presentation/screens/admin_reports_screen.dart';
import '../../features/admin/presentation/screens/admin_users_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/bookings/presentation/screens/incoming_bookings_screen.dart';
import '../../features/bookings/presentation/screens/my_bookings_screen.dart';
import '../../features/bookings/presentation/screens/request_booking_screen.dart';
import '../../features/discovery/presentation/screens/browse_screen.dart';
import '../../features/discovery/presentation/screens/listing_detail_screen.dart';
import '../../features/discovery/presentation/screens/provider_profile_screen.dart';
import '../../features/listings/presentation/screens/listing_form_screen.dart';
import '../../features/listings/presentation/screens/my_listings_screen.dart';
import '../../features/messaging/domain/message.dart';
import '../../features/messaging/presentation/screens/inbox_screen.dart';
import '../../features/messaging/presentation/screens/message_thread_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reviews/domain/review.dart';
import '../../features/reviews/presentation/screens/review_form_screen.dart';

class AppRoute {
  AppRoute._();

  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const myListings = '/listings';
  static const newListing = '/listings/new';
  static const editListing = '/listings/:id/edit';
  static const browse = '/browse';
  static const listingDetail = '/browse/:id';
  static const providerProfile = '/providers/:id';
  static const requestBooking = '/browse/:id/book';
  static const myBookings = '/bookings';
  static const incomingBookings = '/bookings/incoming';
  static const reviewForm = '/bookings/:id/review';
  static const messages = '/messages';
  static const messageThread = '/messages/thread';
  static const notifications = '/notifications';
  static const adminListings = '/admin/listings';
  static const adminUsers = '/admin/users';
  static const adminReports = '/admin/reports';

  static String editListingPath(String id) => '/listings/$id/edit';
  static String listingDetailPath(String id) => '/browse/$id';
  static String providerProfilePath(String id) => '/providers/$id';
  static String requestBookingPath(String listingId) => '/browse/$listingId/book';
  static String reviewFormPath(String bookingId) => '/bookings/$bookingId/review';
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshStream = GoRouterRefreshStream(ref.watch(authRepositoryProvider).authStateChanges);
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: AppRoute.login,
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final authEvent = ref.read(authStateChangesProvider).value?.event;
      final isPasswordRecovery = authEvent == AuthChangeEvent.passwordRecovery;
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      final atResetPassword = state.matchedLocation == AppRoute.resetPassword;
      final loggedOutRoutes = {AppRoute.login, AppRoute.register, AppRoute.forgotPassword};

      // A password-recovery link signs the user into a temporary session — treat that
      // as neither logged-out nor a normal logged-in session, only reset-password.
      if (isPasswordRecovery) {
        return atResetPassword ? null : AppRoute.resetPassword;
      }
      if (!isLoggedIn) {
        return loggedOutRoutes.contains(state.matchedLocation) ? null : AppRoute.login;
      }
      if (loggedOutRoutes.contains(state.matchedLocation) || atResetPassword) {
        return AppRoute.profile;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoute.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoute.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: AppRoute.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: AppRoute.resetPassword, builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(path: AppRoute.profile, builder: (context, state) => const ProfileScreen()),
      GoRoute(path: AppRoute.editProfile, builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: AppRoute.myListings, builder: (context, state) => const MyListingsScreen()),
      GoRoute(path: AppRoute.newListing, builder: (context, state) => const ListingFormScreen()),
      GoRoute(path: AppRoute.editListing, builder: (context, state) => ListingFormScreen(listingId: state.pathParameters['id'])),
      GoRoute(path: AppRoute.browse, builder: (context, state) => const BrowseScreen()),
      GoRoute(path: AppRoute.listingDetail, builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!)),
      GoRoute(path: AppRoute.providerProfile, builder: (context, state) => ProviderProfileScreen(providerId: state.pathParameters['id']!)),
      GoRoute(path: AppRoute.requestBooking, builder: (context, state) => RequestBookingScreen(listingId: state.pathParameters['id']!)),
      GoRoute(path: AppRoute.myBookings, builder: (context, state) => const MyBookingsScreen()),
      GoRoute(path: AppRoute.incomingBookings, builder: (context, state) => const IncomingBookingsScreen()),
      GoRoute(
        path: AppRoute.reviewForm,
        builder: (context, state) => ReviewFormScreen(bookingId: state.pathParameters['id']!, existingReview: state.extra as Review?),
      ),
      GoRoute(path: AppRoute.messages, builder: (context, state) => const InboxScreen()),
      GoRoute(path: AppRoute.messageThread, builder: (context, state) => MessageThreadScreen(conversation: state.extra as ConversationRef)),
      GoRoute(path: AppRoute.notifications, builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: AppRoute.adminListings, builder: (context, state) => const AdminListingsScreen()),
      GoRoute(path: AppRoute.adminUsers, builder: (context, state) => const AdminUsersScreen()),
      GoRoute(path: AppRoute.adminReports, builder: (context, state) => const AdminReportsScreen()),
    ],
  );
});

/// Bridges Supabase's auth-state Stream to go_router's ChangeNotifier-based
/// refreshListenable, so the router re-evaluates `redirect` on every login/logout.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
