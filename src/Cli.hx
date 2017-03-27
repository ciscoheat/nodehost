import js.node.ChildProcess;
import Nodehost.Protocols;

using StringTools;
using Lambda;

class Cli implements Async
{
    static var appName(default, never) = 'nodehost';
    static var startPort(default, never) = 14400;

    static function help() {
        Sys.println("Nodehost available commands:");
        Sys.println("  setup <directory> <username> [startport] [--install-dependencies]");
        Sys.println("  list");
        Sys.println("  create <hostname> [--no-https] [--no-http] [--separate-user]");
        Sys.println("  enable <hostname>");
        Sys.println("  disable <hostname>");
        Sys.println("  remove <hostname> [--including-dir]");
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
            case 'setup' if(params.length >= 2):
                var installDeps = params.has('--install-dependencies');
                params.remove("--install-dependencies");

                if(params.length < 2) help();

                var basepath = params[0];
                var username = params[1];
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
                for(h in hosts) {
                    Sys.println(h.host + " " + h.port + " " + h.path + " " + (h.enabled ? "[Enabled]" : ""));
                }

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

            case 'enable' if(params.length == 1):
                Nodehost.fromConfig(appName).enable(params[0], exit);

            case 'disable' if(params.length == 1):
                Nodehost.fromConfig(appName).disable(params[0], exit);

            case _:
                help();
        }
    }

    static function exit(err : js.Error) {
        if(err != null) Sys.println(err.message);
        Sys.exit(err != null ? 1 : 0);
    }
}