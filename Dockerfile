FROM node:20-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

WORKDIR /evolution

COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

# 🔥 FIX IMPORTANTE (evita errores de peer deps)
RUN npm install --legacy-peer-deps

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env

# 🔥 PRISMA ESTABLE (OBLIGATORIO)
RUN npm install prisma@5 @prisma/client@5 --legacy-peer-deps

RUN npx prisma generate --schema=./prisma/mysql-schema.prisma

RUN npm run build


# ================= FINAL =================
FROM node:20-alpine AS final

RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true
ENV NODE_ENV=production

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", "npx prisma migrate deploy --schema=./prisma/mysql-schema.prisma && npm run start:prod"]
