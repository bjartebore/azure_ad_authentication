import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:azure_ad_authentication/init.dart';
import 'package:flutter/services.dart';

import 'exeption.dart';

class AzureAdAuthentication {
  static const MethodChannel _channel =
      MethodChannel('azure_ad_authentication');
  late String? _clientId, _authority;

  /// Create a new PublicClientApplication authenticating as the given [clientId],
  /// optionally against the selected [authority], defaulting to the common
  AzureAdAuthentication({String? clientId, String? authority}) {
    throw Exception(
        "Direct call is no longer supported in v1.0, please use static method createPublicClientApplication");
  }

  AzureAdAuthentication._create(
      {required String clientId, required String authority}) {
    _clientId = clientId;
    _authority = authority;
  }

  static Future<AzureAdAuthentication> createPublicClientApplication(
      {required String clientId, required String authority}) async {
    var res =
        AzureAdAuthentication._create(clientId: clientId, authority: authority);
    await res._initialize();

    return res;
  }

  /// Acquire a token interactively for the given [scopes]
  Future<UserAdModel?> acquireToken({required List<String> scopes}) async {
    var res = <String, dynamic>{'scopes': scopes};
    try {
      final String? json = await _channel.invokeMethod('acquireToken', res);
      UserAdModel userAdModel = UserAdModel.fromJson(jsonDecode(json!));
      return await getUserModel(userAdModel);
    } on PlatformException catch (e) {
      throw _convertException(e);
    }
  }

  Future<UserAdModel?> getUserModel(UserAdModel userAdModel) async {
    if (userAdModel.accessToken != null) {
      UserAdModel? user = (await Request.post(token: userAdModel.accessToken!));
      if (user != null) {
        user.accessToken = userAdModel.accessToken;
        user.expiresOn = userAdModel.expiresOn;
        return user;
      }
    }
    return userAdModel;
  }

  /// Acquire a token silently, with no user interaction, for the given [scopes]
  Future<UserAdModel?> acquireTokenSilent({required List<String> scopes}) async {
    //create the arguments
    var res = <String, dynamic>{'scopes': scopes};

    //call platform
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('loadAccounts');
      }
      final String json =
          await _channel.invokeMethod('acquireTokenSilent', res);
      UserAdModel userAdModel = UserAdModel.fromJson(jsonDecode(json));
      return await getUserModel(userAdModel);
    } on PlatformException catch (e) {
      throw _convertException(e);
    }
  }

  Future logout() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('loadAccounts');
      }
      await _channel.invokeMethod('logout', <String, dynamic>{});
    } on PlatformException catch (e) {
      throw _convertException(e);
    }
  }

  MsalException _convertException(PlatformException e) {
    switch (e.code) {
      case "CANCELLED":
        return MsalUserCancelledException();
      case "NO_SCOPE":
        return MsalInvalidScopeException();
      case "NO_ACCOUNT":
        return MsalNoAccountException();
      case "NO_CLIENTID":
        return MsalInvalidConfigurationException("Client Id not set");
      case "INVALID_AUTHORITY":
        return MsalInvalidConfigurationException("Invalid authroity set.");
      case "CONFIG_ERROR":
        return MsalInvalidConfigurationException(
            "Invalid configuration, please correct your settings and try again");
      case "NO_CLIENT":
        return MsalUninitializedException();
      case "CHANGED_CLIENTID":
        return MsalChangedClientIdException();
      case "INIT_ERROR":
        return MsalInitializationException();
      case "AUTH_ERROR":
      default:
        return MsalException("Authentication error");
    }
  }

  Future _initialize() async {
    var res = <String, dynamic>{'clientId': _clientId};
    if (_authority != null) {
      res["authority"] = _authority;
    }

    try {
      await _channel.invokeMethod('initialize', res);
    } on PlatformException catch (e) {
      throw _convertException(e);
    }
  }
}