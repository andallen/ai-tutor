# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'InkOS' do
  # Comment the next line if you don't want to use dynamic frameworks
  #  use_frameworks! :linkage => :static

  # Pods for InkOS
  pod 'MyScriptInteractiveInk-Runtime', '4.2.1'
  pod 'iosMath', :modular_headers => true
end

# Test target needs access to the same pods for compilation.
# Tests use mocks so they don't call MyScript at runtime, but need headers for @testable import InkOS.
target 'InkOSTests' do
  # Inherit pods from main target
  pod 'MyScriptInteractiveInk-Runtime', '4.2.1'
end
