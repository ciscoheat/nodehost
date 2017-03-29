@:enum abstract Level(Int) to Int {
    var Debug = 7;
    var Info = 6;
    var Notice = 5;
    var Warning = 4;
    var Error = 3;
    var Critical = 2;
    var Alert = 1;
    var Emergency = 0;
}

class Papertrail
{
    var host : String;
    var port : Int;
    var program : String;

    public function new(papertrailHost : String, port : Int, programName : String) {
        this.host = papertrailHost;
        this.port = port;
        this.program = programName;
    }

    public function send(msg : Dynamic, level : Level) {
        // user level 1 * 8 + level
        var priority = level + 8;
        var hostname = js.node.Os.hostname();
        var date = untyped __js__('new Date().toISOString()');
        var socket : Dynamic = js.node.Dgram.createSocket('udp4');

        var messages = [for(line in Std.string(msg).split('\n')) {
            js.node.Buffer.from('<$priority>1 $date $hostname $program - - - ${level2Ansi(level)} $msg');
        }];

        socket.send(messages, port, host, function(err) socket.close());
    }

    public function debug(msg : Dynamic) send(msg, Debug);
    public function info(msg : Dynamic) send(msg, Info);
    public function warning(msg : Dynamic) send(msg, Warning);
    public function error(msg : Dynamic) send(msg, Error);

    static function level2Ansi(level : Level) return switch level {
        case Debug: "\033[34m" + "debug" + "\033[0m";
        case Info: "\033[32m" + "info" + "\033[0m";    
        case Notice: "\033[32m" + "notice" + "\033[0m";    
        case Warning: "\033[33m" + "warning" + "\033[0m";  
        case Error: "\033[31m" + "error" + "\033[0m";    
        case Critical: "\033[31;1m" + "CRIT" + "\033[0m";
        case Alert: "\033[31;1m" + "ALERT" + "\033[0m";
        case Emergency: "\033[31;1m" + "EMERG" + "\033[0m";
    }
}
