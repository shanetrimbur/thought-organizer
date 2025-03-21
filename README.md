# Thought Organizer

A comprehensive knowledge management and project tracking system designed for creative polymaths. Thought Organizer helps you organize your thoughts, track projects, and maintain documentation in a seamless, integrated environment.

## Features

- **Knowledge Management**: Organize and connect your ideas using Logseq
- **Project Tracking**: Monitor progress and deadlines with an intuitive interface
- **AI Feedback**: Get insights and suggestions for improvement
- **Calendar Integration**: Stay on top of deadlines and tasks
- **Documentation**: Create comprehensive documentation using Docusaurus
- **Project Management**: Track and manage projects using Plane
- **Web Interface**: Access your projects and tasks through a modern web interface

## Installation

### Prerequisites

- Fedora Linux (or compatible distribution)
- Python 3.x
- Node.js and npm
- Docker and Docker Compose
- Flatpak

### Quick Start

1. Clone the repository:
```bash
git clone https://github.com/shanetrimbur/thought-organizer.git
cd thought-organizer
```

2. Make the installation script executable:
```bash
chmod +x ThoughtOrganizer.sh
```

3. Run the installation script:
```bash
./ThoughtOrganizer.sh
```

## Usage

### Starting Thought Organizer

After installation, you can start Thought Organizer in two ways:

1. Using the command line:
```bash
thought-organizer
```

2. Using the desktop shortcut (if installed)

### Project Tracker

Use the project tracker directly from the command line:

```bash
project-tracker list-projects
project-tracker add-project "My Project" "Description" "Category"
project-tracker add-task "Task Title" "Description" 1
```

### Web Interface

Access the web interface at `http://localhost:5000` to manage your projects and tasks through a modern, user-friendly interface.

## Directory Structure

```
/opt/thought-organizer/           # System-wide installation
~/.local/share/thought-organizer/ # User-specific data
~/.config/thought-organizer/      # User-specific configuration
~/Projects/                       # Main projects directory
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Logseq](https://logseq.com/) for knowledge management
- [Plane](https://plane.so/) for project management
- [Docusaurus](https://docusaurus.io/) for documentation
- All other open-source tools and libraries used in this project 