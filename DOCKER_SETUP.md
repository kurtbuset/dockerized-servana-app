# Docker Setup Documentation

## Overview

This document describes the Docker architecture for the Servana application, which consists of two interconnected Docker Compose setups:

1. **LibriLens** - Supabase backend infrastructure
2. **Servana** - Main application (backend + frontend)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Host Machine                              │
│                                                                 │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │   LibriLens Stack   │    │        Servana Stack            │ │
│  │   (supabase)        │    │        (servana)                │ │
│  │                     │    │                                 │ │
│  │  ┌───────────────┐  │    │  ┌─────────────────────────────┐ │ │
│  │  │ supabase-kong │◄─┼────┼──┤ servana_backend             │ │ │
│  │  │ Port: 8000    │  │    │  │ Port: 5000                  │ │ │
│  │  └───────────────┘  │    │  └─────────────────────────────┘ │ │
│  │         │            │    │              │                  │ │
│  │  ┌───────────────┐  │    │  ┌─────────────────────────────┐ │ │
│  │  │ supabase-db   │  │    │  │ servana_frontend            │ │ │
│  │  │ Port: 5432    │  │    │  │ Port: 3000 → 80             │ │ │
│  │  └───────────────┘  │    │  └─────────────────────────────┘ │ │
│  │         │            │    │                                 │ │
│  │  ┌───────────────┐  │    │                                 │ │
│  │  │ Other Services│  │    │                                 │ │
│  │  │ - auth        │  │    │                                 │ │
│  │  │ - rest        │  │    │                                 │ │
│  │  │ - storage     │  │    │                                 │ │
│  │  │ - realtime    │  │    │                                 │ │
│  │  └───────────────┘  │    │                                 │ │
│  └─────────────────────┘    └─────────────────────────────────┘ │
│           │                              │                      │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │ supabase_default    │    │ servana_network                 │ │
│  │ (external network)  │◄───┤ (bridge network)               │ │
│  └─────────────────────┘    └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Network Configuration

### LibriLens Networks
- **supabase_default**: Default bridge network for all Supabase services
- **External**: Exposed to allow external connections from Servana

### Servana Networks
- **servana_network**: Internal bridge network for Servana services
- **supabase_default**: External network connection to LibriLens infrastructure

## Service Details

### LibriLens Stack (./librilens/docker-compose.yml)

| Service | Container Name | Port | Purpose |
|---------|----------------|------|---------|
| kong | supabase-kong | 8000 | API Gateway - Entry point for all API requests |
| db | supabase-db | 5432 | PostgreSQL database |
| auth | supabase-auth | 9999 | Authentication service (GoTrue) |
| rest | supabase-rest | 3000 | PostgREST API server |
| realtime | realtime-dev.supabase-realtime | 4000 | Real-time subscriptions |
| storage | supabase-storage | 5000 | File storage service |
| meta | supabase-meta | 8080 | Database metadata API |
| functions | supabase-edge-functions | - | Edge functions runtime |
| analytics | supabase-analytics | 4000 | Logging and analytics |
| studio | supabase-studio | 3000 | Supabase Studio UI |
| imgproxy | supabase-imgproxy | 5001 | Image transformation |
| vector | supabase-vector | 9001 | Log collection |
| supavisor | supabase-pooler | 5432/6543 | Connection pooler |

### Servana Stack (./docker-compose.yml)

| Service | Container Name | Port | Purpose |
|---------|----------------|------|---------|
| backend | servana_backend | 5000 | Node.js API server |
| frontend | servana_frontend | 3000→80 | React web application |

## Connection Flow

### Backend to Database Connection

```
servana_backend → supabase-kong:8000 → supabase services → supabase-db:5432
```

1. **Servana Backend** connects to `supabase-kong:8000` via the `supabase_default` network
2. **Kong Gateway** routes requests to appropriate Supabase services
3. **Supabase Services** interact with the PostgreSQL database

### Environment Variables

#### Servana Backend Database Connection
```yaml
REACT_SUPABASE_URL: http://supabase-kong:8000
REACT_SUPABASE_ANON_KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
REACT_SERVICE_ROLE_KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Frontend to Backend Connection
```yaml
VITE_BACKEND_URL: http://localhost:5000
VITE_SOCKET_URL: http://localhost:5000
```

## Port Mapping

### External Access (Host → Container)
- **3000**: Servana Frontend (React app)
- **5000**: Servana Backend (Node.js API)
- **54323**: LibriLens Kong Gateway (Supabase API)
- **54324**: LibriLens Studio (Supabase Dashboard)

### Internal Communication (Container → Container)
- **supabase-kong:8000**: Servana Backend → Supabase API Gateway
- **backend:5000**: Frontend → Backend (internal)

## Key Features

### Network Isolation
- **LibriLens services** communicate internally via `supabase_default` network
- **Servana services** communicate internally via `servana_network`
- **Cross-stack communication** happens through the shared `supabase_default` network

### Service Discovery
- Services use **container names** for internal communication (not localhost)
- Docker's built-in DNS resolution handles service name → IP mapping
- Example: `supabase-kong` resolves to the Kong container's IP

### Data Persistence
- **Database data**: `./librilens/volumes/db/data`
- **Storage files**: `./librilens/volumes/storage`
- **Application code**: Volume mounts for development

## Startup Sequence

### LibriLens (Start First)
```bash
cd librilens
docker compose up -d
```

### Servana (Start After LibriLens)
```bash
cd ..
docker compose up -d
```

## Dependencies

### Service Dependencies
- **Servana Backend** depends on LibriLens Kong Gateway being available
- **Servana Frontend** depends on Servana Backend
- **All Supabase services** have internal health check dependencies

### Network Dependencies
- **supabase_default** network must exist before starting Servana
- Created automatically when LibriLens stack starts

## Development vs Production

### Development Mode
- **Backend**: Hot reload with volume mounts (`npm run dev`)
- **Frontend**: Development build with environment variables
- **Database**: Local Supabase instance

### Production Considerations
- **Frontend**: Production build served by nginx
- **Environment URLs**: Switch from localhost to service names
- **SSL/TLS**: Configure Kong for HTTPS termination
- **Scaling**: Use Docker Swarm or Kubernetes for multi-instance deployment

## Troubleshooting

### Common Issues

1. **Backend can't connect to database**
   - Ensure LibriLens stack is running first
   - Check `supabase_default` network exists: `docker network ls`
   - Verify Kong is healthy: `docker logs supabase-kong`

2. **Frontend can't reach backend**
   - Check backend container is running: `docker ps`
   - Verify port 5000 is accessible: `curl http://localhost:5000`

3. **Network connectivity issues**
   - Restart both stacks: `docker compose down && docker compose up`
   - Check network configuration: `docker network inspect supabase_default`

### Useful Commands

```bash
# Check running containers
docker ps

# View logs
docker logs servana_backend
docker logs supabase-kong

# Network inspection
docker network ls
docker network inspect supabase_default

# Service health
docker compose ps
docker compose logs [service_name]
```

## Security Considerations

- **JWT Secrets**: Shared between LibriLens and Servana for authentication
- **Network Isolation**: Services only expose necessary ports
- **Environment Variables**: Sensitive data stored in .env files
- **Database Access**: Servana uses service role key for elevated permissions

## Backup and Recovery

### Database Backup
```bash
docker exec supabase-db pg_dump -U postgres postgres > backup.sql
```

### Volume Backup
```bash
docker run --rm -v librilens_db-config:/data -v $(pwd):/backup alpine tar czf /backup/db-config.tar.gz /data
```

This architecture provides a robust, scalable foundation for the Servana application while leveraging Supabase's comprehensive backend services.