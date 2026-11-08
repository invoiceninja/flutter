Pod::Spec.new do |s|
  s.name             = 'passkeys_native'
  s.version          = '1.0.0'
  s.summary          = 'The OS passkey sheet for the Invoice Ninja app.'
  s.homepage         = 'https://invoiceninja.com'
  s.license          = { :type => 'Elastic-2.0' }
  s.author           = { 'Invoice Ninja' => 'contact@invoiceninja.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'passkeys_native/Sources/passkeys_native/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.swift_version = '5.0'
end
