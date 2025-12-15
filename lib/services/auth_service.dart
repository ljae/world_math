import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Observable Auth State
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Create/Get Current User
  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn.instance.signOut();
      // Kakao logout - only supported on Android/iOS
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await kakao.UserApi.instance.logout();
        } catch (e) {
          // Ignore kakao logout error (e.g. not logged in)
        }
      }
    } catch (e) {
      debugPrint("Error signing out: $e");
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // Google Login
  // --------------------------------------------------------------------------
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return null; // The user canceled the sign-in

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // Apple Login
  // --------------------------------------------------------------------------
  Future<UserCredential?> signInWithApple() async {
    // Apple Sign-In on macOS requires a paid Apple Developer account
    // For now, only enable on iOS
    if (Platform.isMacOS) {
      debugPrint("Apple Sign-In on macOS requires a paid Apple Developer Program membership");
      throw UnsupportedError('Apple Sign-In on macOS requires a paid Apple Developer account. Use iOS or enable with a paid account.');
    }

    try {
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        final oauthProvider = OAuthProvider('apple.com');
        final credential = oauthProvider.credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

        return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Error signing in with Apple: $e");
      // Handle cancellation specific error codes if needed
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // Kakao Login
  // --------------------------------------------------------------------------
  Future<UserCredential?> signInWithKakao() async {
    // Kakao SDK only supports Android and iOS
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint("Kakao Sign-In is not supported on this platform (${Platform.operatingSystem})");
      throw UnsupportedError('Kakao Sign-In is only supported on Android and iOS');
    }

    try {
      // 1. Get Kakao Token
      bool isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
      kakao.OAuthToken token;
      
      if (isKakaoTalkInstalled) {
        try {
            token = await kakao.UserApi.instance.loginWithKakaoTalk();
            debugPrint('Logged in with KakaoTalk');
        } catch (error) {
          debugPrint('KakaoTalk login failed: $error');
          // If user cancelled, return null? Or try account login?
          // Usability: usually fall back to account login if error is not simple cancellation
          if (error is PlatformException && error.code == 'CANCELED') {
              return null;
          }
          // Fallback to account login
          try {
             token = await kakao.UserApi.instance.loginWithKakaoAccount();
             debugPrint('Logged in with KakaoAccount (fallback)');
          } catch (e) {
             debugPrint('KakaoAccount login failed: $e');
             rethrow;
          }
        }
      } else {
        try {
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
          debugPrint('Logged in with KakaoAccount');
        } catch (error) {
          debugPrint('KakaoAccount login failed: $error');
          rethrow;
        }
      }

      // 2. Integration with Firebase
      // Ideally, you would send `token.accessToken` to your customized backend
      // which would mint a Firebase Custom Token using Admin SDK.
      // Since we are client-only here, we have two options:
      // A) Use 'oidc' provider if configured in Firebase Console (OpenID Connect).
      // B) signInAnonymously() and link manually or just use Firestore independently.
      
      // Attempting option B for simplicity in a "Serverless" context w/o user implementing Cloud Functions yet.
      // NOTE: This creates an "Anonymous" user in Firebase but we can store Kakao User Info.
      // Users might replace this with Custom Token auth if they have a backend.
      
      UserCredential userCredential = await _auth.signInAnonymously();
      
      // Fetch Kakao User Info to update profile
      try {
        kakao.User kakaoUser = await kakao.UserApi.instance.me();
        
        // Update Firebase Profile with Kakao Data
        if (userCredential.user != null) {
           await userCredential.user!.updateDisplayName(kakaoUser.kakaoAccount?.profile?.nickname);
           if (kakaoUser.kakaoAccount?.profile?.profileImageUrl != null) {
             await userCredential.user!.updatePhotoURL(kakaoUser.kakaoAccount?.profile?.profileImageUrl);
           }
        }
      } catch (e) {
        debugPrint("Failed to fetch/update Kakao user info: $e");
      }
      
      return userCredential;

    } catch (e) {
      debugPrint("Error signing in with Kakao: $e");
      rethrow;
    }
  }
}
