# Contributing to Patroni Railway Template

Thank you for your interest in contributing to the Patroni Railway Template! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project follows a Code of Conduct that all contributors are expected to adhere to:

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/patroni-railway-template.git
   cd patroni-railway-template
   ```
3. **Add the upstream repository**:
   ```bash
   git remote add upstream https://github.com/ORIGINAL-OWNER/patroni-railway-template.git
   ```

## Development Setup

### Prerequisites

- Docker and Docker Compose
- Git
- A text editor or IDE
- Basic knowledge of PostgreSQL, Patroni, and Docker

### Local Testing Environment

1. Start the local cluster:
   ```bash
   chmod +x scripts/quick-start.sh
   ./scripts/quick-start.sh
   ```

2. Verify everything is working:
   ```bash
   docker-compose ps
   docker-compose logs -f
   ```

## Making Changes

### Branch Naming Convention

- `feature/` - New features (e.g., `feature/add-ssl-support`)
- `fix/` - Bug fixes (e.g., `fix/haproxy-health-check`)
- `docs/` - Documentation updates (e.g., `docs/update-readme`)
- `refactor/` - Code refactoring (e.g., `refactor/patroni-config`)

### Creating a Branch

```bash
git checkout -b feature/your-feature-name
```

### Coding Standards

#### Dockerfile

- Use official base images when possible
- Pin specific versions (avoid `latest` tag)
- Minimize layers by combining RUN commands
- Add health checks
- Use multi-stage builds when appropriate

Example:
```dockerfile
FROM postgres:16-alpine

RUN apk add --no-cache \
    python3 \
    py3-pip \
    && pip3 install patroni[etcd]==3.2.1
```

#### Shell Scripts

- Use `#!/bin/bash` or `#!/bin/sh` shebang
- Use `set -e` to exit on errors
- Add comments for complex logic
- Use meaningful variable names
- Quote variables to prevent word splitting

Example:
```bash
#!/bin/bash
set -e

NODE_NAME="${PATRONI_NAME}"
echo "Starting node: ${NODE_NAME}"
```

#### Configuration Files

- Use consistent indentation (2 spaces for YAML)
- Add comments explaining non-obvious settings
- Group related settings together
- Use environment variables for dynamic values

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(patroni): add SSL/TLS support

- Add SSL certificate generation
- Update Patroni configuration for SSL
- Update documentation

Closes #123
```

```
fix(haproxy): correct health check endpoint

The health check was using the wrong port, causing false negatives.

Fixes #456
```

## Testing

### Required Tests

Before submitting a pull request, ensure:

1. **Local cluster starts successfully**:
   ```bash
   ./scripts/quick-start.sh
   ```

2. **All services are healthy**:
   ```bash
   docker-compose ps
   ```

3. **Cluster status is correct**:
   ```bash
   docker-compose exec patroni1 patronictl -c /tmp/patroni.yml list
   ```

4. **Failover works**:
   ```bash
   ./scripts/test-failover.sh
   ```

5. **Replication is working**:
   ```bash
   # Create test data on primary
   psql "postgresql://postgres:testpassword123@localhost:5432/postgres" -c "CREATE TABLE test (id INT);"
   
   # Verify on replica
   psql "postgresql://postgres:testpassword123@localhost:5433/postgres" -c "SELECT * FROM test;"
   ```

### Test Checklist

- [ ] Services build without errors
- [ ] etcd cluster forms successfully
- [ ] Patroni cluster initializes
- [ ] Primary is elected
- [ ] Replication is working
- [ ] HAProxy routes traffic correctly
- [ ] Failover completes in < 60 seconds
- [ ] Data persists across restarts
- [ ] Health checks pass
- [ ] Documentation is updated

## Submitting Changes

### Pull Request Process

1. **Update your fork**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Push your changes**:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request** on GitHub

4. **Fill out the PR template** with:
   - Description of changes
   - Related issues
   - Testing performed
   - Screenshots (if applicable)

### PR Review Process

- At least one maintainer must approve
- All CI checks must pass
- No merge conflicts
- Documentation must be updated
- Tests must pass

### After Your PR is Merged

1. **Delete your branch**:
   ```bash
   git branch -d feature/your-feature-name
   git push origin --delete feature/your-feature-name
   ```

2. **Update your fork**:
   ```bash
   git checkout main
   git pull upstream main
   git push origin main
   ```

## Reporting Issues

### Before Creating an Issue

1. **Search existing issues** to avoid duplicates
2. **Test with the latest version**
3. **Gather relevant information**:
   - Operating system
   - Docker version
   - Error messages
   - Steps to reproduce

### Issue Template

```markdown
**Description**
A clear description of the issue.

**Steps to Reproduce**
1. Step one
2. Step two
3. Step three

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Environment**
- OS: [e.g., Ubuntu 22.04]
- Docker version: [e.g., 24.0.0]
- Docker Compose version: [e.g., 2.20.0]

**Logs**
```
Paste relevant logs here
```

**Additional Context**
Any other relevant information.
```

## Areas for Contribution

We welcome contributions in these areas:

### High Priority

- [ ] SSL/TLS support
- [ ] Automated backup solution
- [ ] Monitoring integration (Prometheus/Grafana)
- [ ] Performance tuning guide
- [ ] CI/CD pipeline

### Medium Priority

- [ ] Additional load balancer options (PgBouncer, PgPool)
- [ ] Multi-region deployment guide
- [ ] Disaster recovery procedures
- [ ] Migration guide from standalone PostgreSQL
- [ ] Kubernetes deployment option

### Low Priority

- [ ] Additional documentation
- [ ] Example applications
- [ ] Video tutorials
- [ ] Blog posts
- [ ] Community templates

## Questions?

If you have questions:

1. Check the [README](README.md) and [DEPLOYMENT](DEPLOYMENT.md) guides
2. Search existing issues
3. Ask in GitHub Discussions
4. Join the Railway Discord community

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing! 🎉
