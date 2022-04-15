# encoding: UTF-8

# Copyright © Emilio González Montaña
# Licence: Attribution & no derivates
#   * Attribution to the plugin web page URL should be done if you want to use it.
#     https://redmine.ociotec.com/projects/advanced-roadmap
#   * No derivates of this plugin (or partial) are allowed.
# Take a look to licence.txt file at plugin root folder for further details.

module AdvancedRoadmap
  class Setting

    %w(color_good
       color_bad
       color_very_bad
       milestone_label
       milestone_plural_label).each do |setting|
      src = <<-END_SRC
      def self.#{setting}
        setting_or_default(:#{setting})
      end
      END_SRC
      class_eval src, __FILE__, __LINE__
    end

    %w(parallel_effort_custom_field
       solved_issues_to_estimate).each do |setting|
      src = <<-END_SRC
      def self.#{setting}
        setting_or_default(:#{setting}).to_i
      end
      END_SRC
      class_eval src, __FILE__, __LINE__
    end

    %w(ratio_good
       ratio_bad
       ratio_very_bad).each do |setting|
      src = <<-END_SRC
      def self.#{setting}
        setting_or_default(:#{setting}).to_f
      end
      END_SRC
      class_eval src, __FILE__, __LINE__
    end

  private

    def self.setting_or_default(setting)
      ::Setting.plugin_advanced_roadmap[setting] ||
      Redmine::Plugin::registered_plugins[:advanced_roadmap].settings[:default][setting]
    end

  end
end
