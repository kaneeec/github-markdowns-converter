require 'optparse'
require 'shellwords'

def parse_cmd_opts(args)
  options = {}

  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: converter.rb [options]'

    opts.separator ''
    opts.separator 'Specific options:'

    opts.on('-g', '--github-url URL', 'URL to GitHub repository you want to convert') { |url| options[:url] = url }
    opts.on('-o', '--output-dir DIR', 'Output directory for data and results') { |dir| options[:dir] = dir }

    opts.separator ''
    opts.separator 'Common options:'

    opts.on_tail('-h', '--help', 'Show this message') do
      puts(opts)
      exit
    end
  end

  opt_parser.parse!(args)

  if !options.include?(:url) or !options.include?(:dir)
    puts(opt_parser)
    exit
  end

  options
end

def puts_header(text)
  puts("\n#{text}")
  puts('-'*(text.size))
end

def clone_repo
  %x(rm -rf #{OPTS[:dir]} && mkdir -p #{OPTS[:dir]} && cd #{OPTS[:dir]} && git clone #{OPTS[:url]} #{DEFAULT_REPO_NAME})
end

def find_readme_files
  Dir.glob(File.join(OPTS[:dir], DEFAULT_REPO_NAME, '**', 'README.md'))
end

def extract_local_file_links(file)
  links = []

  File.open(file) do |f|
    f.each_line do |line|
      line_links = line.scan(/\[.*\]\((.*)\.md\)/).flatten
      links << line_links unless line_links.empty?
    end
  end

  links.flatten
end

def concat_readme_and_links(readme_file_path, link_names)
  dest_file_name = readme_file_path.split(/[\/\\]/).select { |x| !x.empty? }.join('-').shellescape
  dest_file_path = File.join(OPTS[:dir], dest_file_name)
  link_names_full_path_escaped = link_names
                                   .map { |link_name| File.join(File.dirname(readme_file_path), "#{link_name}.md") }
                                   .shelljoin
  %x(cat #{link_names_full_path_escaped} > #{dest_file_path})
  dest_file_path
end

def generate_pdf(output_file_path)
  %x(cd #{OPTS[:dir]} && gimli #{output_file_path})
end

DEFAULT_REPO_NAME = 'repo'
OPTS = parse_cmd_opts(ARGV)

puts_header('Making local copy of the repository')
clone_repo

puts_header('Searching for README.md files')
readme_files = find_readme_files
puts(readme_files)

puts_header('Extracting local links from README.md files')
readme_files_with_link_names = readme_files
                                 .map { |readme_file| { readme_file => extract_local_file_links(readme_file) } }
                                 .inject(Hash.new) { |flattened, hash| flattened.merge(hash) }
puts(readme_files_with_link_names)

puts_header('Merging base README.md and local files into one')
dest_file_paths = []
readme_files_with_link_names.each_pair do |readme_file, link_names|
  dest_file_path = concat_readme_and_links(readme_file, link_names)
  puts(dest_file_path)
  dest_file_paths << dest_file_path
end

puts_header('Generating PDF files')
dest_file_paths.each do |dest_file_path|
  puts(dest_file_path)
  generate_pdf(dest_file_path)
end
