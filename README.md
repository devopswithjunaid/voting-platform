# Three-Tier Voting Application

A simple voting application demonstrating modern three-tier architecture with containerized deployment options.

## Architecture Overview

### Tier 1: Presentation Layer (Frontend)
- **Technology**: Python Flask
- **Port**: 5000
- **Function**: User voting interface

### Tier 2: Business Logic Layer (Backend)
- **Technology**: Node.js Express
- **Port**: 4000
- **Function**: Results API and display

### Tier 3: Data Layer
- **Database**: PostgreSQL (persistent storage)
- **Cache**: Redis (message queue)
- **Worker**: .NET Core (vote processor)

## Application Flow

1. User votes → Frontend (Flask) → Redis queue
2. Worker processes → Redis queue → PostgreSQL database
3. Results display → Backend (Node.js) → PostgreSQL → User

## Quick Start

### Using Docker Compose (Recommended for local development)

```bash
# Clone and navigate to project
git clone <repository-url>
cd voting-platform

# Start all services
docker-compose up --build

# Access applications
# Voting: http://localhost:5000
# Results: http://localhost:4000
```

### Using Kubernetes

```bash
# Apply all manifests
kubectl apply -f k8s/

# Get service URLs
kubectl get services

# Access via LoadBalancer IPs
```

## Project Structure

```
voting-platform/
├── frontend/           # Flask voting interface
│   ├── app.py         # Main application
│   ├── Dockerfile     # Container config
│   ├── requirements.txt
│   └── templates/
├── backend/           # Node.js results API
│   ├── server.js      # Main application
│   ├── Dockerfile     # Container config
│   ├── package.json
│   └── public/
├── worker/            # .NET vote processor
│   ├── Program.cs     # Main application
│   ├── Dockerfile     # Container config
│   └── Worker.csproj
├── k8s/              # Kubernetes manifests
│   ├── frontend.yaml
│   ├── backend.yaml
│   ├── worker.yaml
│   ├── postgres.yaml
│   └── redis.yaml
└── docker-compose.yml # Local development
```

## Components

### Frontend (Flask)
- Simple voting interface with two options
- Prevents duplicate voting per browser session
- Stores votes in Redis queue for processing

### Backend (Node.js)
- REST API endpoint: `/api/votes`
- Real-time results display
- Connects to PostgreSQL for vote counts

### Worker (.NET Core)
- Processes votes from Redis queue
- Stores votes in PostgreSQL database
- Handles duplicate vote updates

### Data Services
- **Redis**: Message queue for asynchronous vote processing
- **PostgreSQL**: Persistent storage for vote data

## Environment Variables

### Backend
- `POSTGRES_HOST`: Database host (default: db)
- `POSTGRES_USER`: Database user (default: postgres)
- `POSTGRES_PASSWORD`: Database password (default: postgres)
- `POSTGRES_DB`: Database name (default: postgres)

### Worker
- `REDIS_HOST`: Redis host (default: redis)
- `POSTGRES_HOST`: Database host (default: db)

## Development

### Prerequisites
- Docker & Docker Compose
- OR Kubernetes cluster (for k8s deployment)

### Local Development
```bash
# Start services
docker-compose up --build

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Building Individual Images
```bash
# Frontend
docker build -t voting-frontend ./frontend

# Backend
docker build -t voting-backend ./backend

# Worker
docker build -t voting-worker ./worker
```

## Features

- Real-time vote processing
- Duplicate vote prevention
- Live results updates
- Scalable microservices architecture
- Multi-language implementation (Python, Node.js, C#)
- Container-ready deployment
- Kubernetes orchestration support

## Ports

- Frontend: 5000
- Backend: 4000
- Redis: 6379
- PostgreSQL: 5432

## Technology Stack

- **Frontend**: Python 3.9, Flask
- **Backend**: Node.js 16, Express
- **Worker**: .NET 6.0
- **Database**: PostgreSQL 15
- **Cache**: Redis Alpine
- **Containerization**: Docker
- **Orchestration**: Kubernetes
