#!/usr/bin/env ruby
# Script to add MiniLM resources to the Xcode project

require 'xcodeproj'

project_path = File.expand_path('../Reef.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

# Find the main target (Reef)
target = project.targets.find { |t| t.name == 'Reef' }
unless target
  puts "Error: Could not find Reef target"
  exit 1
end

# Find or create the Resources group
main_group = project.main_group
reef_group = main_group.groups.find { |g| g.name == 'Reef' }
unless reef_group
  puts "Error: Could not find Reef group"
  exit 1
end

resources_group = reef_group.groups.find { |g| g.name == 'Resources' }
unless resources_group
  resources_group = reef_group.new_group('Resources', 'Reef/Resources')
  puts "Created Resources group"
end

# Add MiniLM-L6-v2.mlpackage
mlpackage_path = 'Reef/Resources/MiniLM-L6-v2.mlpackage'
existing_mlpackage = resources_group.files.find { |f| f.path&.include?('MiniLM') }
unless existing_mlpackage
  mlpackage_ref = resources_group.new_file(mlpackage_path)
  target.resources_build_phase.add_file_reference(mlpackage_ref)
  puts "Added MiniLM-L6-v2.mlpackage to project"
else
  puts "MiniLM-L6-v2.mlpackage already in project"
end

# Add tokenizer_vocab.json
vocab_path = 'Reef/Resources/tokenizer_vocab.json'
existing_vocab = resources_group.files.find { |f| f.path&.include?('tokenizer_vocab') }
unless existing_vocab
  vocab_ref = resources_group.new_file(vocab_path)
  target.resources_build_phase.add_file_reference(vocab_ref)
  puts "Added tokenizer_vocab.json to project"
else
  puts "tokenizer_vocab.json already in project"
end

# Save the project
project.save
puts "Project saved successfully!"
