require "./router"

class MainRouter < Router
  def initialize
    get "/login" do |env|
      base_url = Config.current.base_url
      render "src/views/login.html.ecr"
    end

    get "/logout" do |env|
      begin
        env.session.delete_string "token"
      rescue e
        @context.error "Error when attempting to log out: #{e}"
      ensure
        redirect env, "/login"
      end
    end

    post "/login" do |env|
      begin
        username = env.params.body["username"]
        password = env.params.body["password"]
        token = @context.storage.verify_user(username, password).not_nil!

        env.session.string "token", token

        callback = env.session.string? "callback"
        if callback
          env.session.delete_string "callback"
          redirect env, callback
        else
          redirect env, "/"
        end
      rescue
        redirect env, "/login"
      end
    end

    get "/library" do |env|
      begin
        username = get_username env

        sort_opt = SortOptions.from_info_json @context.library.dir, username
        get_sort_opt

        titles = @context.library.sorted_titles username, sort_opt
        percentage = titles.map &.load_percentage username

        layout "library"
      rescue e
        @context.error e
        env.response.status_code = 500
      end
    end

    get "/book/:title" do |env|
      begin
        title = (@context.library.get_title env.params.url["title"]).not_nil!
        username = get_username env

        sort_opt = SortOptions.from_info_json title.dir, username
        get_sort_opt

        entries = title.sorted_entries username, sort_opt

        percentage = title.load_percentage_for_all_entries username, sort_opt
        title_percentage = title.titles.map &.load_percentage username
        layout "title"
      rescue e
        @context.error e
        env.response.status_code = 500
      end
    end

    get "/download" do |env|
      mangadex_base_url = Config.current.mangadex["base_url"]
      layout "download"
    end

    get "/download/plugins" do |env|
      begin
        id = env.params.query["plugin"]?
        plugins = Plugin.list
        plugin = nil

        if id
          plugin = Plugin.new id
        elsif !plugins.empty?
          plugin = Plugin.new plugins[0][:id]
        end

        layout "plugin-download"
      rescue e
        @context.error e
        env.response.status_code = 500
      end
    end

    get "/" do |env|
      begin
        username = get_username env
        continue_reading = @context
          .library.get_continue_reading_entries username
        recently_added = @context.library.get_recently_added_entries username
        start_reading = @context.library.get_start_reading_titles username
        titles = @context.library.titles
        new_user = !titles.any? { |t| t.load_percentage(username) > 0 }
        empty_library = titles.size == 0
        layout "home"
      rescue e
        @context.error e
        env.response.status_code = 500
      end
    end

    get "/api" do |env|
      render "src/views/api.html.ecr"
    end
  end
end
