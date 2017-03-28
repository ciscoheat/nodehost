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

enum Protocols
{
    Http;
    Https;
}

class Nodehost implements Async
{
    var config : AppData;

    static function configFile(app : String) return '/etc/nginx/' + app + ".conf.json";

    public static function fromConfig(app : String) {
        if(!exists(configFile(app)))
            throw 'Configuration file ' + configFile(app) + " doesn't exist.";

        return new Nodehost(AppData.fromJson(haxe.Json.parse(File.getContent(configFile(app)))));
    }

    ///////////////////////////////////////////////////////////////////////////

    public function new(config : AppData) {
        if(config.username == "root") throw "Nodehost cannot be used as root.";
        if(exec(['id -u ${config.username} > /dev/null']) != null) throw 'User ${config.username} doesn\'t exist.';

        this.config = config;
    }

    ///////////////////////////////////////////////////////////////////////////

    public function checkDependencies(forceInstall : Bool, cb : Error -> Void) {
        // nodemon
        var err, stdout, stderr : String = @async ChildProcess.exec("nodemon -v", {encoding: 'utf-8'});
        if(err != null) {
            var command = "sudo npm install -g nodemon";
            var error = "nodemon not found. Can be installed with:\n" + command;

            var err = if(forceInstall) exec([command]) else new Error(error);
            if(err != null) return cb(err);
        }

        // Nginx
        var err, stdout, stderr : String = @async ChildProcess.exec("/etc/init.d/nginx status", {encoding: 'utf-8'});
        if(err != null) {
            var command = "sudo add-apt-repository -y ppa:nginx/stable && sudo apt-get update -y && sudo apt-get install -y nginx";
            var error = "Nginx not found. Can be installed with:\n" + command;

            var err = if(forceInstall) exec([command]) else new Error(error);
            if(err != null) return cb(err);
        }

        // certbot
        var err, stdout, stderr : String = @async ChildProcess.exec("certbot --version", {encoding: 'utf-8'});
        if(err != null) {
            var command = "sudo add-apt-repository -y ppa:certbot/certbot && sudo apt-get update -y && sudo apt-get install -y certbot";
            var error = "certbot/letsencrypt not found. Can be installed with:\n" + command;

            var err = if(forceInstall) exec([command]) else new Error(error);
            if(err != null) return cb(err);
        }

        cb(null);
    }

    ///////////////////////////////////////////////////////////////////////////

    public function setup(forceInstall : Bool, cb : Error -> Void) {
        if(!ask('Setup ${config.app} for user "${config.username}" in directory "${config.basepath}"?')) {
            return cb(new Error("User interrupt."));
        }

        var err = @async(err => cb) checkDependencies(forceInstall);

        if(exists(configFile(config.app))) {
            return cb(new Error('Configuration file ${configFile(config.app)} already exists.'));
        }

        // Setup
        var err = sudoExec([
            'getent group ${config.app} || sudo addgroup ${config.app}',
            'gpasswd -a ${config.username} ${config.app}',
            'mkdir -p ${config.basepath}',
            'chown ${config.username}:${config.app} ${config.basepath}'
        ]);
        if(err != null) return cb(err);

        var json = haxe.Json.stringify(config.toJson(), "    ") + "\n";
        var err = installFile(configFile(config.app), json, 'root', 644);

        cb(err);
    }

