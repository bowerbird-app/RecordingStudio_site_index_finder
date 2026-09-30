# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    module Text
      UTF8_BOM = "\xEF\xBB\xBF".b

      module_function

      def utf8(value)
        text = value.to_s.dup.force_encoding(Encoding::BINARY)
        text.delete_prefix!(UTF8_BOM)
        text.force_encoding(Encoding::UTF_8)
        text.scrub!
        text
      end
    end
  end
end
