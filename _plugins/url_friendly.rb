module Jekyll
  module UrlFriendly
    def url_friendly(str)
      return str.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    end
  end
end

Liquid::Template.register_filter(Jekyll::UrlFriendly)