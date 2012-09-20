require 'princely/pdf_helper'

Mime::Type.register 'application/pdf', :pdf

if !defined?(PDF_GENERATOR) || PDF_GENERATOR == :PRINCE_XML
  ActionController::Base.send(:include, PdfHelper)
end
