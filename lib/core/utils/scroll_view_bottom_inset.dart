import 'package:flutter/material.dart';

// Extra bottom inset for scroll/list padding or trailing SizedBox height
double scrollViewBottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;
