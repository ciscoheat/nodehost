import js.node.ChildProcess;
import Sys.println;
import Sys.print;
import Sys.exit;
import js.Error;
import sys.FileSystem.exists;
import haxe.io.Path;
import sys.io.File;

using StringTools;
using Lambda;
using dataclass.JsonConverter;

class Nodehost implements Async
{
    var config : AppData;

    static function configFile(app : String) return '/etc/nginx/' + app + ".conf.json";

    public static function fromConfig(app : String) {
        if(!exists(configFile(app)))
            throw 'Configuration file ' + configFile(app) + " doesn't exist.";

        return new Nodehost(AppData.fromJson(haxe.Json.parse(File.getContent(configFile(app)))));
    }

    public function new(config) {
        this.config = config;
    }

    public function checkDependencies(cb : Error -> Void) {
        // nodemon
        var err, stdout, stderr : String = @async(err => cb) ChildProcess.exec("nodemon -v", {encoding: 'utf-8'});
        if(!~/\d+\./.match(stdout)) {
            var error = "nodemon not found. Can be installed with:\n" +
            "npm install -g nodemon";

            return cb(new Error(error));
        }

        // Nginx
        var err, stdout, stderr = @async(err => cb) ChildProcess.exec("nginx -v", {encoding: 'utf-8'});
        if(!stderr.startsWith("nginx")) {
            var error = "Nginx not found. Can be installed with:\n" +
            "add-apt-repository ppa:nginx/stable && apt-get update && apt-get install -y nginx";

            return cb(new Error(error));
        }

        // letsencrypt
        var err, stdout, stderr = @async(err => cb) ChildProcess.exec("letsencrypt --version", {encoding: 'utf-8'});
        if(!stderr.startsWith("letsencrypt")) {
            var error = "letsencrypt not found. Can be installed with:\n" +
            "apt-get install -y letsencrypt";

            return cb(new Error(error));
        }

        cb(null);
    }

    public function setup(cb : Error -> Void) {
        var err = @async(err => cb) checkDependencies();

        if(exists(configFile(config.app))) {
            return cb(new Error('Configuration file ${configFile(config.app)} already exists.'));
        }

        if(!ask('Setup ${config.app} for user "${config.username}" in directory "${config.basepath}"?')) {
            return cb(new Error("User interrupt."));
        }

        // Setup
        var err = exec([
            'getent group ${config.app} || addgroup ${config.app}',
            'gpasswd -a ${config.username} ${config.app}',
            'mkdir -p ${config.basepath}',
            'chown ${config.username}:${config.app} ${config.basepath}'
        ]);
        if(err != null) return cb(err);

        try {
            var json = haxe.Json.stringify(config.toJson(), "    ");
            File.saveContent(configFile(config.app), json);
        } catch(e : Dynamic) {
            return cb(new Error(Std.string(e)));
        }

        cb(null);
    }

    public function list(cb : Error -> Array<HostData> -> Void) {
        try {
            var enabled = Glob.sync('/etc/nginx/sites-enabled/${config.app}+([0-9]).conf').map(function(file) 
                return new Path(file).file
            );

            var hosts = Glob.sync('/etc/nginx/sites-available/${config.app}+([0-9]).conf').map(function(file) {
                var filename = new Path(file);
                var content = File.getContent(file);
                var id = filename.file;
                
                var portReg = ~/\d+$/;
                if(!portReg.match(id)) {
                    throw new Error("Invalid configuration file: " + id + "." + filename.ext);
                }
                var port = Std.parseInt(portReg.matched(0));

                var hostReg = ~/\bserver_name\s+([\S]+)/;
                if(!hostReg.match(content)) {
                    throw new Error("server_name not found in configuration file: " + id + "." + filename.ext);
                }
                var host = hostReg.matched(1);

                return new HostData({
                    id: id,
                    path: Path.join([config.basepath, id]),
                    host: host,
                    port: port,
                    enabled: enabled.has(id),
                    user: config.username
                });
            });
            cb(null, hosts);
        } catch(err : Error) {
            cb(err, null);
        }
    }

    public function create(hostname : String, ssl : Bool, cb : Error -> Void) {
        var err, hosts = @async(err => cb) list();
        var hostExists = hosts.find(function(host) return host.host == hostname);

        if(hostExists != null)
            return cb(new Error('Host "$hostname" already exists (${hostExists.id})'));

        var nextPort = hosts.fold(function(host, port : Int) 
            return Std.int(Math.max(host.port, port)), config.startport-1) + 1;

        var id = config.app + nextPort;

        var hostData = new HostData({
            id: id,
            path: Path.join([config.basepath, hostname]),
            host: hostname,
            port: nextPort,
            enabled: false,
            user: config.username
        });

        // Render templates
        function template(name : String) 
            return Path.join([js.Node.__dirname, 'templates', name]);

        var systemd = render(template('systemd.conf'), hostData);
        var location = render(template('nginx.location.conf'), hostData);
        var http = render(template('nginx.http.conf'), {LOCATION: location});
        var https = render(template('nginx.https.conf'), {LOCATION: location, host: hostData.host});
        var startup = render(template('startup.sh'), hostData);
        var app = render(template('app.js'), hostData);

        File.saveContent(Path.join(['/etc/systemd/system', hostData.id + ".service"]), systemd);
        File.saveContent(Path.join(['/etc/nginx/sites-available', hostData.id + ".conf"]), http);
        if(ssl) File.saveContent(Path.join(['/etc/nginx/sites-available', hostData.id + ".ssl.conf"]), https);

        var error = exec([
            'adduser --no-create-home --system ${hostData.id}',
            'mkdir -p ' + Path.join([hostData.path, 'www', 'public']),
            'chown ${hostData.id}:${config.app} ${hostData.path} -R'
        ]);
        if(error != null) return cb(error);

        // Add default app.js
        var appFile = Path.join([hostData.path, 'www', 'app.js']);
        if(!exists(appFile)) File.saveContent(appFile, app);

        // Add service start file
        var serviceFile = Path.join([hostData.path, hostData.host]);
        if(!exists(serviceFile)) File.saveContent(serviceFile, startup);

        // Enable service
        enable(hostname, cb);
    }

