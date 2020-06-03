require "./router"

class MainRouter < Router
  def setup
    get "/login" do |env|
      render "src/views/login.ecr"
    end

    get "/logout" do |env|
      begin
        cookie = env.request.cookies.find { |c| c.name == "token" }.not_nil!
        @context.storage.logout cookie.value
      rescue e
        @context.error "Error when attempting to log out: #{e}"
      ensure
        env.redirect "/login"
      end
    end

    post "/login" do |env|
      begin
        username = env.params.body["username"]
        password = env.params.body["password"]
        token = @context.storage.verify_user(username, password).not_nil!

        cookie = HTTP::Cookie.new "token", token
        cookie.expires = Time.local.shift years: 1
        env.response.cookies << cookie
        env.redirect "/"
      rescue
        env.redirect "/login"
      end
    end

    get "/library" do |env|
      begin
        titles = @context.library.titles
        username = get_username env
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
        percentage = title.entries.map { |e|
          title.load_percentage username, e.title
        }
        layout "title"
      rescue e
        @context.error e
        env.response.status_code = 404
      end
    end

    get "/download" do |env|
      base_url = @context.config.mangadex["base_url"]
      layout "download"
    end

    get "/" do |env|
      begin
        username = get_username env
        continue_reading = @context.library.get_continue_reading_entries username

        layout "home"
      rescue e
        @context.error e
        env.response.status_code = 500
      end
    end
  end
end
