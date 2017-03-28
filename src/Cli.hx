import js.node.ChildProcess;
import Nodehost.Protocols;

using StringTools;
using Lambda;
using Colors;

class Cli implements Async
{
    static var appName(default, never) = 'nodehost';
    static var startPort(default, never) = 14400;

    static function help() { Sys.println("
Usage: nodehost <command> [options...]

Commands:

  setup <directory> <username> [startport] [--install-dependencies]
  create <hostname> [--no-https] [--no-http] [--separate-user]

  list

  status <hostname>
  start <hostname>
  stop <hostname>
  restart <hostname>
  edit-nginx <hostname> [--restart]
  remove <hostname> [--including-dir]  

        ".trim() + "\n");
        Sys.exit(1);
    }

    static function main() {
        try start()
        catch(e : js.Error) exit(e)
        catch(e : String) exit(new js.Error(e));
    }

    static function start() {
        var args = Sys.args();
        if(args.length == 0) help();

        var params = args.slice(1);

        switch args[0].trim() {
            case 'setup' if(params.length >= 1):
                var installDeps = params.has('--install-dependencies');
                params.remove("--install-dependencies");

                if(params.length == 0) help();

                var basepath = params[0];
                var username = if(params.length > 1) params[1] else ChildProcess.execSync("whoami", {encoding: 'utf-8'}).trim();
                var startport = if(params.length > 2) Std.parseInt(params[2]) else startPort;

                var appData = new Nodehost.AppData({
                    app: appName,
                    username: username,
                    basepath: basepath,
                    startport: startport
                });

                new Nodehost(appData).setup(installDeps, exit);

            case 'list' if(params.length == 0):
                var err, hosts = @async(err => exit) Nodehost.fromConfig(appName).list();
                var output = [['Host name', "Port", "Status", "Path"]];

                for(h in hosts) {
                    output.push([h.host, Std.string(h.port), (h.enabled ? "running" : "stopped"), h.path]);
                }

                var max = [];
                for(x in 0...output[0].length) {
                    max[x] = 0;
                    for(y in 0...output.length) {
                        var str = output[y][x];
                        max[x] = Std.int(Math.max(max[x], str.length));
                    }
                }

                var sep = " | ".dim();

                Sys.println("");
                for(y in 0...output.length) {
                    Sys.println(sep + output[y].mapi(function(x, str) {
                        str = str.rpad(" ", max[x]);
                        // Add some colors
                        return if(y > 0) switch x {
                            case 0: str.bold();
                            case 2: str == "running" ? str.green() : str.red();
                            case _: str;
                        } else {
                            str.yellow();
                        }
                    }).join(sep) + sep);
                }
                Sys.println("");

            case 'create' if(params.length >= 1):
                var args = params.slice(1);
                var separateUser = args.has('--separate-user');
                var protocols = new haxe.EnumFlags<Nodehost.Protocols>();
                if(!args.has('--no-https')) protocols.set(Https);
                if(!args.has('--no-http')) protocols.set(Http);

                Nodehost.fromConfig(appName).create(params[0], protocols, separateUser, exit);

            case 'remove' if(params.length >= 1):
                var includingDir = params.length > 1 && params[1] == '--including-dir';
                Nodehost.fromConfig(appName).remove(params[0], includingDir, exit);

            case 'start' if(params.length == 1):
                Nodehost.fromConfig(appName).start(params[0], exit);

            case 'stop' if(params.length == 1):
                Nodehost.fromConfig(appName).stop(params[0], exit);

            case 'restart' if(params.length == 1):
                Nodehost.fromConfig(appName).restart(params[0], exit);

            case 'status' if(params.length >= 1):
                Nodehost.fromConfig(appName).status(params[0], params.slice(1), exit);

            case 'edit-nginx' if(params.length >= 1):
                var restart = params.has("--restart");
                Nodehost.fromConfig(appName).editNginx(params[0], restart, exit);
            
            case _:
                help();
        }
    }

    static function exit(err : js.Error) {
        if(err != null) Sys.println(err.message);
        Sys.exit(err != null ? 1 : 0);
    }
}