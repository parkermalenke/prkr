module Jekyll
  module BaseDomain
    def base_domain(url)
      return url.sub(%r{([a-z]+://)?([^/]*)(/.*$)?}i, '\\2')
    end
  end
end

Liquid::Template.register_filter(Jekyll::BaseDomain)