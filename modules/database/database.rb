class Database
  attr_accessor :database, :services
  def initialize
    @database = Sequel.connect('sqlite://database.db')

    #Installing databases
    unless @database.table_exists?(:services)
      Console.show 'Creating database...', 'info'
      @database.create_table :services do
        primary_key :id
        String :folder_name
        String :start_command
        String :service_name
        String :service_type
        String :pid_file
        String :version
      end

      @database.create_table :monitors do
        primary_key :id
        String :ram_usage
        String :cpu_usage
        Date :date
        Integet :service_id
      end
    end


    #Set tables
    self.services=@database[:services]
  end
end
