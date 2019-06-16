
Pod::Spec.new do |s|
  s.name         = "RNNordicWrapper"
  s.version      = "1.0.0"
  s.summary      = "RNNordicWrapper"
  s.description  = <<-DESC
                  RNNordicWrapper
                   DESC
  s.homepage     = "https:///tusharksarkar74@github.com/tusharksarkar74/RNNordicWrapper"
  s.license      = "MIT"
  s.author             = { "Tushar" => "tusharksarkar74@gmail.com" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https:///tusharksarkar74@github.com/tusharksarkar74/RNNordicWrapper.git", :tag => "master" }
  s.source_files  = "RNNordicWrapper/**/*.{h,m}"
  s.requires_arc = true


  s.dependency "React"
  s.dependency 'ZIPFoundation', '~> 0.9.8'
  s.dependency 'iOSDFULibrary', '~> 4.4.0'

end

  