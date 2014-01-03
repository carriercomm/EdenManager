#Contains system calls for the monitor
module ServiceSystem
  module System
    def daemonize(cmd, service, options = {})
      child_socket, parent_socket = Socket.pair(:UNIX, :STREAM, 0) # used to send message to the process
      rd, wr = IO.pipe # used to send the pid
      p1 = Process.fork { #start a new process by forking the parent
        set_user(options[:username])
        threads = []
        Dir.chdir(ENV["PWD"] = options[:working_dir].to_s) if options[:working_dir] #teleport to the install folder
        stdin, stdout, stderr, wait_thr = Open3.popen3(*Shellwords.shellwords(cmd))
        parent_socket.close
        rd.close
        wr.write wait_thr[:pid]
        wr.close
        handle_input(stdin, wait_thr, child_socket, threads) #handle app's stdin and packets
        handle_output(stdout, stderr, service, wait_thr, threads) #handle app's stdout/stderr
        threads.map(&:join)
        exit
      }
      Process.detach(p1) # divorce p1 from parent process (shell)
      child_socket.close
      wr.close
      daemon_id = rd.read.to_i
      rd.close
      pidfile = File.new(options[:pid_file], 'w')
      pidfile.chmod(0777) #Setting it so every users can see it. TODO: set it readable only to the user that run the service
      pidfile.puts "#{daemon_id}"
      pidfile.close
      service.socket = parent_socket #used to communicate with the child process
      daemon_id
    end

    def handle_input(stdin, wait_thr, child_socket, threads)
      threads << Thread.new {
        while wait_thr.status
          if child_socket.ready?
            header = child_socket.read(8).unpack('LL')
            length = header[0]
            packet = header[1]
            case packet
              when 1
                stdin.write(child_socket.read(length))
              when 2
                #send console
              else
                Console.show "Unknown packet : #{packet}"
            end
          end
          sleep 1
        end
      }
    end

    def handle_output (stdout,stderr,service,wait_thr,threads)
      threads << Thread.new {  #handle stdout
        while wait_thr.status
          if stdout.ready?
            begin
              pidfile = File.new("../../../#{service.service[:pid_file]}", 'a')
              pidfile.puts "#{stdout.gets}"
              pidfile.close
            rescue => e
              Console.show e, 'error'
            end
          end
          sleep 1
        end
      }

      threads << Thread.new { #handle stderr
        while wait_thr.status
          begin
            pidfile = File.new("../../../#{service.service[:pid_file]}", 'a')
            pidfile.puts "#{stderr.gets}"
            pidfile.close
          rescue => e
            Console.show e, 'error'
          end
          sleep 1
        end
      }
    end

    #Launch the program as a specific User.
    def set_user(uid)
      if ::Process::Sys.geteuid == 0
        uid_num = Etc.getpwnam(uid).uid if uid
        ::Process::Sys.setuid(uid_num) if uid
      end
    end
  end
end
