# App-specific R8 rules belong here. Flutter and the included plugins provide
# their own consumer rules; do not add broad -keep or -dontwarn directives just
# to silence a release-build failure.

# Keep source/line metadata so uploaded mapping and native-symbol files produce
# useful Play Console crash reports without exposing debug code in the bundle.
-keepattributes SourceFile,LineNumberTable
