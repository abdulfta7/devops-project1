# Database Dockerfile - MySQL with initialization
FROM mysql:8.0

# Metadata
LABEL maintainer="student@example.com" \
      version="1.0" \
      description="Bookstore MySQL Database"

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# Expose port
EXPOSE 3306

# Health check (BONUS)
HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
  CMD mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD || exit 1
