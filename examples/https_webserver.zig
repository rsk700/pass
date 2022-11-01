// run with:
// $ zig run examples/hello_world.zig --pkg-begin pass src/pass.zig

// this playbook will:
//     - configure firewall (will allow ssh, http, https)
//     - enable letsencrypt certificates for domain
//     - configure nginx static website with https support

const std = @import("std");
const assert = std.debug.assert;
const pass = @import("pass");
const c = pass.checks;
const a = pass.actions;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // ! CHANGE EMAIL AND WEBSERVER NAMES TO CORRECT VALUES !
    const email = "your_email";
    const webserver_domain = "your_domain";

    comptime assert(!std.mem.eql(u8, email, "your_email"));
    comptime assert(!std.mem.eql(u8, webserver_domain, "your_domain"));

    const nginx_conf = std.mem.replaceOwned(u8, allocator, @embedFile("https_webserver_nginx.conf"), "{--domain--}", webserver_domain) catch unreachable;
    defer allocator.free(nginx_conf);
    const index_html = @embedFile("https_webserver_index.html");
    const certbot_renew = @embedFile("https_webserver_certbot-renew");

    const book = pass.Playbook.init(
        comptime &.{
            c.userIsRoot(),
            c.named("Os is Ubuntu 20.04", c.stdoutContainsOnce(&.{ "lsb_release", "-a" }, "Ubuntu 20.04")),
        },
        &[_]pass.Instruction{
            comptime .{
                .action = a.named("Upgrade apt packages", a.many(&.{
                    a.runProcess(&.{ "apt", "update", "-y" }),
                    a.runProcess(&.{ "apt", "upgrade", "-y" }),
                })),
            },
            comptime .{
                .action = a.installAptPackages(&.{ "nginx", "certbot" }),
            },
            comptime .{
                .env = &.{
                    c.named("Firewall is inactive", c.stdoutContainsOnce(&.{ "ufw", "status" }, "Status: inactive")),
                },
                .action = a.named("Configure firewall", a.many(&.{
                    a.runProcess(&.{ "ufw", "allow", "ssh" }),
                    a.runProcess(&.{ "ufw", "allow", "http" }),
                    a.runProcess(&.{ "ufw", "allow", "https" }),
                    a.runProcess(&.{ "ufw", "default", "deny", "incoming" }),
                    a.runProcess(&.{ "ufw", "default", "allow", "outgoing" }),
                })),
            },
            comptime .{
                .action = a.named("Stop nginx", a.runProcess(&.{ "systemctl", "stop", "nginx" })),
            },
            comptime .{
                .env = &.{
                    c.named("Nginx is inactive", c.stdoutContainsOnce(&.{ "systemctl", "is-active", "nginx" }, "inactive")),
                },
                .confirm = &.{
                    c.named("Ssl certificate exists", c.isFile("/etc/letsencrypt/live/" ++ webserver_domain ++ "/fullchain.pem")),
                },
                .action = a.named("Request ssl certificate", a.runProcess(&.{ "certbot", "certonly", "--standalone", "--agree-tos", "--no-eff-email", "-m", email, "-d", webserver_domain })),
            },
            comptime .{
                .confirm = &.{
                    c.named("Is certbot renew enabled", c.isFile("/etc/cron.weekly/certbot-renew")),
                },
                .action = a.named("Enable certbot renew", a.many(&.{
                    a.writeFile("/etc/cron.weekly/certbot-renew", certbot_renew),
                    a.setFilePermissions("/etc/cron.weekly/certbot-renew", 0o555, "root", "root"),
                })),
            },
            comptime .{
                .confirm = &.{
                    c.named("Default nginx site deleted", c.not(c.isFile("/etc/nginx/sites-enabled/default"))),
                },
                .action = a.named("Delete default nginx site", a.deleteFile("/etc/nginx/sites-enabled/default")),
            },
            .{
                .confirm = comptime &.{
                    c.named("Is pass demo site nginx configuration exists", c.isFile("/etc/nginx/sites-enabled/pass-demo")),
                },
                .action = a.Action_Named.init("Create pass demo site nginx configuration", a.Action_WriteFile.init("/etc/nginx/sites-enabled/pass-demo", nginx_conf).as_Action()).as_Action(),
            },
            comptime .{
                .action = a.named("Create website files", a.many(&.{
                    a.createDir("/opt/pass-demo-site", 0o774, "www-data", "www-data"),
                    a.writeFile("/opt/pass-demo-site/index.html", index_html),
                    a.setFilePermissions("/opt/pass-demo-site/index.html", 0o664, "www-data", "www-data"),
                })),
            },
            comptime .{
                .action = a.named("Start nginx", a.runProcess(&.{ "systemctl", "start", "nginx" })),
            },
            comptime .{
                .action = a.named("Start firewall", a.runProcess(&.{ "systemctl", "start", "ufw" })),
            },
            comptime .{
                .action = a.named("Enable firewall", a.runProcess(&.{ "ufw", "--force", "enable" })),
            },
        },
    );

    _ = book.apply(allocator);
}
