FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

WORKDIR /evolution

# Copiar archivos de configuración de dependencias
COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

# Instalar dependencias limpias para compilar
RUN npm ci --silent

# Copiar el código fuente indispensable
COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env

# --- CAMBIO CRÍTICO PARA MYSQL ---
# Forzamos a Prisma a leer el esquema de MySQL antes de compilar
ENV DATABASE_PROVIDER=mysql
RUN npx prisma generate --schema=./prisma/mysql-schema.prisma

# Compilar TypeScript a JavaScript de producción
RUN npm run build

# --- ETAPA FINAL ---
FROM node:24-alpine AS final

RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl

# Configuración de entorno requerida por Evolution API
ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true
ENV NODE_ENV=production

WORKDIR /evolution

# Traer solo lo necesario desde el compilador
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env

EXPOSE 8080

# Comando optimizado para MySQL en Render: Ejecuta migraciones e inicia la API
ENTRYPOINT ["/bin/bash", "-c", "npx prisma migrate deploy --schema=./prisma/mysql-schema.prisma && npm run start:prod"]