    ///////////////////////////////////////////////////////////////////////////

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
                    path: Path.join([config.basepath, host]),
                    host: host,
                    port: port,
                    enabled: enabled.has(id),
                });
            });
            cb(null, hosts);
        } catch(err : Error) {
            cb(err, null);
        }
    }

    ///////////////////////////////////////////////////////////////////////////

    public function create(hostname : String, protocols : haxe.EnumFlags<Protocols>, separateUser : Bool, cb : Error -> Void) {
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
        });

        var user = separateUser ? id : config.username;

        Reflect.setField(hostData, 'USER', user);

        // Render templates
        function template(name : String)
            return Path.join([js.Node.__dirname, 'templates', name]);

        // Add special LOCATION var, for nginx configuration
        var location = render(template('nginx.location.conf'), hostData);
        Reflect.setField(hostData, 'LOCATION', location);

        var systemd = render(template('systemd.conf'), hostData);
        var http = protocols.has(Http) ? render(template('nginx.http.conf'), hostData) : '';
        var https = protocols.has(Https) ? render(template('nginx.https.conf'), hostData) : '';
        var startup = ~/\r/g.replace(render(template('startup.sh'), hostData), ''); // Remove carriage returns from shell script
        var app = render(template('app.js'), hostData);

        installFile(
            Path.join(['/etc/systemd/system', hostData.id + ".service"]),
            systemd, 'root', 755
        );

        var header = '# ${hostData.host} on port ${hostData.port}\n';
        installFile(
            Path.join(['/etc/nginx/sites-available', hostData.id + ".conf"]),
            header + [http, https].join('\n'), 'root', 644
        );

        // Create home directory
        sudoExec(['mkdir -p ' + Path.join([hostData.path, 'www', 'public'])]);

        // Create extra user
        if(separateUser) sudoExec(['adduser --no-create-home --system ${hostData.id}']);

        // Add default app.js
        var appFile = Path.join([hostData.path, 'www', 'app.js']);
        if(!exists(appFile)) {
            installFile(appFile, app, 660);
        }

        // Add service start file
        var serviceFile = Path.join([hostData.path, hostData.host]);
        if(!exists(serviceFile)) {
            installFile(serviceFile, startup, 770);
        }

        // Set owner to service user
        sudoExec(['chown $user:${config.app} ${hostData.path} -R']);

        // Enable service
        start(hostname, cb);
    }

    ///////////////////////////////////////////////////////////////////////////

    public function start(hostname : String, cb : Error -> Void) {
        var err, hostData = @async(err => cb) getHost(hostname);

        if(hostData.enabled)
            return cb(new Error('$hostname is already enabled.'));

        var src = Path.join(['/etc/nginx/sites-available', hostData.id + '.conf']);

        var execute = [
            'ln -s $src ' + src.replace('/sites-available/', '/sites-enabled/'),
            '/etc/init.d/nginx reload',
            'systemctl enable ' + hostData.id,
            'systemctl start ' + hostData.id
        ];

        cb(sudoExec(execute));
    }

    ///////////////////////////////////////////////////////////////////////////

    public function stop(hostname : String, cb : Error -> Void) {
        var err, hostData = @async(err => cb) getHost(hostname);

        if(!hostData.enabled)
            return cb(new Error('$hostname is not enabled.'));

        var src = Path.join(['/etc/nginx/sites-enabled', hostData.id + '.conf']);

        var execute = [
            'rm $src',
            '/etc/init.d/nginx reload',
            'systemctl disable ' + hostData.id,
            'systemctl stop ' + hostData.id
        ];

        cb(sudoExec(execute));
    }

    ///////////////////////////////////////////////////////////////////////////

    public function restart(hostname : String, cb : Error -> Void) {
        var err, hostData = @async(err => cb) getHost(hostname);

        if(!hostData.enabled)
            return start(hostname, cb);

        var execute = [
            '/etc/init.d/nginx reload',
            'systemctl restart ' + hostData.id
        ];

        cb(sudoExec(execute));
    }

    ///////////////////////////////////////////////////////////////////////////

    public function status(hostname : String, params : Array<String>, cb : Error -> Void) {
        var err, hostData = @async(err => cb) getHost(hostname);

        var execute = [
            //'systemctl ${params.join(" ")} status ' + hostData.id
            'systemctl status ' + hostData.id
        ];

        cb(exec(execute));
    }

    ///////////////////////////////////////////////////////////////////////////

    public function remove(hostname : String, includingDir : Bool, cb : Error -> Void) {
        if(!ask('Remove "$hostname"?')) {
            return cb(new Error("User interrupt."));
        }
        
        var err = @async stop(hostname);
        var err, hostData = @async(err => cb) getHost(hostname);

        var execute = [
            'getent passwd ${hostData.id} > /dev/null && deluser ${hostData.id}',
            'rm -f ' + Path.join(['/etc/systemd/system', hostData.id + ".service"]),
            'rm -f ' + Path.join(['/etc/nginx/sites-available', hostData.id + ".conf"])
        ];

        if(includingDir) execute.push('rm -rf ' + hostData.path);

        cb(sudoExec(execute));
    }

    ///////////////////////////////////////////////////////////////////////////

    public function editNginx(hostname : String, restartAfter : Bool, cb : Error -> Void) {
        var err, hostData = @async(err => cb) getHost(hostname);
        var file = Path.join(['/etc/nginx/sites-available', hostData.id + ".conf"]);

        var err = sudoExec(['sudo bash -c "$${EDITOR:-nano} $file"']);
        if(restartAfter && err == null) restart(hostname, cb);
        else cb(err);
    }

    ///////////////////////////////////////////////////////////////////////////

    function getHost(hostname : String, cb : Error -> HostData -> Void) : Void {
        var err, hosts = @async(err, null => cb) list();
        var hostData = hosts.find(function(host) return host.host == hostname);
        var error = hostData == null ? new Error('Host "$hostname" doesn\'t exist.') : null;

        cb(error, hostData);
    }

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
            response = js.Lib.require('readline-sync').question(msg.rtrim() + ' (y/n) ').toLowerCase();
        }
        return response == 'y';
    }

    static function exec(commands : Array<String>) : Error {
        var errors = [];
        for(cmd in commands) {
            try ChildProcess.execSync(cmd, {stdio: 'inherit'})
            catch(e : js.Error) errors.push(e);
        }

        return errors.length > 0
            ? new Error(errors.map(function(err) return err.message).join("\n"))
            : null;
    }

    static function sudoExec(commands : Array<String>)
        return exec(commands.map(function(cmd) return 'sudo $cmd'));

    static function installFile(filename : String, content : String, ?owner : String, ?permissions : Int) {
        try {
            var tmpFile = js.Lib.require('tmp').fileSync();
            File.saveContent(tmpFile.name, content);

            var params = ['install'];
            if(owner != null) params.push('-g $owner -o $owner');
            if(permissions != null) params.push('-m ' + Std.string(permissions));
            params.push(tmpFile.name + " " + filename);

            return sudoExec([params.join(" ")]);            
        }
        catch(e : Error) return e;
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
    public var enabled : Bool;
}