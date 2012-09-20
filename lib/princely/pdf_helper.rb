module PdfHelper
  require 'princely'

  def self.included(base)
    base.class_eval do
      alias_method_chain :render, :princely
    end
  end

  def render_with_princely(options = nil, *args, &block)
    if options.is_a?(Hash) && options.has_key?(:pdf)
      options[:name] ||= options.delete(:pdf)
      make_and_send_pdf(options.delete(:name), options)
    else
      render_without_princely(options, *args, &block)
    end
  end

  private

  def make_pdf(options = {})
    options[:stylesheets] ||= []
    options[:layout] ||= false
    options[:template] ||= File.join(controller_path,action_name)
    @transformed_stylesheets  = []
    @template.template_format = :html
    prince = Princely.new()
    # Sets style sheets on PDF renderer
    prince.add_style_sheets(*options[:stylesheets].collect{|style| stylesheet_file_path(style)})

    html_string = render_to_string(:template => options[:template], :layout => options[:layout])

    # Make all paths relative, on disk paths...
    html_string.gsub!(".com:/",".com/") # strip out bad attachment_fu URLs
    html_string.gsub!( /src=["'\/]+([^:]+?)["']/i ) { |m| "src=\"#{Rails.public_path}/" + $1 + '"' } # re-route absolute paths

    # Remove asset ids on images with a regex
    html_string.gsub!( /src=["'](\S+\?\d*)["']/i ) { |m| 'src="' + $1.split('?').first + '"' }

    # Send the generated PDF file from our html string.
    if filename = options[:filename] || options[:file]
      result = prince.pdf_from_string_to_file(html_string, filename)
    else
      result = prince.pdf_from_string(html_string)
    end
    @transformed_stylesheets.each {|file| file.unlink }
    result
  end

  def make_and_send_pdf(pdf_name, options = {})
    send_data(
      make_pdf(options),
      :filename => pdf_name + ".pdf",
      :type => 'application/pdf',
      :disposition => 'inline'
    )
  end

  def stylesheet_file_path(stylesheet)
    stylesheet     = stylesheet.to_s.gsub(".css","")
    stylesheet_dir = Rails.public_path
    stylesheet     = File.join(stylesheet_dir, "#{stylesheet}.css")
    transform_paths(stylesheet).path
  end

  # Make all relative paths to absolute in stylesheet fil
  def transform_paths(stylesheet)
    content = File.open(stylesheet, 'r').read
    stylesheet_dir = File.dirname(stylesheet)

    content.gsub!(/url\(['"]?([^'"\)]+)['"]?\)/) do |m|
      url = $1.gsub(/\?\d+\z/, '')

      if url.first == '/'
        "url(#{Rails.public_path}#{url})"
      elsif url =~ /\Ahttp/
        "url(#{url})"
      else
        "url(#{stylesheet_dir}/#{url})"
      end
    end

    transformed_stylesheet = Tempfile.new(File.basename(stylesheet))

    transformed_stylesheet.write(content)
    transformed_stylesheet.close
    @transformed_stylesheets << transformed_stylesheet

    transformed_stylesheet
  end
end
