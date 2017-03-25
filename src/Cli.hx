import js.node.ChildProcess;

using StringTools;

class Cli implements Async
{
    static function help() {
        Sys.println("Nodehost available commands:");
        Sys.println("  setup");
        Sys.println("  status");
        Sys.println("  install <hostname>");
        Sys.println("  remove <hostname>");
        Sys.exit(1);
    }

    static function main() {
        var args = Sys.args();
        if(args.length == 0) help();

        var params = args.slice(1);

        switch args[0].trim() {
            case 'help' | '-h' | '--help': help();
            case 'setup':
                var username = ChildProcess.execSync("whoami", {encoding: 'utf-8'}).trim();
                var cwd = ChildProcess.execSync("pwd", {encoding: 'utf-8'}).trim();
                
                var appData = new Nodehost.AppData({
                    app: 'nodehost',
                    username: username,
                    basepath: haxe.io.Path.join([cwd, 'nodehost'])
                });

                new Nodehost(appData).setup();
        }
    }
}