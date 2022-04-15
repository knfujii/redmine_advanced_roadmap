# encoding: UTF-8

# Copyright © Emilio González Montaña
# Licence: Attribution & no derivates
#   * Attribution to the plugin web page URL should be done if you want to use it.
#     https://redmine.ociotec.com/projects/advanced-roadmap
#   * No derivates of this plugin (or partial) are allowed.
# Take a look to licence.txt file at plugin root folder for further details.

module AdvancedRoadmap
  module RedmineHelpersGanttPatch
    def self.included(base)
      base.class_eval do

        include ApplicationHelper

        def render_project_with_milestones(project, options={})
          render_object_row(project, options)
          increment_indent(options) do
            # render project milestones.
            if project.milestones.any?
              subject_for_milestones_label(options)
              @number_of_rows += 1
              options[:top] += options[:top_increment]
              increment_indent(options) do
                project.milestones.sort.each do |milestone|
                  render_object_row(milestone, options)
                end
              end
            end
            # render issue that are not assigned to a version
            issues = project_issues(project).select {|i| i.fixed_version.nil?}
            render_issues(issues, options)
            # then render project versions and their issues
            versions = project_versions(project)
            self.class.sort_versions!(versions)
            versions.each do |version|
              render_version(project, version, options)
            end
          end
        end
        alias_method_chain :render_project, :milestones

        def subject_for_milestones_label(options)
          case options[:format]
          when :html
            subject = view.content_tag('span', :class => 'icon icon-milestones') do
              label_milestone_plural
            end
            html_subject(options, subject, :css => 'milestones-label')
          when :image
            image_subject(options, label_milestone_plural)
          when :pdf
            pdf_new_page?(options)
            pdf_subject(options, label_milestone_plural)
          end
        end

        def subject_for_milestone(milestone, options)
          case options[:format]
          when :html
            subject = view.content_tag('span', :class => 'icon icon-milestone') do
              view.link_to_milestone(milestone)
            end
            html_subject(options, subject, :css => 'milestone-name')
          when :image
            image_subject(options, milestone.to_s)
          when :pdf
            pdf_new_page?(options)
            pdf_subject(options, milestone.to_s)
          end
        end

        def line_for_milestone(milestone, options)
          # Skip milestones that don't have an effective date
          if milestone.is_a?(Milestone) && milestone.milestone_effective_date
            options[:zoom] ||= 1
            options[:g_width] ||= (self.date_to - self.date_from + 1) * options[:zoom]
            coords = coordinates_point(milestone.milestone_effective_date, options[:zoom], options[:format])
            label = h(milestone)
            case options[:format]
              when :html
                html_task(options, coords, true, label, milestone)
              when :image
                image_task(options, coords, true, label, milestone)
              when :pdf
                pdf_task(options, coords, true, label, milestone)
              else
                raise 'Invalid type'
            end
          else
            ActiveRecord::Base.logger.debug 'Gantt#line_for_milestone was not given a milestone with an milestone_effective_date'
            ''
          end
        end

      private

        def coordinates_point(date, zoom = nil, format = nil)
          zoom ||= @zoom
          coords = {}
          if date && (self.date_from < date) && (self.date_to > date)
            coords[:start] = date - self.date_from
            coords[:end] = (format == :pdf) ? (coords[:start]) : (coords[:start] - 1)
            coords[:bar_end] = date - self.date_from
          end
          # Transforms dates into pixels width
          coords.keys.each do |key|
            coords[key] = ((coords[key] * zoom) + (zoom.to_f / 2.0)).floor
          end
          return(coords)
        end

      end
    end
  end
end
