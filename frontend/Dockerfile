FROM nginx:alpine

# Copy static files
COPY html/ /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf
COPY security-headers.conf /etc/nginx/security-headers.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
