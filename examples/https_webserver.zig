// run with:
// $ zig run examples/hello_world.zig --pkg-begin pass src/pass.zig

// this playbook will:
//     - configure firewall (will allow ssh, http, https)
//     - enable letsencrypt certificates for domain
//     - configure nginx static website with https support

const std = @import("std");
const assert = std.debug.assert;
const pass = @import("pass");
const checks = pass.checks;
const actions = pass.actions;

pub fn main() void {
    const a = std.testing.allocator;

    // ! CHANGE EMAIL AND WEBSERVER NAMES TO CORRECT VALUES !
    const email = "your_email";
    const webserver_domain = "your_domain";

    comptime assert(!std.mem.eql(u8, email, "your_email"));
    comptime assert(!std.mem.eql(u8, webserver_domain, "your_domain"));

    const nginx_conf = std.mem.replaceOwned(u8, a, @embedFile("https_webserver_nginx.conf"), "{--domain--}", webserver_domain) catch unreachable;
    defer a.free(nginx_conf);
    const index_html = @embedFile("https_webserver_index.html");
    const certbot_renew = @embedFile("https_webserver_certbot-renew");

    const book = pass.Playbook.init(
        &.{
            checks.Check_UserIsRoot.init().as_Check(),
            checks.Named.init("Os is Ubuntu 20.04", checks.Check_StdoutContainsOnce.init(&.{ "lsb_release", "-a" }, "Ubuntu 20.04").as_Check()).as_Check(),
        },
        &[_]pass.Instruction{
            .{
                .action = actions.Named.init("Upgrade apt packages", actions.Action_Many.init(&.{
                    actions.Action_RunProcess.init(&.{ "apt", "update", "-y" }).as_Action(),
                    actions.Action_RunProcess.init(&.{ "apt", "upgrade", "-y" }).as_Action(),
                }).as_Action()).as_Action(),
            },
            .{
                .action = actions.Action_InstallAptPackages.init(&.{ "nginx", "certbot" }).as_Action(),
            },
            .{
                .env = &.{
                    checks.Named.init("Firewall is inactive", checks.Check_StdoutContainsOnce.init(&.{ "ufw", "status" }, "Status: inactive").as_Check()).as_Check(),
                },
                .action = actions.Named.init("Configure firewall", actions.Action_Many.init(&.{
                    actions.Action_RunProcess.init(&.{ "ufw", "allow", "ssh" }).as_Action(),
                    actions.Action_RunProcess.init(&.{ "ufw", "allow", "http" }).as_Action(),
                    actions.Action_RunProcess.init(&.{ "ufw", "allow", "https" }).as_Action(),
                    actions.Action_RunProcess.init(&.{ "ufw", "default", "deny", "incoming" }).as_Action(),
                    actions.Action_RunProcess.init(&.{ "ufw", "default", "allow", "outgoing" }).as_Action(),
                }).as_Action()).as_Action(),
            },
            .{
                .action = actions.Named.init("Stop nginx", actions.Action_RunProcess.init(&.{ "systemctl", "stop", "nginx" }).as_Action()).as_Action(),
            },
            .{
                .env = &.{
                    checks.Named.init("Nginx is inactive", checks.Check_StdoutContainsOnce.init(&.{ "systemctl", "is-active", "nginx" }, "inactive").as_Check()).as_Check(),
                },
                .confirm = &.{
                    checks.Named.init("Ssl certificate exists", checks.Check_IsFile.init("/etc/letsencrypt/live/" ++ webserver_domain ++ "/fullchain.pem").as_Check()).as_Check(),
                },
                .action = actions.Named.init("Request ssl certificate", actions.Action_RunProcess.init(&.{ "certbot", "certonly", "--standalone", "--agree-tos", "--no-eff-email", "-m", email, "-d", webserver_domain }).as_Action()).as_Action(),
            },
            .{
                .confirm = &.{
                    checks.Named.init("Is certbot renew enabled", checks.Check_IsFile.init("/etc/cron.weekly/certbot-renew").as_Check()).as_Check(),
                },
                .action = actions.Named.init("Enable certbot renew", actions.Action_Many.init(&.{
                    actions.Action_WriteFile.init("/etc/cron.weekly/certbot-renew", certbot_renew).as_Action(),
                    actions.Action_SetFilePermissions.init("/etc/cron.weekly/certbot-renew", 0o555, "root", "root").as_Action(),
                }).as_Action()).as_Action(),
            },
            .{
                .confirm = &.{
                    checks.Named.init("Default nginx site deleted", checks.Check_Not.init(checks.Check_IsFile.init("/etc/nginx/sites-enabled/default").as_Check()).as_Check()).as_Check(),
                },
                .action = actions.Named.init("Delete default nginx site", actions.Action_DeleteFile.init("/etc/nginx/sites-enabled/default").as_Action()).as_Action(),
            },
            .{
                .confirm = &.{
                    checks.Named.init("Is pass demo site nginx configuration exists", checks.Check_IsFile.init("/etc/nginx/sites-enabled/pass-demo").as_Check()).as_Check(),
                },
                .action = actions.Named.init("Create pass demo site nginx configuration", actions.Action_WriteFile.init("/etc/nginx/sites-enabled/pass-demo", nginx_conf).as_Action()).as_Action(),
            },
            .{
                .action = actions.Named.init("Create website files", actions.Action_Many.init(&.{
                    actions.Action_CreateDir.init("/opt/pass-demo-site", 0o774, "www-data", "www-data").as_Action(),
                    actions.Action_WriteFile.init("/opt/pass-demo-site/index.html", index_html).as_Action(),
                    actions.Action_SetFilePermissions.init("/opt/pass-demo-site/index.html", 0o664, "www-data", "www-data").as_Action(),
                }).as_Action()).as_Action(),
            },
            .{
                .action = actions.Named.init("Start nginx", actions.Action_RunProcess.init(&.{ "systemctl", "start", "nginx" }).as_Action()).as_Action(),
            },
            .{
                .action = actions.Named.init("Start firewall", actions.Action_RunProcess.init(&.{ "systemctl", "start", "ufw" }).as_Action()).as_Action(),
            },
            .{
                .action = actions.Named.init("Enable firewall", actions.Action_RunProcess.init(&.{ "ufw", "--force", "enable" }).as_Action()).as_Action(),
            },
        },
    );

    _ = book.apply(a);
}
