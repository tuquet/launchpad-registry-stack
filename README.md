# Private Docker Registry Boilerplate

A lightweight, self-hosted Docker Registry with a Web UI and Basic Authentication.

---

### 🚀 Recommended Companion
This registry is designed to work perfectly with the [Strapi Docker Boilerplate](https://github.com/tuquet/strapi-docker-boilerplate). Use them together to achieve a professional **Build Locally, Deploy Seamlessly** workflow that saves VPS resources.

---

> **Looking for the full deployment workflow?** See [DEPLOYMENT.md](DEPLOYMENT.md) for instructions on how to deploy **Strapi + Next.js** using the [Strapi Docker Boilerplate](https://github.com/tuquet/strapi-docker-boilerplate) without consuming VPS build resources.

## Project Structure
```text
.
├── docker-compose.yml
├── nginx-registry.conf
├── auth/
│   └── registry.password
└── data/ (Auto-generated image storage)
```

## Quick Start

### 1. Setup Basic Authentication
Generate your password file using `htpasswd`. If you don't have it installed locally, use Docker:

```bash
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn <your_user> <your_password> > auth/registry.password
```

### 2. Launch Registry
```bash
docker compose up -d
```

### 3. Access Web UI
Open your browser and navigate to `http://localhost:8080`.

---

## Workflow for Tech Leads

### Step 1: Login
Authenticate your local build machine or CI/CD runner:
```bash
docker login <SERVER_IP>:5000
```
*Note: If using HTTP, add the IP to `insecure-registries` in Docker's `daemon.json`.*

### Step 2: Tag and Push Image
```bash
# Tag existing image
docker tag my-app:latest <SERVER_IP>:5000/my-app:v1

# Push to private registry
docker push <SERVER_IP>:5000/my-app:v1
```

### Step 3: Pull on Production VPS
```bash
docker pull <SERVER_IP>:5000/my-app:v1
```

---

## Pro Tips

1. **Nginx Reverse Proxy:** Use the provided [nginx-registry.conf](nginx-registry.conf) to map a domain (e.g., `hub.example.com`) and setup SSL. This removes the need for `insecure-registries` configuration.
2. **Garbage Collection:** Docker images consume significant disk space. Delete unused tags via UI, then run garbage collection inside the container:
   ```bash
   docker exec docker-registry bin/registry garbage-collect /etc/docker/registry/config.yml
   ```
3. **Storage Cleanup:** Ensure `REGISTRY_STORAGE_DELETE_ENABLED` is set to `true` in `docker-compose.yml` to allow the UI to delete images.
