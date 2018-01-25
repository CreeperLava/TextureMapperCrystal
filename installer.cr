require "http/client"
require "http/headers"
require "sqlite3"
require "csv"

class Initializer
  def initialize
    @dupes_db = SQLite3::Database.new "database.db"
    @full_db = SQLite3::Database.new "full.db"
    modified = update_texture_map?
    @texture_map = "Texture_Map.csv"
    @texture_csv = File.open(@texture_map)

    if internet?
      if File.file? "database.db"
        update_db if modified
      else
        create_db
      end
    end
  end

  def internet?
    begin
      HTTP::Client.head("https://google.com")
      return true
    rescue HTTP::Error
      return false
    end
  end

  def update_texture_map?
    last_modified_time = File.open(@texture_map).stat.mtime.to_s("%FT%TZ")
      
    # check if texture map has been modified
    HTTP::Client.get("https://api.github.com/repos/CreeperLava/TextureMapperCrystal/commits?path=#{texture_map}&since=#{last_modified_time}") do |response|
      # if yes, download the new and replace the original
      if response.body_io != [] of ElementType
        HTTP::Client.get("https://raw.githubusercontent.com/CreeperLava/TextureMapperCrystal/master/Texture_Map.csv") do |response|
          File.write(@texture_map, response.body_io)
          return true
        end
      end
      return false
    end
  end

  def create_db
    @dupes_db.execute <<-SQL
      create table textures (
        groupid INTEGER,
        game INTEGER,
        crc TEXT,
        name TEXT,
        size_x INTEGER,
        size_y INTEGER,
        format TEXT,
        grade INTEGER,
        PRIMARY KEY(groupid, game, crc)
      );
    SQL

    CSV.each_row(@texture_csv) do |row|
      @dupes_db.execute("insert into textures values ( ?, ?, ?, ?, ?, ?, ?, ? )", row[0..7])
    end
    @dupes_db.execute("vacuum")
  end


  def update_db

    CSV.each_row(@texture_csv) do |row|
      @dupes_db.execute("insert into textures values ( ?, ?, ?, ?, ?, ?, ?, ? )", row[0..7]) unless # add lines to database
          @dupes_db.execute("select * from textures where groupid=#{row[0]} and game=#{row[1]} and crc=#{row[2]} limit 1").empty? # unless they're already present
    end
    @dupes_db.execute("vacuum")
  end
end

Initializer.new