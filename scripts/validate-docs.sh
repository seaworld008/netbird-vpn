#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Checking local Markdown links"
ruby -e '
  Dir.glob("**/*.md").each do |file|
    text = File.read(file)
    text.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each do |link|
      next if link =~ /^(https?:|mailto:|#)/
      path = link.split("#", 2)[0]
      next if path.empty?
      target = File.expand_path(path, File.dirname(file))
      unless File.exist?(target)
        warn "missing: #{file} -> #{link}"
        exit 1
      end
    end
  end
'

echo "==> Checking Markdown code fences"
ruby -e '
  bad = []
  Dir.glob("**/*.md").each do |file|
    stack = []
    File.readlines(file).each_with_index do |line, index|
      next unless line =~ /^(`{3,}|~{3,})/
      mark = Regexp.last_match(1)
      if stack.empty?
        stack << [mark[0], mark.length, index + 1]
      elsif stack[-1][0] == mark[0] && mark.length >= stack[-1][1]
        stack.pop
      else
        stack << [mark[0], mark.length, index + 1]
      end
    end
    bad << [file, stack] unless stack.empty?
  end
  if bad.any?
    bad.each { |file, stack| warn "unclosed #{file}: #{stack.inspect}" }
    exit 1
  end
'

echo "==> Parsing YAML code blocks"
ruby -ryaml -e '
  count = 0
  Dir.glob("**/*.md").each do |file|
    text = File.read(file)
    text.scan(/^```ya?ml\n(.*?)^```/m).each do |match|
      count += 1
      begin
        YAML.load_stream(match[0])
      rescue => error
        warn "YAML error in #{file}: #{error.message}"
        exit 1
      end
    end
  end
  puts "parsed yaml blocks: #{count}"
'

echo "==> Checking stale version markers"
if rg -n "v0\\.71\\.4|2026-06-05|512899d82|0358be2|how-to/networks|use-cases/setup-site-to-site-access" . --glob '!scripts/validate-docs.sh'; then
  echo "Found stale version markers or old official-doc paths" >&2
  exit 1
fi

echo "==> Checking patch whitespace"
git diff --check

echo "Documentation validation passed."
