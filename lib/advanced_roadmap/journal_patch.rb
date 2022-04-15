# encoding: UTF-8

# Copyright © Emilio González Montaña
# Licence: Attribution & no derivates
#   * Attribution to the plugin web page URL should be done if you want to use it.
#     https://redmine.ociotec.com/projects/advanced-roadmap
#   * No derivates of this plugin (or partial) are allowed.
# Take a look to licence.txt file at plugin root folder for further details.

require_dependency 'issue'

module AdvancedRoadmap
  module JournalPatch
    def self.included(base)
      base.class_eval do

        alias_method :visible_details_without_advanced_roadmap, :visible_details
        def visible_details(user = User.current)
          details.select do |detail|
            if detail.property == 'cf'
              detail.custom_field && detail.custom_field.visible_by?(project, user)
            elsif detail.property == 'relation'
              Issue.find_by_id(detail.value || detail.old_value).try(:visible?, user)
            elsif detail.property == 'attr' && detail.prop_key == 'estimated_hours'
              user.allowed_to?(:view_issue_estimated_hours, project)
            else
              true
            end
          end
        end

      end
    end
  end
end
