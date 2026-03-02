# ── Stage 1: Build the React application ─────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /build

# Copy package manifests first for layer-cache efficiency
COPY react-app/package.json react-app/package-lock.json* ./

# Install dependencies
RUN npm ci --silent

# Copy the full React source tree.
# For react-app-07 the build context includes react-app/src/scripts/aws_config.py
# (injected by Terraform). For the other 19 repos this directory is absent.
COPY react-app/ .

# Ensure scripts directory always exists so Stage 2 COPY never fails
RUN mkdir -p /build/src/scripts

# Build the production bundle
RUN npm run build

# ── Stage 2: Serve with nginx ─────────────────────────────────────────────────
FROM nginx:1.25-alpine

# Custom nginx config (SPA routing + caching headers)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the compiled React app
COPY --from=builder /build/build /usr/share/nginx/html

# Copy the scripts directory into the final image.
# For react-app-07: contains aws_config.py with IAM credentials.
# For all others:   directory is empty — no credentials present.
COPY --from=builder /build/src/scripts /app/src/scripts/

# Build-time label to identify which repo this image belongs to
ARG REPO_NAME=unknown
LABEL repo.name="${REPO_NAME}"
LABEL org.opencontainers.image.description="Stags Lab React Dashboard — ECR CTF Challenge"

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
