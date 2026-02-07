# Smart Shopper - PySpark Project for Databricks

A modern PySpark project template designed for Databricks environments, following best practices for structure, testing, and deployment.

## 🚀 Project Structure

```
smart_shopper/
├── pyproject.toml           # Project configuration and dependencies
├── .gitignore              # Git ignore rules
├── databricks/             # Databricks-specific files
│   ├── notebooks/          # Databricks notebooks
│   └── workflows/          # Workflow configurations
├── src/smart_shopper/      # Source code
│   ├── config/            # Configuration management
│   ├── utils/             # Helper functions
│   ├── transformations/   # Data transformation logic
│   └── jobs/              # Job entry points
├── tests/                 # Unit and integration tests
├── data/                  # Local data directories
└── docs/                  # Documentation
```

## 📋 Prerequisites

- Python 3.9 or higher
- Access to a Databricks workspace
- Git

## 🛠️ Setup

### Local Development

1. **Clone the repository**
```bash
git clone https://github.com/niladriforu/smart_shopper.git
cd smart_shopper
```

2. **Create a virtual environment**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. **Install dependencies**
```bash
pip install -e ".[dev]"
```

4. **Configure environment variables**
```bash
cp .env.example .env
# Edit .env with your configuration
```

### Databricks Setup

1. **Connect via Databricks Repos**
   - Go to Repos in your Databricks workspace
   - Click "Add Repo"
   - Enter the repository URL
   - Clone the repository

2. **Install package in Databricks**
   - Upload the project or use Repos
   - Install via notebook: `%pip install -e .`

## 🧪 Testing

Run tests locally:
```bash
pytest tests/
```

Run tests with coverage:
```bash
pytest --cov=src/smart_shopper tests/
```

## 📚 Usage

### Running Notebooks

1. Navigate to `databricks/notebooks/`
2. Open the desired notebook in Databricks
3. Attach to a cluster
4. Run the notebook cells

### Running Jobs

```python
from smart_shopper.jobs.sample_job import main

main()
```

## 🔧 Development

### Code Formatting

```bash
black src/ tests/
```

### Linting

```bash
ruff check src/ tests/
```

### Type Checking

```bash
mypy src/
```

## 📦 Dependencies

Core dependencies:
- **PySpark**: Distributed data processing
- **Delta Lake**: ACID transactions on data lakes
- **Pandas**: Data manipulation
- **Pydantic**: Data validation

Development dependencies:
- **pytest**: Testing framework
- **chispa**: PySpark test helpers
- **black**: Code formatter
- **ruff**: Fast Python linter

## 🚀 Deployment

See [docs/deployment.md](docs/deployment.md) for detailed deployment instructions.

### Quick Deploy

1. **Push to main branch**
2. **Databricks Repos sync** automatically
3. **Configure and run workflows** from `databricks/workflows/`

## 📖 Documentation

- [Architecture](docs/architecture.md) - System design and architecture
- [Setup Guide](docs/setup.md) - Detailed setup instructions
- [Deployment](docs/deployment.md) - Deployment strategies

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Write/update tests
4. Submit a pull request

## 📄 License

[Add your license here]

## 👥 Contact

[Add contact information here]