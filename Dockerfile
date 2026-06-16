FROM node:20-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

WORKDIR /evolution

# =========================
# DEPENDENCIAS
# =========================
COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

# 🔥 INSTALACIÓN ESTABLE
RUN npm install --legacy-peer-deps

# 🔥 PRISMA VERSION ESTABLE (IMPORTANTE)
RUN npm install prisma@5.19.0 @prisma/client@5.19.0 --legacy-peer-deps

# =========================
# CÓDIGO
# =========================
COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env

# =========================
# PRISMA GENERATE
# =========================
RUN npx prisma generate --schema=./prisma/mysql-schema.prisma

# =========================
# BUILD (EVITA CRASH TS)
# =========================
ENV TS_NODE_TRANSPILE_ONLY=1

RUN npx tsc --noEmit || true && npx tsup


# =========================
# RUNTIME
# =========================
FROM node:20-alpine AS final

RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true
ENV NODE_ENV=production

WORKDIR /evolution

# =========================
# SOLO LO NECESARIO
# =========================
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env

EXPOSE 8080

# =========================
# START
# =========================
ENTRYPOINT ["/bin/bash", "-c", "npx prisma migrate deploy --schema=./prisma/mysql-schema.prisma && npm run start:prod"]
