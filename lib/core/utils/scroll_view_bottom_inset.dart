import 'package:flutter/material.dart';

/// Extra bottom inset for scroll/list [padding] or trailing [SizedBox] height
/// Uses [MediaQuery.padding] (not [MediaQuery.viewPadding]) so nested routes
/// inside the main tab shell do not reserve the home-indicator gap twice: the
/// outer [Scaffold.bottomNavigationBar] already sits in the safe area, and the
/// tab body’s [MediaQuery.padding.bottom] is typically zero there
double scrollViewBottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;
