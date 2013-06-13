require 'flickraw'

module Jekyll

	class GeneratePhotosets < Generator

		safe true
		priority :low


		def generate(site)
			generate_photosets(site) if (site.config['flickr']['enabled'])
		end


		def generate_photosets(site)
			site.posts.each do |post|
				post.data['photos'] = load_photos(post.data['photoset'], site) if post.data['photoset']
			end
		end


		def load_photos(photoset, site)
			if cache_dir = site.config['flickr']['cache_dir']
				path = File.join(cache_dir, "#{Digest::MD5.hexdigest(photoset.to_s)}.yml")
				if File.exists?(path)
					photos = YAML::load(File.read(path))
				else
					photos = generate_photo_data(photoset, site)
					File.open(path, 'w') { |f| f.print(YAML::dump(photos)) }
				end
			else
				photos = generate_photo_data(photoset, site)
			end

			photos
		end


		def generate_photo_data(photoset, site)
			return_set = Array.new

			FlickRaw.api_key = site.config['flickr']['api_key']
			FlickRaw.shared_secret = site.config['flickr']['shared_secret']

			photos = flickr.photosets.getPhotos :photoset_id => photoset, :extras => 'url_m, url_h, url_k'

			photos.photo.each do |p|
				title = p.title
				id = p.id
				url_t = p.url_m[0..-5] + '_t.jpg'
				url_m = p.url_m[0..-5] + '_m.jpg'
				url = p.url_m
				url_c = p.url_m[0..-5] + '_c.jpg'
				url_b = p.url_m[0..-5] + '_b.jpg'
				if defined? p.url_h
					url_h = p.url_h
				else
					url_h = url_b
				end
				if defined? p.url_k
					url_k = p.url_k
				else
					url_k = url_b
				end

				photo = FlickrPhoto.new(title, id, url_t, url_m, url, url_c, url_b, url_h, url_k)
				return_set.push photo
			end

			sleep 1

			return_set
		end


	end

	class FlickrPhoto

		attr_accessor(:title, :id, :url_t, :url_m, :url, :url_c, :url_b, :url_h, :url_k)

		def initialize(title, id, url_t, url_m, url, url_c, url_b, url_h, url_k)
			@title = title
			@id = id
			@url_t = url_t
			@url_m = url_m
			@url   = url
			@url_c = url_c
			@url_b = url_b
			@url_h = url_h
			@url_k = url_k
		end


		def to_liquid
			{
				'title' => title,
				'id' => id,
				'url_t' => url_t,
				'url_m' => url_m,
				'url' => url,
				'url_c' => url_c,
				'url_b' => url_b,
				'url_h' => url_h,
				'url_k' => url_k
			}
		end

	end

end