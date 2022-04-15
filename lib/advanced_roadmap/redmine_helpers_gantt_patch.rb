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

        # Returns the number of rows that will be used to list a project on
        # the Gantt chart.  This will recurse for each subproject.
        alias_method :number_of_rows_on_project_without_advanced_roadmap, :number_of_rows_on_project
        def number_of_rows_on_project(project)
          return 0 unless projects.include?(project)
          count = 1
          if project.milestones.any?
            count += 1
            project.milestones.each do |milestone|
              count += 1
              milestone.versions.each do |version|
                count += 1
                version.fixed_issues do |issue|
                  count += 1
                end
              end
            end
          end
          issues = project_issues(project).select {|i| i.fixed_version.nil?}
          if issues.present?
            count += 1
            count += issues.size
          end
          versions = project_versions(project)
          if versions.present?
            count += 1
            versions.each do |version|
              count += 1
              count += version_issues(project, version).size
            end
          end
          count
        end

        alias_method :render_project_without_advanced_roadmap, :render_project
        def render_project(project, options={})
          render_object_row(project, options)
          increment_indent(options) do
            # render project milestones.
            if project.milestones.any?
              subject_for_label(options, l(:label_milestone_plural), 'icon-milestones')
              options[:top] += options[:top_increment]
              increment_indent(options) do
                project.milestones.sort.each do |milestone|
                  render_milestone(project, milestone, options)
                end
              end
            end
            # render orphan issues (without parent version)
            issues = project_issues(project).select {|i| i.fixed_version.nil?}
            if issues.present?
              subject_for_label(options, l(:label_orphan_issues), 'icon-issue')
              options[:top] += options[:top_increment]
              increment_indent(options) do
                render_issues(issues, options)
              end
            end
            # then render project orphan versions (without parent milestone)
            versions = project_versions(project)
            if versions.present?
              subject_for_label(options, l(:label_orphan_versions), 'icon-package')
              options[:top] += options[:top_increment]
              increment_indent(options) do
                self.class.sort_versions!(versions)
                versions.each do |version|
                  if version.milestones.empty?
                    render_version(project, version, options)
                  end
                end
              end
            end
          end
        end

        def render_milestone(project, milestone, options={})
          render_object_row(milestone, options)
          increment_indent(options) do
            milestone.versions.each do |version|
              render_object_row(version, options)
              increment_indent(options) do
                issues = version.fixed_issues.to_ary
                render_issues(issues, options)
              end
            end
          end
        end

        alias_method :html_subject_content_without_advanced_roadmap, :html_subject_content
        def html_subject_content(object)
          case object
          when Hash
            view.content_tag('span', :class => 'icon icon-milestones') do
              label_milestone_plural
            end
          when Milestone
            html_class = +""
            html_class << 'icon icon-milestones '
            s = view.link_to_milestone(object).html_safe
            view.content_tag(:span, s, :class => html_class).html_safe
          else
            html_subject_content_without_advanced_roadmap(object)
          end
        end

        alias_method :html_subject_without_advanced_roadmap, :html_subject
        def html_subject(params, subject, object)
          content = html_subject_content(object) || subject
          tag_options = {}
          case object
          when Milestone
            tag_options[:id] = "milestone-#{object.id}"
            tag_options[:class] = "milestone-name"
            has_children = object.versions.present?
          when Issue
            tag_options[:id] = "issue-#{object.id}"
            tag_options[:class] = "issue-subject hascontextmenu"
            tag_options[:title] = object.subject
            children = object.children & project_issues(object.project)
            has_children = children.present? && (children.collect(&:fixed_version).uniq & [object.fixed_version]).present?
          when Version
            tag_options[:id] = "version-#{object.id}"
            tag_options[:class] = "version-name"
            has_children = object.fixed_issues.exists?
          when Project
            tag_options[:class] = "project-name"
            has_children = object.issues.exists? || object.versions.exists?
          end
          if object
            tag_options[:data] = {
                :collapse_expand => {
                    :top_increment => params[:top_increment],
                    :obj_id => "#{object.class}-#{object.id}".downcase,
                },
            }
          end
          if has_children
            content = view.content_tag(:span, nil, :class => 'icon icon-expended expander') + content
            tag_options[:class] += ' open'
          else
            if params[:indent]
              params = params.dup
              params[:indent] += 12
            end
          end
          style = "position: absolute;top:#{params[:top]}px;left:#{params[:indent]}px;"
          style += "width:#{params[:subject_width] - params[:indent]}px;" if params[:subject_width]
          tag_options[:style] = style
          output = view.content_tag(:div, content, tag_options)
          @subjects << output
          output
        end

        def subject_for_label(options, label, icon)
          case options[:format]
          when :html
            subject = view.content_tag('span', :class => 'icon ' + icon) do
              label
            end
            html_subject(options, subject, nil)
          when :image
            image_subject(options, label)
          when :pdf
            pdf_new_page?(options)
            pdf_subject(options, label)
          end
        end

        def subject_for_milestone(milestone, options)
          case options[:format]
          when :html
            subject = view.content_tag('span', :class => 'icon icon-milestone') do
              view.link_to_milestone(milestone)
            end
            html_subject(options, subject, milestone)
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
