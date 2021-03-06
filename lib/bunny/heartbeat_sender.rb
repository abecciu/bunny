require "thread"
require "amq/protocol/client"
require "amq/protocol/frame"

module Bunny
  class HeartbeatSender

    #
    # API
    #

    def initialize(transport)
      @transport = transport
      @mutex     = Mutex.new

      @last_activity_time = Time.now
    end

    def start(period = 30)
      @mutex.synchronize do
        # calculate interval as half the given period plus
        # some compensation for Ruby's implementation inaccuracy
        # (we cannot get at the nanos level the Java client uses, and
        # our approach is simplistic). MK.
        @interval = [(period / 2) - 1, 0.4].max

        @thread = Thread.new(&method(:run))
      end
    end

    def stop
      @mutex.synchronize { @thread.exit }
    end

    def signal_activity!
      @last_activity_time = Time.now
    end

    protected

    def run
      begin
        loop do
          self.beat

          sleep @interval
        end
      rescue IOError => ioe
        puts ioe.message
        stop
      rescue Exception => e
        puts e.message
        stop
      end
    end

    def beat
      now = Time.now

      if now > (@last_activity_time + @interval)
        @transport.send_raw(AMQ::Protocol::HeartbeatFrame.encode)
      end
    end
  end
end
