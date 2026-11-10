# Not Stripe's own class: com.google.android.play:review-ktx (from in_app_review)
# references this annotation, which no Play Services jar here defines. R8 let it
# pass until Stripe Terminal's consumer rules (`-keepattributes *Annotation*`,
# via mek_stripe_terminal) kept class annotations, and then failed the release
# build on the missing class. Store builds only.
-dontwarn com.google.android.gms.common.annotation.NoNullnessRewrite
