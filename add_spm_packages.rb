require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'Jagat.xcodeproj')
PACKAGES = [
  { name: 'OrbitCore',     path: 'Packages/OrbitCore' },
  { name: 'OrbitUI',       path: 'Packages/OrbitUI' },
  { name: 'OrbitServices', path: 'Packages/OrbitServices' },
]

project = Xcodeproj::Project.open(PROJECT_PATH)
target  = project.targets.find { |t| t.name == 'Jagat' }

# 1. Remove stale PBXFileReference wrappers for the packages (added by drag-drop)
stale_refs = project.files.select { |f| PACKAGES.any? { |p| f.path == p[:path] } }
stale_refs.each do |ref|
  # Remove from all groups
  project.groups.each { |g| g.children.delete(ref) rescue nil }
  ref.remove_from_project
end

# 2. Remove existing SPM build file entries & product dependencies for these packages
frameworks_phase = target.frameworks_build_phase
frameworks_phase.files.select { |f|
  f.product_ref && PACKAGES.any? { |p| f.product_ref.product_name == p[:name] }
}.each(&:remove_from_project)

target.package_product_dependencies.select { |d|
  PACKAGES.any? { |p| d.product_name == p[:name] }
}.each { |d| target.package_product_dependencies.delete(d); d.remove_from_project rescue nil }

# Remove existing XCLocalSwiftPackageReference for these paths
project.root_object.package_references.select { |r|
  PACKAGES.any? { |p| r.relative_path == p[:path] }
}.each { |r| project.root_object.package_references.delete(r); r.remove_from_project rescue nil }

# 3. Add XCLocalSwiftPackageReference + XCSwiftPackageProductDependency for each package
PACKAGES.each do |pkg|
  # Local package reference
  ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  ref.relative_path = pkg[:path]
  project.root_object.package_references << ref

  # Product dependency linked to the local ref
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.product_name = pkg[:name]
  dep.package = ref
  target.package_product_dependencies << dep

  # Add to Frameworks build phase
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  frameworks_phase.files << build_file
end

project.save
puts "Done. Packages added: #{PACKAGES.map { |p| p[:name] }.join(', ')}"
