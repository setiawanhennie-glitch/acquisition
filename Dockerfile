# syntax=docker/dockerfile:1

# ---------- Base: shared runtime config only (NO dependency install) ----------
FROM node:20-alpine AS base
WORKDIR /app

# Non-root user with fixed UID
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) }).on('error', () => { process.exit(1) })"

# ---------- Development ----------
FROM base AS development
ENV NODE_ENV=development

# Install ALL dependencies (prod + dev) exactly once
COPY --chown=nodejs:nodejs package*.json ./
RUN npm ci && npm cache clean --force

# Application source (node_modules excluded via .dockerignore)
COPY --chown=nodejs:nodejs . .

CMD ["npm", "run", "dev"]

# ---------- Production (default target) ----------
FROM base AS production
ENV NODE_ENV=production

# Install production dependencies exactly once
COPY --chown=nodejs:nodejs package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --chown=nodejs:nodejs . .

CMD ["npm", "start"]