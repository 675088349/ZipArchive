Pod::Spec.new do |s|
  s.name         = 'SSZipArchive'
  s.version      = '2.6.1'
  s.summary      = 'Utility class for zipping and unzipping files on iOS, tvOS, visionOS, watchOS, and macOS.'
  s.description  = 'SSZipArchive is a simple utility class for zipping and unzipping files on iOS, tvOS, visionOS, watchOS, and macOS. It supports AES and PKWARE encryption.'
  s.homepage     = 'https://github.com/ZipArchive/ZipArchive'
  s.license      = { :type => 'MIT', :file => 'LICENSE.txt' }
  s.authors      = { 'Sam Soffes' => 'sam@soff.es', 'Joshua Hudson' => nil, 'Wilson Chen' => nil }
  s.source       = { :git => 'https://github.com/ZipArchive/ZipArchive.git', :tag => "#{s.version}" }
  s.ios.deployment_target = '15.5'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '15.4'
  s.visionos.deployment_target = '1.0'
  s.watchos.deployment_target = '8.4'
#  s.dependency 'UniversalDetector2'
  s.source_files = 'SSZipArchive/*.{m,h}', 'SSZipArchive/include/*.{m,h}', 'SSZipArchive/minizip/*.{c,h}', 'SSZipArchive/minizip/compat/*.{c,h}'
  s.resource_bundles = {'SSZipArchive' => ['SSZipArchive/Supporting Files/Privacyinfo.xcprivacy']}
  s.public_header_files = 'SSZipArchive/*.h'
  s.libraries = 'z', 'iconv'
  s.framework = 'Security'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'HAVE_ARC4RANDOM_BUF HAVE_ICONV HAVE_INTTYPES_H HAVE_PKCRYPT HAVE_STDINT_H HAVE_WZAES HAVE_ZLIB ZLIB_COMPAT' }
end
