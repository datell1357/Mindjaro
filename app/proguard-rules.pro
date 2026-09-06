# Protobuf lite resolves generated message fields by their original names.
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}
