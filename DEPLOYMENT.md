# 🚀 LaunchPad Deployment Guide (Low Resource Optimization)

This workflow is optimized for **Tech Leads** deploying to VPS environments with limited CPU/RAM. Instead of building on the VPS (which causes crashes and high latency), we use a **Local Build & Push** strategy.

## 🏗️ Deployment Architecture

1.  **Local Machine/CI:** Build Docker images.
2.  **Private Registry:** Store images securely.
3.  **Production VPS:** Only pulls and runs (Zero build overhead).

---

## 📦 1. Setup Your Private Registry

First, initialize your registry on the VPS or a dedicated storage server.

### Generate Auth
```bash
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn <user> <password> > auth/registry.password
```

### Launch Registry & UI
```bash
docker compose up -d
```
Access the UI at `http://<SERVER_IP>:8080`.

---

## 🛠️ 2. Build & Push Workflow (Local/CI)

Perform these steps on your powerful local machine or CI pipeline to avoid taxing the VPS.

### Step 1: Login to Registry
```bash
docker login <REGISTRY_DOMAIN_OR_IP>:5000
```
*(If using HTTP without Nginx, add the IP to `insecure-registries` in `daemon.json`)*

### Step 2: Build and Tag Images
Navigate to your [strapi-docker-boilerplate](https://github.com/tuquet/strapi-docker-boilerplate) folder:

```bash
# Build Strapi Image
docker build -t <REGISTRY_IP>:5000/strapi-app:v1 ./strapi

# Build Next.js Image
docker build -t <REGISTRY_IP>:5000/next-app:v1 ./next
```

### Step 3: Push to Registry
```bash
docker push <REGISTRY_IP>:5000/strapi-app:v1
docker push <REGISTRY_IP>:5000/next-app:v1
```

---

## 🚀 3. Pull & Deploy on VPS

On the production VPS, your `docker-compose.yml` should reference the images from your registry.

### Optimized `docker-compose.prod.yml`
```yaml
services:
  strapi:
    image: <REGISTRY_IP>:5000/strapi-app:v1
    restart: always
    # ... other config ...

  nextjs:
    image: <REGISTRY_IP>:5000/next-app:v1
    restart: always
    # ... other config ...
```

### Deploy Lighly
```bash
# Login on VPS
docker login <REGISTRY_IP>:5000

# Pull and Start (Zero Build Time)
docker compose -f docker-compose.prod.yml up -d
```

---

## 💡 Best Practices for Low-RAM VPS

- **No `build` on VPS:** Never run `docker compose up --build` on a 1GB/2GB RAM VPS. It will likely hang during `yarn install` or `next build`.
- **Pre-baked Env Vars:** Bake production-safe environment variables into your docker images during build time or use a shared `.env` file that doesn't trigger a rebuild.
- **Nginx Reverse Proxy:** Use the provided [nginx-registry.conf](nginx-registry.conf) to proxy `hub.yourdomain.com` to port 5000 with SSL. This makes `docker login` secure and standard.
- **Garbage Collection:** Registry storage grows fast. Run this to clean up:
  ```bash
  docker exec docker-registry bin/registry garbage-collect /etc/docker/registry/config.yml
  ```

---

## 📈 Summary of Lifecycle
1. **Code** (Local) → 2. **Build** (Local) → 3. **Push** (Registry) → 4. **Pull** (VPS) → 5. **Run** (VPS)