    public function enable(hostname : String, cb : Error -> Void) {
        var err, hostData = @async(err => cb) getHost(hostname);

        if(hostData.enabled)
            return cb(new Error('$hostname is already enabled.'));

        var src = Path.join(['/etc/nginx/sites-available', hostData.id + '.conf']);
        var srcSsl = Path.join(['/etc/nginx/sites-available', hostData.id + '.ssl.conf']);

        var execute = [
            'ln -s $src ' + src.replace('/sites-available/', '/sites-enabled/')
        ];

        if(exists(srcSsl))
            execute.push('ln -s $srcSsl ' + srcSsl.replace('/sites-available/', '/sites-enabled/'));

        execute.push('/etc/init.d/nginx reload');
        execute.push('systemctl enable ' + hostData.id);
        execute.push('systemctl start ' + hostData.id);

        cb(exec(execute));
    }

    public function remove(hostname : String, includingWWW : Bool, cb : Error -> Void) {
        var err, hostData = @async(err => cb) getHost(hostname);

        exec([
            'systemctl stop ' + hostData.id,
            'systemctl disable ' + hostData.id,
            'deluser ' + hostData.id
        ]);

        try sys.FileSystem.deleteFile(Path.join(['/etc/systemd/system', hostData.id + ".service"])) catch(e : Dynamic) {};
        try sys.FileSystem.deleteFile(Path.join(['/etc/nginx/sites-enabled', hostData.id + ".conf"])) catch(e : Dynamic) {};
        try sys.FileSystem.deleteFile(Path.join(['/etc/nginx/sites-enabled', hostData.id + ".ssl.conf"])) catch(e : Dynamic) {};
        try sys.FileSystem.deleteFile(Path.join(['/etc/nginx/sites-available', hostData.id + ".conf"])) catch(e : Dynamic) {};
        try sys.FileSystem.deleteFile(Path.join(['/etc/nginx/sites-available', hostData.id + ".ssl.conf"])) catch(e : Dynamic) {};

        if(includingWWW) trace(hostData.path);
            //exec(['rm -rf ' + hostData.path]);

        cb(null);
    }

    function getHost(hostname : String, cb : Error -> HostData -> Void) : Void {
        var err, hosts = @async(err, null => cb) list();
        var hostData = hosts.find(function(host) return host.host == hostname);
        var error = hostData == null ? new Error('Host "$hostname" doesn\'t exist.') : null;

        cb(error, hostData);
    }

    ///////////////////////////////////////////////////////////////////////////

    static function render(file : String, vars : Dynamic) {
        var content = File.getContent(file);
        var search = ~/([^\\])\$\{(\w+)\}/;
        var output = new StringBuf();

        while(search.match(content)) {
            var replaceVar = search.matched(2);
            if(!Reflect.hasField(vars, replaceVar))
                throw 'Variable not found for $file: $replaceVar';

            output.add(search.matchedLeft() + search.matched(1) + Reflect.getProperty(vars, replaceVar));
            content = search.matchedRight();
        }
        if(content != null) output.add(content);

        return output.toString();
    }

    static function ask(msg : String) : Bool {
        var response = '';
        while(!['y', 'n'].has(response)) {
            print(msg.rtrim() + ' (y/n) ');
            response = Sys.stdin().readLine().toLowerCase();
        }
        return response == 'y';
    }

    static function exec(commands : Array<String>) : Error {
        var errors = [];
        for(cmd in commands) {
            try ChildProcess.execSync(cmd)
            catch(e : js.Error) errors.push(e);
        }

        return errors.length > 0 
            ? new Error(errors.map(function(err) return err.message).join("\n"))
            : null;
    }
}

@immutable class AppData implements DataClass
{
    @validate(~/[a-zA-Z]\w*/) public var app : String;
    @validate(~/\w+/) public var username : String;
    @validate(_.length > 0) public var basepath : String;
    @validate(_ >= 1024) public var startport : Int;
}

@immutable class HostData implements DataClass
{
    @validate(~/[a-zA-Z]\w*\d+/) public var id : String;
    @validate(_.length > 1) public var path : String;
    @validate(~/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/) public var host : String;
    @validate(_ >= 1024) public var port : Int;
    @validate(~/\w+/) public var user : String;
    public var enabled : Bool;
}