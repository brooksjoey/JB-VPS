# Websites & Domains

## What this area is for

This area helps you host websites and manage domains on your VPS. You can set up web servers, configure domains, and manage site files.

## Common things you can do here

- Point domains to your server's IP address
- Set up web servers (nginx, Apache)
- Host static websites or web applications
- Configure SSL certificates
- Manage virtual hosts and site configurations
- Upload and organize website files

## What each menu choice will do

1. **Point a domain to this server** - Provides DNS configuration instructions and checks
2. **Host a simple website** - Sets up a basic website with web server configuration
3. **Add or remove a site** - Manages virtual hosts and site configurations
4. **Show where site files live** - Displays web root directories and file locations

## Where files will be created

- Website files: `/var/www/` (default web root)
- Server configs: `/etc/nginx/sites-available/` or `/etc/apache2/sites-available/`
- SSL certificates: `/etc/ssl/certs/` or `/etc/letsencrypt/`
- Log files: `/var/log/nginx/` or `/var/log/apache2/`

## Logs and files

- Web server access logs: `/var/log/nginx/access.log` or similar
- Web server error logs: `/var/log/nginx/error.log` or similar
- JB-VPS web log: `/var/log/jb-vps/web.log`
- Site configurations: `/etc/nginx/sites-enabled/` or similar

## Example: Host a simple website

The "Host a simple website" option will:
1. Install and configure a web server (nginx by default)
2. Create a sample website in `/var/www/example/`
3. Set up a virtual host configuration
4. Start the web server
5. Display the URL where your site is accessible

Use `jb help web` for command-line options or navigate through the menu for guided assistance.
