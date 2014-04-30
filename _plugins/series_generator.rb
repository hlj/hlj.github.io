module Jekyll

  class Series < Generator

    safe true

    def generate(site)
      series = {}
      site.posts.each do |post|
        if post.data["series"]
          if series[post.data["series"]]
            series[post.data["series"]] << post
          else
            series[post.data["series"]] = [post]
          end
        end
      end

      build_series_page(site, series)

      build_subpages(site, series)
    end

    def build_series_page(site, series)
      newpage = SeriesPage.new(site, site.source, 'series', 'post', series.map { |k,v| [k, v.count] })
      site.pages << newpage
    end

    def build_subpages(site, series)
      series.each_pair do |name, posts|
        path = "/series/#{name}"
        newpage = SeriesSubPage.new(site, site.source, path, 'post', name, posts)
        site.pages << newpage
      end

    end

  class SeriesPage < Page
    def initialize(site, base, dir, type, series)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), "series.html")
      self.data["series"] = series
    end
  end

  class SeriesSubPage < Page
    def initialize(site, base, dir, type, val, posts)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), "series_index.html")
      self.data["posts"] = posts
      self.data["name"] = val
    end
  end
end

end
