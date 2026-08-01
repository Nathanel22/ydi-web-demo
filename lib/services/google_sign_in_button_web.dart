import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget renderGoogleSignInButton({bool forceGeneric = false}) =>
    web.renderButton(
      configuration: forceGeneric
          ? web.GSIButtonConfiguration(
              type: web.GSIButtonType.icon,
              size: web.GSIButtonSize.large,
              shape: web.GSIButtonShape.pill,
            )
          : web.GSIButtonConfiguration(
              size: web.GSIButtonSize.large,
              text: web.GSIButtonText.signinWith,
              locale: 'de',
            ),
    );
