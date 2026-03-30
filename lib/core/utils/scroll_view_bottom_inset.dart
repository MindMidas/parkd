import 'package:flutter/material.dart';

// extra bottom inset for scroll/list padding or trailing SizedBox height
double scrollViewBottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;
