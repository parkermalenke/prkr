module Jekyll
	class Category_pager < Generator


		def generate(site)
			site.categories.each do |category|
				build_subpages(site, category)
			end
		end


		def build_subpages(site, posts)
			posts[1] = posts[1].sort_by { |p| -p.date.to_f }
			paginate(site, posts)
		end


		def paginate(site, posts)
			pages = Pager.calculate_pages(posts[1], site.config['paginate'].to_i)
			(1..pages).each do |num_page|
				pager = Pager.new(site.config, num_page, posts[1], pages)
				path = "/#{posts[0]}"
				if num_page > 1
					path = path + "/page#{num_page}"
				end
				newpage = GroupSubPage.new(site, site.source, path, posts[0])
				newpage.pager = pager
				site.pages << newpage
			end
		end


		class GroupSubPage < Page


			def initialize(site, base, dir, val)
				@site = site
				@base = base
				@dir = dir
				@name = 'index.html'

				self.process(@name)
				self.read_yaml(File.join(base, '_layouts'), "#{val}-paged.html")
				self.data['title'] = val.capitalize
			end


		end


	end
end