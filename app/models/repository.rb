# frozen_string_literal: true

require "base64"
require "digest"

class Repository < ApplicationRecord
  include GithubApi

  has_many :pull_requests
  has_many :review_rules
  has_many :settings

  belongs_to :installation

  attr_reader :config

  def self.find_by_full_name(full_name)
    owner, name = full_name.split("/", 2)
    self.find_by(owner: owner, name: name)
  end

  # @param key [String]
  # @return [String]
  def read_setting(key)
    self.setting(key)&.read
  end

  def setting(key)
    self.settings.find_by(key: key)
  end

  def full_name
    "#{self.owner}/#{self.name}"
  end

  # Determines if the repository's settings would ignore the given set of labels
  def ignore?(labels)
    ignored_labels = Array(read_setting("ignore_labels"))
    ignored_labels.present? &&
      Set.new(ignored_labels).intersect?(Set.new(labels))
  end

  # Refresh this repository's config by reading the configuration file from
  # GitHub. If the configuration file could not be read, this method exits early
  # and does not update any configuration.
  def refresh_config!
    contents =
      begin
        Base64.decode64(
          github_client.contents(self.full_name, path: Config::PATH).content
        )
      rescue Octokit::NotFound
        return
      end

    digest = Digest::MD5.new
    digest.update(contents)
    hexdigest = digest.hexdigest
    return unless self.config_hash != hexdigest

    @config =
      begin
        Config.new(YAML.safe_load(contents))
      rescue Psych::Exception
        return
      end
    return unless self.config.valid?

    refresh_settings
    refresh_rules

    self.config_hash = hexdigest
    self.save!
  end

  private

  def refresh_settings
    if (min_reviewers_config = self.config[:minimum_reviewers_required])
      if (min_reviewers_setting = self.setting("minimum_reviewers_required"))
        min_reviewers_setting.set(min_reviewers_config)
        min_reviewers_setting.save!
      else
        self.settings.create!(
          key: "minimum_reviewers_required",
          value: min_reviewers_config
        )
      end
    end
  end

  def refresh_rules
    teams = github_client.org_teams(self.owner)
    self.config[:rules].each do |rule_config|
      refresh_rule(rule_config, teams)
    end
  end

  def refresh_rule(rule_config, teams)
    rule =
      if rule_config[:match] == true
        ReviewRuleAlways.find_or_initialize_by(
          short_code: rule_config[:short_code],
          repository_id: self.id
        )
      elsif rule_config[:match][:path]
        ReviewRuleFileMatch.find_or_initialize_by(
          short_code: rule_config[:short_code],
          repository_id: self.id,
        ).tap do |r|
          r.file_match = Array.wrap(rule_config[:match][:path]).join("|")
        end
      elsif rule_config[:match][:diff]
        ReviewRuleDiffMatch.find_or_initialize_by(
          short_code: rule_config[:short_code],
          repository_id: self.id,
        ).tap do |r|
          r.file_match = Array.wrap(rule_config[:match][:diff]).join("|")
        end
      end

    return unless rule

    rule.reviewer = rule_config[:reviewer]

    rule.name = rule_config[:name]
    rule.active = rule_config[:active]

    rule.save!
  end
end
