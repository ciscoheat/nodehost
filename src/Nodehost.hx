import js.node.ChildProcess;
import Sys.println;
import Sys.print;
import Sys.exit;

using StringTools;
using Lambda;

class Nodehost implements Async
{
    var appData : AppData;

    public function new(appData) {
        this.appData = appData;
    }

    public function setup() {
        // Check dependencies
        
        // Nginx
        var err, stdout, stderr = @async ChildProcess.exec("nginx -v", {encoding: 'utf-8'});
        if(err != null) throw err;
        if(!stderr.startsWith("nginx")) {
            println("Nginx not found. Can be installed with:");
            println("add-apt-repository ppa:nginx/stable && apt-get update && apt-get install -y nginx");
            exit(1);
        }

        // letsencrypt
        var err, stdout, stderr = @async ChildProcess.exec("letsencrypt --version", {encoding: 'utf-8'});
        if(err != null) throw err;
        if(!stderr.startsWith("letsencrypt")) {
            println("letsencrypt not found. Can be installed with:");
            println("apt-get install -y letsencrypt");
            exit(1);
        }

        var response = '';
        while(!['y', 'n'].has(response)) {
            print('Setup ${appData.app} for user ${appData.username} in directory "${appData.basepath}"? (y/n) ');
            response = Sys.stdin().readLine().toLowerCase();
        }
        if(response == 'n') exit(1);

        // Setup
        var commands = [
            'addgroup ${appData.app}',
            'gpasswd -a ${appData.username} ${appData.app}',
            'mkdir -p ${appData.basepath}',
            'chown ${appData.username}:${appData.app} ${appData.basepath}'
        ];

        var status = 0;

        for(cmd in commands) {
            try ChildProcess.execSync(cmd)
            catch(e : js.Error) status = 1;
        }

        exit(status);
    }

    static function exit(code = 1) Sys.exit(code);
}

@immutable class AppData implements DataClass
{
    @validate(~/\w+/) public var app : String;
    @validate(~/\w+/) public var username : String;
    @validate(_.length > 0) public var basepath : String;
}

@immutable class HostData implements DataClass
{
    @validate(~/\w+\d+/) public var id : String;
    @validate(_.length > 1) public var path : String;
    @validate(_.length > 1) public var host : String;

    public static function fromAppData(appData : AppData, host : String, port : Int) {
        return new HostData({
            id: appData.app + port,
            path: haxe.io.Path.join([appData.basepath, appData.app + port]),
            host: host
        });
    }
}