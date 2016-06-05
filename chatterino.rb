require 'em-websocket'
require 'json'

class Chat
  def initialize
    @channels = Hash.new { |hash, key| hash[key] = EM::Channel.new }
    @online = Hash.new { |hash, key| hash[key] = [] }
  end

  def method_missing(_m, *_args)
    puts 'Invalid method called'
  end

  def get_chans(ws)
    ws.send(@channels.keys.to_json)
  end

  def get_online(ws, cname)
    ws.send(@online[cname][:list].to_json) if @online[cname]
  end

  def new_chan(ws, cname, user)
    @channels[cname] = EM::Channel.new
    @online[cname] = []
    subscribe(ws, cname, user)
  end

  def subscribe(ws, cname, user)
    sid = @channels[cname].subscribe { |m| ws.send(m) }
    @online[cname] << {user: user, sid: sid}
    msg = {author: cname, msg: "#{user} joined the chat"}.to_json
    @channels[cname].push msg
  end

  def send_msg(ws, cname, user, *words)
    unless @channels[cname]
      ws.send({author: 'server', msg: 'Invalid channel'}.to_json)
      return
    end
    str = ''
    words.map { |w| str += "#{w} " }
    m = {author: user, msg: str}.to_json
    @channels[cname].push m
  end

  def unsubscribe(ws, cname, user)
    return unless @channels[cname]
    users = @online[cname].select{ |elem| elem[:user] == user }
    users.each {|elem| @channels[cname].unsubscribe elem[:sid] }
    ws.send({author: 'server', msg: 'Goodbye'}.to_json)
  end
end

@chat = Chat.new

EventMachine.run do
  EventMachine::WebSocket.start(host: '0.0.0.0', port: 8081) do |ws|
    ws.onopen { |handshake| puts "#{handshake} connected" }
    ws.onmessage do |msg|
      tokens = msg.split
      @chat.send(tokens.shift, ws, *tokens)
    end
  end
end
