#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'

def dir(path=nil)
  path = "/#{path}" if path
  r = ''
  File.expand_path('.', __FILE__).gsub(/\\/, '/').split('/').reject{|d| d == ''}.each {|d|
    r += "/#{d}"
    return "#{r}#{path}" if File.directory?("#{r}/redmine_backlogs")
  }
  return nil
end

$key_order = []
def keycomp(a, b)
  pa = $key_order.index(a)
  pb = $key_order.index(b)

  return pa <=> pb if pa && pb
  return 1 if pa
  return -1 if pb
  return a.to_s <=> b.to_s
end

class Hash
  # sorted keys for cleaner diffs in git
  def to_yaml(opts = {})
    YAML::quick_emit(object_id, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        sort{|a, b| keycomp(a, b) }.each do |k, v|
          map.add(k, v)
        end
      end
    end
  end
end

webdir = dir('www.redminebacklogs.net')
webpage = File.open("#{webdir}/_posts/en/1992-01-01-translations.textile", 'w')
translations = dir('redmine_backlogs/config/locales')

$key_order = []
File.open("#{translations}/en.yml").each {|line|
  m = line.match(/^\s+[-_a-z0-9]+\s*:/)
  next unless m
  key = m[0].strip.gsub(/:$/, '').strip
  $key_order << key
}

translation = {}
Dir.glob("#{translations}/*.yml").each {|trans|
  strings = YAML::load_file(trans)
  translation[strings.keys[0]] = strings[strings.keys[0]]
}

webpage.write(<<HEADER)
---
title: Translations
layout: default
categories: en
---
h1. Translations

*Want to help out with translating Backlogs? Excellent!

Create an account at "GitHub":http://www.github.com if you don't have one yet. "Fork":https://github.com/relaxdiego/redmine_backlogs/fork the "Backlogs":http://github.com/relaxdiego/redmine_backlogs repository, in that repository browse to Source -> config -> locales, click on the translation you want to adapt, en click the "Edit this file" button. Change what you want, and then issue a "pull request":https://github.com/relaxdiego/redmine_backlogs/pull/new/master, and I'll be able to fetch your changes. The changes will automatically be attributed to you.

The messages below mean the following:

| *Missing* | the key is not present in the translation. |
| *Obsolete* | the key is present but no longer in use, so it should be removed. |
| *Old-style variable substitution* | the translation uses { { keyword } } instead of %{keyword}. This works for now, but redmine is in the process of phasing it out. |

bq(success). English

serves as a base for all other translations

HEADER

def same(s1, s2)
  return (s1.to_s.strip == s2.to_s.strip) && (s1.to_s.strip.split.size > 2)
end

def name(t)
  return YAML::load_file("#{dir('redmine/config/locales')}/#{t}.yml")[t]['general_lang_name']
end

translation.keys.sort.each {|t|
  next if t == 'en'

  untranslated = []
  varstyle = []

  nt = {}
  translation['en'].keys.each {|k|
    nt[k] = translation[t][k].to_s.strip
    nt[k] = translation['en'][k].to_s.strip if nt[k].strip == ''

    varstyle << k if nt[k].include?('{{')
    untranslated << k if same(nt[k], translation['en'][k])
  }
  untranslated = [] if t == 'en-GB'
  errors = (varstyle + untranslated).uniq

  if errors.size > 0
    pct = " (#{((nt.keys.size - errors.size) * 100) / nt.keys.size}%)"
  else
    pct = ''
  end

  if untranslated.size > 0
    status = 'error'
  elsif varstyle.size > 0
    status = 'warning'
  else
    status = 'success'
  end

  webpage.write("bq(#{status}). #{name(t)}#{pct}\n\n")

  columns = 2
  [[untranslated, 'Untranslated'], [varstyle, 'Old-style variable substitution']].each {|error|
    keys, title = *error
    next if keys.size == 0

    webpage.write("*#{title}*\n\n")
    keys.sort!
    while keys.size > 0
      row = (keys.shift(columns) + ['', ''])[0..columns-1]
      webpage.write("|" + row.join("|") + "|\n")
    end

    webpage.write("\n")

    File.open("#{translations}/#{t}.yml", 'w') do |out|
      out.write({t => nt}.to_yaml)
    end
  }
}
