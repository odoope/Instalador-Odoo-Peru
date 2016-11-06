#!/bin/bash
sudo apt-get install nginx -y
IPADR=`ifconfig eth0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`
nginx_file=/etc/nginx/sites-available/$IPADR
sudo su root -c "echo 'upstream openerpweb {
    server 0.0.0.0:8069 weight=1 fail_timeout=300s;
}
upstream openerpweb-im {
    server 0.0.0.0:8072 weight=1 fail_timeout=300s;
}
'" >> $nginx_file
echo """server {
    # server port and name
    listen 80;
    server_name    $IPADR;
""" >> $nginx_file
echo '
    # Specifies the maximum accepted body size of a client request, 
    # as indicated by the request header Content-Length. 
    client_max_body_size 200m;
    #log files
    access_log    /var/log/nginx/openerp-access.log;
    error_log    /var/log/nginx/openerp-error.log;
    
    proxy_connect_timeout       600;
    proxy_send_timeout          600;
    proxy_read_timeout          600;
    send_timeout                600;
    keepalive_timeout    600;
    
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss application/rss+xml text/javascript image/svg+xml application/vnd.ms-fontobject application/x-font-ttf font/opentype image/bmp image/png image/gif image/jpeg image/jpg;
	
    # increase proxy buffer to handle some OpenERP web requests
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;
    location / {
        proxy_pass    http://openerpweb;
        # force timeouts if the backend dies
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        # set headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forward-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        # by default, do not forward anything
        proxy_redirect off;
    }
    location /longpolling {
    	 proxy_pass    http://openerpweb-im;
    }
    # cache some static data in memory for 60mins.
    # under heavy load this should relieve stress on the OpenERP web interface a bit.
    location ~* /web/static/ {
        proxy_cache_valid 200 60m;
        proxy_buffering    on;
        expires 864000;
        proxy_pass http://openerpweb;
    }
}' >> $nginx_file
sudo ln -s $nginx_file /etc/nginx/sites-enabled/
sudo service nginx restart
echo 'Houston, estamos listos para despegar. Solo abre http://'$IPADR
echo 'En caso de cualquier problema, contacte a : http://odooperu.pe/page/website.contactus'
