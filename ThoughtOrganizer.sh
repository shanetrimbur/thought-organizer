#!/bin/bash

# Quantum Brain: Complete Setup Script for Fedora
# This script sets up the knowledge management system and tracker

# Define installation paths (standard Linux file hierarchy)
QUANTUM_BRAIN_HOME="/opt/quantum-brain"  # System-wide installation
USER_DATA_DIR="$HOME/.local/share/quantum-brain"  # User-specific data
USER_CONFIG_DIR="$HOME/.config/quantum-brain"  # User-specific configuration
USER_PROJECTS_DIR="$HOME/Projects"  # Main projects directory

# Define color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║  ${GREEN}Quantum Brain${BLUE} - Knowledge Management & Tracking System  ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}This script should NOT be run as root.${NC}"
    echo -e "${YELLOW}It will use sudo for operations that require elevated privileges.${NC}"
    exit 1
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    echo -e "${RED}This script requires sudo, which is not installed.${NC}"
    echo -e "${YELLOW}Please install sudo and try again.${NC}"
    exit 1
fi

# Check if running on Fedora
if ! grep -q "Fedora" /etc/os-release; then
    echo -e "${YELLOW}Warning: This script is designed for Fedora.${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create directory structure
echo -e "${BLUE}Creating directory structure...${NC}"
sudo mkdir -p "$QUANTUM_BRAIN_HOME"
sudo chown "$USER:$USER" "$QUANTUM_BRAIN_HOME"
mkdir -p "$USER_DATA_DIR"/{knowledge-base,projects,documentation,visualizations,meta,data,calendar,feedback,tracker}
mkdir -p "$USER_CONFIG_DIR"/{logseq,plane,docusaurus,tracker}
mkdir -p "$USER_PROJECTS_DIR"

# Install dependencies
echo -e "${BLUE}Installing system dependencies...${NC}"
sudo dnf update -y
sudo dnf install -y git nodejs npm python3 python3-pip docker docker-compose flatpak \
    evolution evolution-ews libnotify chromium httpd mod_wsgi python3-flask \
    python3-pandas python3-matplotlib python3-scikit-learn && echo -e "${GREEN}Dependencies installed successfully.${NC}" || echo -e "${RED}Some dependencies failed to install.${NC}"

# Enable and start Docker
echo -e "${BLUE}Setting up Docker...${NC}"
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker "$USER"
echo -e "${YELLOW}NOTE: You may need to log out and back in for Docker permissions to take effect${NC}"

# Install Python dependencies
echo -e "${BLUE}Installing Python packages...${NC}"
pip install --user nltk scikit-learn pandas numpy matplotlib flask schedule requests openai python-crontab icalendar && echo -e "${GREEN}Python packages installed successfully.${NC}" || echo -e "${RED}Some Python packages failed to install.${NC}"

# Download NLTK data
echo -e "${BLUE}Downloading NLTK data...${NC}"
python3 -c "import nltk; nltk.download('punkt'); nltk.download('stopwords'); nltk.download('wordnet')" && echo -e "${GREEN}NLTK data downloaded successfully.${NC}" || echo -e "${RED}Failed to download NLTK data.${NC}"

# Install Quantum Brain core system
echo -e "${BLUE}Setting up Quantum Brain...${NC}"

# Clone repository or copy files (simplified here)
cd "$QUANTUM_BRAIN_HOME"
git init
cat > README.md << EOL
# Quantum Brain

A comprehensive knowledge management and project tracking system designed for creative polymaths.
EOL

# Install Logseq through Flatpak
echo -e "${BLUE}Installing Logseq...${NC}"
flatpak install -y flathub com.logseq.Logseq && echo -e "${GREEN}Logseq installed successfully.${NC}" || echo -e "${RED}Failed to install Logseq.${NC}"

# Setup Plane (project management)
echo -e "${BLUE}Setting up Plane...${NC}"
cd "$USER_DATA_DIR/projects"
git clone https://github.com/makeplane/plane.git
cd plane
# Create docker-compose.yml with a simplified configuration for Plane
cat > docker-compose.yml << 'EOL'
version: '3'
services:
  api:
    image: makeplane/plane-backend:latest
    restart: always
    ports:
      - "8000:8000"
    volumes:
      - plane_backend_data:/app
    environment:
      - SECRET_KEY=insecurekeyfornowchangeit
      - DEBUG=0
      - DOCKERIZED=1
      - DJANGO_SETTINGS_MODULE=plane.settings.production
      - REDIS_URL=redis://redis:6379
      - DATABASE_URL=postgres://plane:plane@db:5432/plane
      - EMAIL_HOST=mailhog
      - EMAIL_PORT=1025
      - EMAIL_FROM=no-reply@quantum-brain.local

  worker:
    image: makeplane/plane-backend:latest
    restart: always
    volumes:
      - plane_backend_data:/app
    depends_on:
      - api
      - redis
      - db
    command: python manage.py celery
    environment:
      - SECRET_KEY=insecurekeyfornowchangeit
      - DEBUG=0
      - DOCKERIZED=1
      - DJANGO_SETTINGS_MODULE=plane.settings.production
      - REDIS_URL=redis://redis:6379
      - DATABASE_URL=postgres://plane:plane@db:5432/plane

  beat-worker:
    image: makeplane/plane-backend:latest
    restart: always
    volumes:
      - plane_backend_data:/app
    depends_on:
      - api
      - redis
      - db
    command: python manage.py celery_beat
    environment:
      - SECRET_KEY=insecurekeyfornowchangeit
      - DEBUG=0
      - DOCKERIZED=1
      - DJANGO_SETTINGS_MODULE=plane.settings.production
      - REDIS_URL=redis://redis:6379
      - DATABASE_URL=postgres://plane:plane@db:5432/plane

  frontend:
    image: makeplane/plane-frontend:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_BASE_URL=http://localhost:8000

  db:
    image: postgres:15.2-alpine
    restart: always
    volumes:
      - plane_db_data:/var/lib/postgresql/data/
    environment:
      - POSTGRES_USER=plane
      - POSTGRES_PASSWORD=plane
      - POSTGRES_DB=plane

  redis:
    image: redis:6.2.7-alpine
    restart: always
    volumes:
      - plane_redis_data:/data

  mailhog:
    image: mailhog/mailhog
    restart: always
    ports:
      - "8025:8025"
      - "1025:1025"

volumes:
  plane_backend_data:
  plane_db_data:
  plane_redis_data:
EOL

# Setup Docusaurus for documentation
echo -e "${BLUE}Setting up Docusaurus...${NC}"
cd "$USER_DATA_DIR/documentation"
npx create-docusaurus@latest docs-site classic --typescript

# Create Project Tracker & Reminder System
echo -e "${BLUE}Creating project tracker and reminder system...${NC}"
cd "$USER_DATA_DIR/tracker"

# Create the tracker Python script
cat > project_tracker.py << 'EOL'
#!/usr/bin/env python3

import os
import json
import datetime
import time
import subprocess
import schedule
import sys
import argparse
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
from crontab import CronTab

# Configuration
CONFIG_DIR = os.path.expanduser("~/.config/quantum-brain/tracker")
DATA_DIR = os.path.expanduser("~/.local/share/quantum-brain/tracker")
FEEDBACK_DIR = os.path.expanduser("~/.local/share/quantum-brain/feedback")
CALENDAR_DIR = os.path.expanduser("~/.local/share/quantum-brain/calendar")
PROJECT_DIR = os.path.expanduser("~/Projects")

# Ensure directories exist
os.makedirs(CONFIG_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(FEEDBACK_DIR, exist_ok=True)
os.makedirs(CALENDAR_DIR, exist_ok=True)
os.makedirs(PROJECT_DIR, exist_ok=True)

CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
PROJECTS_FILE = os.path.join(DATA_DIR, "projects.json")
TASKS_FILE = os.path.join(DATA_DIR, "tasks.json")
CALENDAR_FILE = os.path.join(CALENDAR_DIR, "calendar.ics")
PROGRESS_FILE = os.path.join(DATA_DIR, "progress.json")

# Default configuration
DEFAULT_CONFIG = {
    "reminder_frequency": {
        "daily": True,
        "weekly": True,
        "monthly": True
    },
    "reminder_time": {
        "daily": "09:00",
        "weekly": "Mon 10:00",
        "monthly": "1 11:00"
    },
    "ai_feedback": {
        "enabled": True,
        "api_key": "",
        "provider": "openai",
        "frequency": "weekly"
    },
    "notification_methods": ["desktop", "calendar", "email"],
    "email": "",
    "progress_tracking": {
        "enabled": True,
        "metrics": ["commits", "time_spent", "tasks_completed"]
    }
}

# Load or create configuration
def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    else:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(DEFAULT_CONFIG, f, indent=2)
        return DEFAULT_CONFIG

# Save configuration
def save_config(config):
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)

# Load or create projects
def load_projects():
    if os.path.exists(PROJECTS_FILE):
        with open(PROJECTS_FILE, 'r') as f:
            return json.load(f)
    else:
        default_projects = []
        with open(PROJECTS_FILE, 'w') as f:
            json.dump(default_projects, f, indent=2)
        return default_projects

# Save projects
def save_projects(projects):
    with open(PROJECTS_FILE, 'w') as f:
        json.dump(projects, f, indent=2)

# Load or create tasks
def load_tasks():
    if os.path.exists(TASKS_FILE):
        with open(TASKS_FILE, 'r') as f:
            return json.load(f)
    else:
        default_tasks = []
        with open(TASKS_FILE, 'w') as f:
            json.dump(default_tasks, f, indent=2)
        return default_tasks

# Save tasks
def save_tasks(tasks):
    with open(TASKS_FILE, 'w') as f:
        json.dump(tasks, f, indent=2)

# Load or create progress data
def load_progress():
    if os.path.exists(PROGRESS_FILE):
        with open(PROGRESS_FILE, 'r') as f:
            return json.load(f)
    else:
        default_progress = {}
        with open(PROGRESS_FILE, 'w') as f:
            json.dump(default_progress, f, indent=2)
        return default_progress

# Save progress data
def save_progress(progress):
    with open(PROGRESS_FILE, 'w') as f:
        json.dump(progress, f, indent=2)

# Add a new project
def add_project(name, description, category, deadline=None, priority="medium", tags=None):
    projects = load_projects()
    
    new_project = {
        "id": len(projects) + 1,
        "name": name,
        "description": description,
        "category": category,
        "created_at": datetime.datetime.now().isoformat(),
        "deadline": deadline,
        "priority": priority,
        "status": "active",
        "tags": tags or [],
        "path": os.path.join(PROJECT_DIR, name),
        "progress": 0,
        "time_spent": 0,
        "last_updated": datetime.datetime.now().isoformat()
    }
    
    projects.append(new_project)
    save_projects(projects)
    
    # Create project directory
    project_path = os.path.join(PROJECT_DIR, name)
    if not os.path.exists(project_path):
        os.makedirs(project_path)
        
    print(f"Added project: {name}")
    
    # Add initial task to set up the project
    add_task(
        title=f"Set up {name} project", 
        description="Initial project setup and planning", 
        project_id=new_project["id"], 
        due_date=(datetime.datetime.now() + datetime.timedelta(days=3)).isoformat(),
        priority="high"
    )
    
    return new_project

# Add a new task
def add_task(title, description, project_id, due_date=None, priority="medium", status="todo"):
    tasks = load_tasks()
    
    new_task = {
        "id": len(tasks) + 1,
        "title": title,
        "description": description,
        "project_id": project_id,
        "created_at": datetime.datetime.now().isoformat(),
        "due_date": due_date,
        "priority": priority,
        "status": status,
        "completed_at": None,
        "time_spent": 0
    }
    
    tasks.append(new_task)
    save_tasks(tasks)
    
    print(f"Added task: {title}")
    
    # Update calendar
    generate_calendar()
    
    return new_task

# List all projects
def list_projects():
    projects = load_projects()
    
    if not projects:
        print("No projects found.")
        return
    
    print("\n--- Projects ---")
    for project in projects:
        deadline_str = f"Due: {project['deadline']}" if project.get('deadline') else "No deadline"
        status_emoji = "🟢" if project['status'] == 'active' else "🔴" if project['status'] == 'completed' else "🟡"
        print(f"{status_emoji} {project['id']}. {project['name']} ({project['category']}) - {deadline_str} - {project['progress']}% complete")

# List all tasks
def list_tasks(project_id=None, status=None):
    tasks = load_tasks()
    projects = {p["id"]: p["name"] for p in load_projects()}
    
    if project_id:
        tasks = [t for t in tasks if t["project_id"] == project_id]
    
    if status:
        tasks = [t for t in tasks if t["status"] == status]
    
    if not tasks:
        print("No tasks found with the specified criteria.")
        return
    
    print("\n--- Tasks ---")
    for task in tasks:
        due_str = f"Due: {task['due_date']}" if task.get('due_date') else "No due date"
        status_emoji = "✅" if task['status'] == 'done' else "🔄" if task['status'] == 'in_progress' else "⏳"
        project_name = projects.get(task['project_id'], "Unknown Project")
        print(f"{status_emoji} {task['id']}. [{project_name}] {task['title']} - {due_str}")

# Update project status
def update_project(project_id, status=None, progress=None, time_spent=None):
    projects = load_projects()
    
    for project in projects:
        if project["id"] == project_id:
            if status:
                project["status"] = status
            if progress is not None:
                project["progress"] = progress
            if time_spent is not None:
                project["time_spent"] = project.get("time_spent", 0) + time_spent
            
            project["last_updated"] = datetime.datetime.now().isoformat()
            save_projects(projects)
            print(f"Updated project: {project['name']}")
            
            # Update progress tracking
            update_progress_tracking(project_id, "project_update", {
                "status": status,
                "progress": progress,
                "time_spent": time_spent
            })
            
            return project
    
    print(f"Project with ID {project_id} not found.")
    return None

# Update task status
def update_task(task_id, status=None, time_spent=None):
    tasks = load_tasks()
    
    for task in tasks:
        if task["id"] == task_id:
            if status:
                task["status"] = status
                if status == "done":
                    task["completed_at"] = datetime.datetime.now().isoformat()
            if time_spent is not None:
                task["time_spent"] = task.get("time_spent", 0) + time_spent
            
            save_tasks(tasks)
            print(f"Updated task: {task['title']}")
            
            # Update project progress
            update_project_progress(task["project_id"])
            
            # Update progress tracking
            update_progress_tracking(task["project_id"], "task_update", {
                "task_id": task_id,
                "status": status,
                "time_spent": time_spent
            })
            
            return task
    
    print(f"Task with ID {task_id} not found.")
    return None

# Update project progress based on completed tasks
def update_project_progress(project_id):
    tasks = load_tasks()
    project_tasks = [t for t in tasks if t["project_id"] == project_id]
    
    if not project_tasks:
        return
    
    completed_tasks = [t for t in project_tasks if t["status"] == "done"]
    progress = int((len(completed_tasks) / len(project_tasks)) * 100)
    
    update_project(project_id, progress=progress)

# Update progress tracking
def update_progress_tracking(project_id, event_type, data):
    progress = load_progress()
    
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    
    if today not in progress:
        progress[today] = []
    
    event = {
        "timestamp": datetime.datetime.now().isoformat(),
        "project_id": project_id,
        "event_type": event_type,
        "data": data
    }
    
    progress[today].append(event)
    save_progress(progress)

# Generate progress visualization
def generate_progress_charts():
    progress = load_progress()
    projects = {p["id"]: p["name"] for p in load_projects()}
    
    if not progress:
        print("No progress data available.")
        return
    
    # Prepare data
    dates = sorted(progress.keys())
    project_progress = {}
    
    for date in dates:
        for event in progress[date]:
            project_id = event["project_id"]
            if project_id not in project_progress:
                project_progress[project_id] = {"dates": [], "progress": []}
            
            if event["event_type"] == "project_update" and "progress" in event["data"] and event["data"]["progress"] is not None:
                project_progress[project_id]["dates"].append(date)
                project_progress[project_id]["progress"].append(event["data"]["progress"])
    
    # Create charts directory
    charts_dir = os.path.join(DATA_DIR, "charts")
    os.makedirs(charts_dir, exist_ok=True)
    
    # Generate charts
    plt.figure(figsize=(12, 8))
    
    for project_id, data in project_progress.items():
        if not data["dates"] or not data["progress"]:
            continue
            
        project_name = projects.get(project_id, f"Project {project_id}")
        plt.plot(data["dates"], data["progress"], marker='o', label=project_name)
    
    plt.title("Project Progress Over Time")
    plt.xlabel("Date")
    plt.ylabel("Progress (%)")
    plt.legend()
    plt.grid(True)
    plt.xticks(rotation=45)
    plt.tight_layout()
    
    chart_path = os.path.join(charts_dir, "progress_chart.png")
    plt.savefig(chart_path)
    print(f"Progress chart saved to: {chart_path}")
    
    # Time spent chart
    time_spent = {}
    
    for project_id in project_progress.keys():
        project_name = projects.get(project_id, f"Project {project_id}")
        time_spent[project_name] = 0
        
        for date in progress:
            for event in progress[date]:
                if event["project_id"] == project_id and "time_spent" in event["data"] and event["data"]["time_spent"]:
                    time_spent[project_name] += event["data"]["time_spent"]
    
    if time_spent:
        plt.figure(figsize=(10, 6))
        projects_names = list(time_spent.keys())
        times = list(time_spent.values())
        
        plt.bar(projects_names, times)
        plt.title("Time Spent per Project")
        plt.xlabel("Project")
        plt.ylabel("Time (hours)")
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        time_chart_path = os.path.join(charts_dir, "time_chart.png")
        plt.savefig(time_chart_path)
        print(f"Time chart saved to: {time_chart_path}")

# Generate AI feedback on projects
def generate_ai_feedback():
    config = load_config()
    
    if not config["ai_feedback"]["enabled"] or not config["ai_feedback"]["api_key"]:
        print("AI feedback is disabled or API key is not set.")
        return
    
    try:
        import openai
        
        projects = load_projects()
        tasks = load_tasks()
        progress = load_progress()
        
        # Prepare data for AI
        project_data = []
        
        for project in projects:
            project_tasks = [t for t in tasks if t["project_id"] == project["id"]]
            completed_tasks = [t for t in project_tasks if t["status"] == "done"]
            
            project_info = {
                "name": project["name"],
                "description": project["description"],
                "category": project["category"],
                "created_at": project["created_at"],
                "deadline": project["deadline"],
                "status": project["status"],
                "progress": project["progress"],
                "tasks_total": len(project_tasks),
                "tasks_completed": len(completed_tasks),
                "last_updated": project["last_updated"]
            }
            
            project_data.append(project_info)
        
        # Get AI feedback
        openai.api_key = config["ai_feedback"]["api_key"]
        
        for project_info in project_data:
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a helpful project management assistant. Analyze the project data and provide constructive feedback, suggestions for improvement, and next steps."},
                    {"role": "user", "content": f"Please analyze this project and provide feedback: {json.dumps(project_info, indent=2)}"}
                ]
            )
            
            feedback = response.choices[0].message.content
            
            # Save feedback
            feedback_file = os.path.join(FEEDBACK_DIR, f"{project_info['name'].replace(' ', '_')}_feedback_{datetime.datetime.now().strftime('%Y%m%d')}.txt")
            
            with open(feedback_file, 'w') as f:
                f.write(f"AI Feedback for: {project_info['name']}\n")
                f.write(f"Generated on: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
                f.write(feedback)
            
            print(f"Generated AI feedback for: {project_info['name']}")
    
    except Exception as e:
        print(f"Error generating AI feedback: {e}")

# Generate calendar with upcoming tasks and deadlines
def generate_calendar():
    try:
        from icalendar import Calendar, Event, vDatetime
        
        projects = load_projects()
        tasks = load_tasks()
        
        cal = Calendar()
        cal.add('prodid', '-//Quantum Brain//Project Tracker//EN')
        cal.add('version', '2.0')
        
        # Add project deadlines
        for project in projects:
            if project.get("deadline") and project["status"] == "active":
                try:
                    deadline_date = datetime.datetime.fromisoformat(project["deadline"])
                    
                    event = Event()
                    event.add('summary', f"DEADLINE: {project['name']}")
                    event.add('description', project["description"])
                    event.add('dtstart', vDatetime(deadline_date))
                    event.add('dtend', vDatetime(deadline_date + datetime.timedelta(hours=1)))
                    event.add('priority', 1)  # High priority
                    
                    cal.add_component(event)
                except (ValueError, TypeError):
                    pass  # Skip if date format is invalid
        
        # Add tasks with due dates
        for task in tasks:
            if task.get("due_date") and task["status"] != "done":
                try:
                    due_date = datetime.datetime.fromisoformat(task["due_date"])
                    
                    project_name = "Unknown Project"
                    for project in projects:
                        if project["id"] == task["project_id"]:
                            project_name = project["name"]
                            break
                    
                    event = Event()
                    event.add('summary', f"TASK: {task['title']} ({project_name})")
                    event.add('description', task["description"])
                    event.add('dtstart', vDatetime(due_date))
                    event.add('dtend', vDatetime(due_date + datetime.timedelta(hours=1)))
                    
                    # Set priority
                    if task["priority"] == "high":
                        event.add('priority', 1)
                    elif task["priority"] == "medium":
                        event.add('priority', 5)
                    else:
                        event.add('priority', 9)
                    
                    cal.add_component(event)
                except (ValueError, TypeError):
                    pass  # Skip if date format is invalid
        
        # Add reminder events
        config = load_config()
        
        if config["reminder_frequency"]["daily"]:
            try:
                daily_time = datetime.datetime.strptime(config["reminder_time"]["daily"], "%H:%M").time()
                
                # Add daily reminder for the next 30 days
                for i in range(30):
                    reminder_date = datetime.datetime.now().replace(
                        hour=daily_time.hour, 
                        minute=daily_time.minute, 
                        second=0, 
                        microsecond=0
                    ) + datetime.timedelta(days=i)
                    
                    event = Event()
                    event.add('summary', "Daily Project Review")
                    event.add('description', "Review your active projects and tasks for the day")
                    event.add('dtstart', vDatetime(reminder_date))
                    event.add('dtend', vDatetime(reminder_date + datetime.timedelta(minutes=15)))
                    event.add('priority', 5)
                    
                    cal.add_component(event)
            except (ValueError, TypeError):
                pass
        
        # Save calendar file
        with open(CALENDAR_FILE, 'wb') as f:
            f.write(cal.to_ical())
        
        print(f"Calendar generated: {CALENDAR_FILE}")
        
        # Try to add to Evolution
        try:
            subprocess.run(["evolution", f"calendar:///?source=file://{CALENDAR_FILE}"], 
                           stdout=subprocess.DEVNULL, 
                           stderr=subprocess.DEVNULL)
        except:
            pass
    
    except Exception as e:
        print(f"Error generating calendar: {e}")

# Setup reminder cron jobs
def setup_reminders():
    config = load_config()
    
    try:
        # Get current user's crontab
        cron = CronTab(user=True)
        
        # Remove existing quantum-brain reminders
        for job in cron.find_comment("quantum-brain-reminder"):
            cron.remove(job)
        
        # Set up daily reminder
        if config["reminder_frequency"]["daily"]:
            try:
                daily_time = datetime.datetime.strptime(config["reminder_time"]["daily"], "%H:%M").time()
                
                job = cron.new(command=f"XDG_RUNTIME_DIR=/run/user/$(id -u) DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus notify-send 'Quantum Brain' 'Daily project review reminder' -i appointment", comment="quantum-brain-reminder")
                job.setall(f"{daily_time.minute} {daily_time.hour} * * *")
            except (ValueError, TypeError):
                pass
        
        # Set up weekly reminder
        if config["reminder_frequency"]["weekly"]:
            try:
                weekly_time = config["reminder_time"]["weekly"].split()
                day_map = {"Mon": 1, "Tue": 2, "Wed": 3, "Thu": 4, "Fri": 5, "Sat": 6, "Sun": 0}
                day = day_map.get(weekly_time[0], 1)
                time_parts = weekly_time[1].split(":")
                
                job = cron.new(command=f"XDG_RUNTIME_DIR=/run/user/$(id -u) DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus notify-send 'Quantum Brain' 'Weekly project review reminder' -i appointment", comment="quantum-brain-reminder")
                job.setall(f"{time_parts[1]} {time_parts[0]} * * {day}")
            except (ValueError, TypeError, IndexError):
                pass
        
        # Set up monthly reminder
        if config["reminder_frequency"]["monthly"]:
            try:
                monthly_time = config["reminder_time"]["monthly"].split()
                day_of_month = int(monthly_time[0])
                time_parts = monthly_time[1].split(":")
                
                job = cron.new(command=f"XDG_RUNTIME_DIR=/run/user/$(id -u) DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus notify-send 'Quantum Brain' 'Monthly project review reminder' -i appointment", comment="quantum-brain-reminder")
                job.setall(f"{time_parts[1]} {time_parts[0]} {day_of_month} * *")
            except (ValueError, TypeError, IndexError):
                pass
        
        # Save crontab
        cron.write()
        print("Reminders set up successfully.")
    
    except Exception as e:
        print(f"Error setting up reminders: {e}")

# Send notification
def send_notification(title, message):
    try:
        subprocess.run(["notify-send", title, message])
        print(f"Notification sent: {title} - {message}")
    except Exception as e:
        print(f"Error sending notification: {e}")

# Run daily tasks
def daily_tasks():
    print("Running daily tasks...")
    
    # Check for approaching deadlines
    projects = load_projects()
    tasks = load_tasks()
    
    today = datetime.datetime.now().date()
    
    # Check project deadlines
    for project in projects:
        if project["status"] != "active" or not project.get("deadline"):
            continue
        
        try:
            deadline = datetime.datetime.fromisoformat(project["deadline"]).date()
            days_left = (deadline - today).days
            
            if 0 <= days_left <= 3:
                send_notification(
                    "Project Deadline Approaching",
                    f"{project['name']} is due in {days_left} days!"
                )
        except (ValueError, TypeError):
            pass
    
    # Check task due dates
    for task in tasks:
        if task["status"] == "done" or not task.get("due_date"):
            continue
        
        try:
            due_date = datetime.datetime.fromisoformat(task["due_date"]).date()
            days_left = (due_date - today).days
            
            if 0 <= days_left <= 2:
                project_name = "Unknown Project"
                for project in projects:
                    if project["id"] == task["project_id"]:
                        project_name = project["name"]
                        break
                
                send_notification(
                    "Task Due Soon",
                    f"Task '{task['title']}' for {project_name} is due in {days_left} days!"
                )
        except (ValueError, TypeError):
            pass
    
    # Update calendar
    generate_calendar()

# Run weekly tasks
def weekly_tasks():
    print("Running weekly tasks...")
    
    # Generate progress charts
    generate_progress_charts()
    
    # Get AI feedback if enabled
    config = load_config()
    if config["ai_feedback"]["enabled"] and config["ai_feedback"]["frequency"] == "weekly":
        generate_ai_feedback()
    
    # Check for stale projects
    projects = load_projects()
    today = datetime.datetime.now()
    
    for project in projects:
        if project["status"] != "active":
            continue
        
        try:
            last_updated = datetime.datetime.fromisoformat(project["last_updated"])
            days_since_update = (today - last_updated).days
            
            if days_since_update > 7:
                send_notification(
                    "Stale Project Alert",
                    f"{project['name']} hasn't been updated in {days_since_update} days!"
                )
        except (ValueError, TypeError):
            pass

# Run monthly tasks
def monthly_tasks():
    print("Running monthly tasks...")
    
    # Generate comprehensive reports
    projects = load_projects()
    tasks = load_tasks()
    progress = load_progress()
    
    report_dir = os.path.join(DATA_DIR, "reports")
    os.makedirs(report_dir, exist_ok=True)
    
    report_file = os.path.join(report_dir, f"monthly_report_{datetime.datetime.now().strftime('%Y_%m')}.txt")
    
    with open(report_file, 'w') as f:
        f.write(f"Quantum Brain Monthly Report - {datetime.datetime.now().strftime('%B %Y')}\n")
        f.write("=" * 80 + "\n\n")
        
        # Project summary
        f.write("PROJECT SUMMARY\n")
        f.write("-" * 80 + "\n")
        
        active_projects = [p for p in projects if p["status"] == "active"]
        completed_projects = [p for p in projects if p["status"] == "completed"]
        
        f.write(f"Total Projects: {len(projects)}\n")
        f.write(f"Active Projects: {len(active_projects)}\n")
        f.write(f"Completed Projects: {len(completed_projects)}\n\n")
        
        # Active projects
        f.write("ACTIVE PROJECTS\n")
        for project in active_projects:
            project_tasks = [t for t in tasks if t["project_id"] == project["id"]]
            completed_tasks = [t for t in project_tasks if t["status"] == "done"]
            
            f.write(f"- {project['name']} ({project['category']})\n")
            f.write(f"  Progress: {project['progress']}%\n")
            f.write(f"  Tasks: {len(completed_tasks)}/{len(project_tasks)} completed\n")
            
            if project.get("deadline"):
                try:
                    deadline = datetime.datetime.fromisoformat(project["deadline"]).date()
                    days_left = (deadline - datetime.datetime.now().date()).days
                    f.write(f"  Deadline: {deadline} ({days_left} days left)\n")
                except (ValueError, TypeError):
                    f.write(f"  Deadline: {project['deadline']}\n")
            
            f.write("\n")
        
        # Recently completed projects
        last_month = datetime.datetime.now() - datetime.timedelta(days=30)
        recent_completed = [
            p for p in completed_projects 
            if datetime.datetime.fromisoformat(p.get("last_updated", "2000-01-01")) > last_month
        ]
        
        if recent_completed:
            f.write("\nRECENTLY COMPLETED PROJECTS\n")
            for project in recent_completed:
                f.write(f"- {project['name']} ({project['category']})\n")
                f.write(f"  Completed on: {project['last_updated'].split('T')[0]}\n")
            f.write("\n")
        
        # Get AI feedback if enabled
        config = load_config()
        if config["ai_feedback"]["enabled"] and config["ai_feedback"]["frequency"] == "monthly":
            generate_ai_feedback()
    
    print(f"Monthly report generated: {report_file}")
    
    send_notification(
        "Monthly Project Report",
        f"Your monthly project report is ready. View it at: {report_file}"
    )

# Run schedule
def run_schedule():
    schedule.every().day.at("09:00").do(daily_tasks)
    schedule.every().monday.at("10:00").do(weekly_tasks)
    schedule.every(30).days.at("11:00").do(monthly_tasks)
    
    print("Scheduler started. Press Ctrl+C to exit.")
    
    while True:
        schedule.run_pending()
        time.sleep(60)

# CLI interface
def main():
    parser = argparse.ArgumentParser(description="Quantum Brain Project Tracker")
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    # add project command
    add_project_parser = subparsers.add_parser("add-project", help="Add a new project")
    add_project_parser.add_argument("name", help="Project name")
    add_project_parser.add_argument("description", help="Project description")
    add_project_parser.add_argument("category", help="Project category")
    add_project_parser.add_argument("--deadline", help="Project deadline (YYYY-MM-DD)")
    add_project_parser.add_argument("--priority", choices=["low", "medium", "high"], default="medium", help="Project priority")
    add_project_parser.add_argument("--tags", help="Comma-separated list of tags")
    
    # add task command
    add_task_parser = subparsers.add_parser("add-task", help="Add a new task")
    add_task_parser.add_argument("title", help="Task title")
    add_task_parser.add_argument("description", help="Task description")
    add_task_parser.add_argument("project_id", type=int, help="Project ID")
    add_task_parser.add_argument("--due", help="Due date (YYYY-MM-DD)")
    add_task_parser.add_argument("--priority", choices=["low", "medium", "high"], default="medium", help="Task priority")
    
    # list projects command
    subparsers.add_parser("list-projects", help="List all projects")
    
    # list tasks command
    list_tasks_parser = subparsers.add_parser("list-tasks", help="List tasks")
    list_tasks_parser.add_argument("--project", type=int, help="Filter by project ID")
    list_tasks_parser.add_argument("--status", choices=["todo", "in_progress", "done"], help="Filter by status")
    
    # update project command
    update_project_parser = subparsers.add_parser("update-project", help="Update project status")
    update_project_parser.add_argument("project_id", type=int, help="Project ID")
    update_project_parser.add_argument("--status", choices=["active", "on_hold", "completed"], help="New status")
    update_project_parser.add_argument("--progress", type=int, help="Progress percentage (0-100)")
    update_project_parser.add_argument("--time", type=float, help="Time spent in hours")
    
    # update task command
    update_task_parser = subparsers.add_parser("update-task", help="Update task status")
    update_task_parser.add_argument("task_id", type=int, help="Task ID")
    update_task_parser.add_argument("--status", choices=["todo", "in_progress", "done"], help="New status")
    update_task_parser.add_argument("--time", type=float, help="Time spent in hours")
    
    # generate calendar command
    subparsers.add_parser("generate-calendar", help="Generate calendar with deadlines and tasks")
    
    # generate charts command
    subparsers.add_parser("generate-charts", help="Generate progress charts")
    
    # generate AI feedback command
    subparsers.add_parser("generate-feedback", help="Generate AI feedback for projects")
    
    # setup reminders command
    subparsers.add_parser("setup-reminders", help="Setup reminder cron jobs")
    
    # run scheduler command
    subparsers.add_parser("run-scheduler", help="Run scheduler in the foreground")
    
    args = parser.parse_args()
    
    if args.command == "add-project":
        tags = args.tags.split(",") if args.tags else []
        add_project(args.name, args.description, args.category, args.deadline, args.priority, tags)
    
    elif args.command == "add-task":
        add_task(args.title, args.description, args.project_id, args.due, args.priority)
    
    elif args.command == "list-projects":
        list_projects()
    
    elif args.command == "list-tasks":
        list_tasks(args.project, args.status)
    
    elif args.command == "update-project":
        update_project(args.project_id, args.status, args.progress, args.time)
    
    elif args.command == "update-task":
        update_task(args.task_id, args.status, args.time)
    
    elif args.command == "generate-calendar":
        generate_calendar()
    
    elif args.command == "generate-charts":
        generate_progress_charts()
    
    elif args.command == "generate-feedback":
        generate_ai_feedback()
    
    elif args.command == "setup-reminders":
        setup_reminders()
    
    elif args.command == "run-scheduler":
        run_schedule()
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
EOL

chmod +x project_tracker.py

# Create a simple web interface for the tracker
cat > web_interface.py << 'EOL'
#!/usr/bin/env python3

from flask import Flask, render_template, request, redirect, url_for, jsonify
import os
import json
import subprocess
import datetime

app = Flask(__name__)

# Configuration
CONFIG_DIR = os.path.expanduser("~/.config/quantum-brain/tracker")
DATA_DIR = os.path.expanduser("~/.local/share/quantum-brain/tracker")
FEEDBACK_DIR = os.path.expanduser("~/.local/share/quantum-brain/feedback")
CALENDAR_DIR = os.path.expanduser("~/.local/share/quantum-brain/calendar")
CHARTS_DIR = os.path.join(DATA_DIR, "charts")

# Ensure directories exist
os.makedirs(CONFIG_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(FEEDBACK_DIR, exist_ok=True)
os.makedirs(CALENDAR_DIR, exist_ok=True)
os.makedirs(CHARTS_DIR, exist_ok=True)

CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
PROJECTS_FILE = os.path.join(DATA_DIR, "projects.json")
TASKS_FILE = os.path.join(DATA_DIR, "tasks.json")

def load_projects():
    if os.path.exists(PROJECTS_FILE):
        with open(PROJECTS_FILE, 'r') as f:
            return json.load(f)
    return []

def save_projects(projects):
    with open(PROJECTS_FILE, 'w') as f:
        json.dump(projects, f, indent=2)

def load_tasks():
    if os.path.exists(TASKS_FILE):
        with open(TASKS_FILE, 'r') as f:
            return json.load(f)
    return []

def save_tasks(tasks):
    with open(TASKS_FILE, 'w') as f:
        json.dump(tasks, f, indent=2)

def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    return {}

def run_tracker_command(command):
    try:
        result = subprocess.run(
            ["python3", os.path.join(DATA_DIR, "project_tracker.py")] + command,
            capture_output=True,
            text=True
        )
        return result.stdout
    except Exception as e:
        return f"Error: {str(e)}"

@app.route('/')
def index():
    projects = load_projects()
    tasks = load_tasks()
    
    active_projects = [p for p in projects if p["status"] == "active"]
    completed_projects = [p for p in projects if p["status"] == "completed"]
    
    # Get tasks due soon
    today = datetime.datetime.now().date()
    soon_tasks = []
    
    for task in tasks:
        if task["status"] == "done" or not task.get("due_date"):
            continue
        
        try:
            due_date = datetime.datetime.fromisoformat(task["due_date"]).date()
            days_left = (due_date - today).days
            
            if 0 <= days_left <= 7:
                project_name = "Unknown Project"
                for project in projects:
                    if project["id"] == task["project_id"]:
                        project_name = project["name"]
                        break
                
                soon_tasks.append({
                    "id": task["id"],
                    "title": task["title"],
                    "project": project_name,
                    "due_date": task["due_date"].split('T')[0],
                    "days_left": days_left,
                    "priority": task["priority"]
                })
        except (ValueError, TypeError):
            pass
    
    # Sort by days left
    soon_tasks.sort(key=lambda x: x["days_left"])
    
    # Check for AI feedback
    feedback_files = []
    if os.path.exists(FEEDBACK_DIR):
        feedback_files = [f for f in os.listdir(FEEDBACK_DIR) if f.endswith('.txt')]
        feedback_files.sort(reverse=True)
    
    # Check for progress charts
    progress_chart = os.path.join(CHARTS_DIR, "progress_chart.png")
    time_chart = os.path.join(CHARTS_DIR, "time_chart.png")
    
    has_progress_chart = os.path.exists(progress_chart)
    has_time_chart = os.path.exists(time_chart)
    
    return render_template(
        'index.html',
        active_projects=active_projects,
        completed_projects=completed_projects,
        soon_tasks=soon_tasks,
        feedback_files=feedback_files,
        has_progress_chart=has_progress_chart,
        has_time_chart=has_time_chart
    )

@app.route('/project/<int:project_id>')
def project_detail(project_id):
    projects = load_projects()
    tasks = load_tasks()
    
    project = None
    for p in projects:
        if p["id"] == project_id:
            project = p
            break
    
    if not project:
        return redirect(url_for('index'))
    
    project_tasks = [t for t in tasks if t["project_id"] == project_id]
    todo_tasks = [t for t in project_tasks if t["status"] == "todo"]
    in_progress_tasks = [t for t in project_tasks if t["status"] == "in_progress"]
    done_tasks = [t for t in project_tasks if t["status"] == "done"]
    
    return render_template(
        'project_detail.html',
        project=project,
        todo_tasks=todo_tasks,
        in_progress_tasks=in_progress_tasks,
        done_tasks=done_tasks
    )

@app.route('/add-project', methods=['GET', 'POST'])
def add_project():
    if request.method == 'POST':
        name = request.form['name']
        description = request.form['description']
        category = request.form['category']
        deadline = request.form.get('deadline', '')
        priority = request.form.get('priority', 'medium')
        tags = request.form.get('tags', '')
        
        command = ["add-project", name, description, category]
        if deadline:
            command.extend(["--deadline", deadline])
        if priority:
            command.extend(["--priority", priority])
        if tags:
            command.extend(["--tags", tags])
        
        output = run_tracker_command(command)
        return redirect(url_for('index'))
    
    return render_template('add_project.html')

@app.route('/add-task', methods=['GET', 'POST'])
def add_task():
    if request.method == 'POST':
        title = request.form['title']
        description = request.form['description']
        project_id = int(request.form['project_id'])
        due_date = request.form.get('due_date', '')
        priority = request.form.get('priority', 'medium')
        
        command = ["add-task", title, description, str(project_id)]
        if due_date:
            command.extend(["--due", due_date])
        if priority:
            command.extend(["--priority", priority])
        
        output = run_tracker_command(command)
        return redirect(url_for('index'))
    
    projects = load_projects()
    active_projects = [p for p in projects if p["status"] == "active"]
    
    return render_template('add_task.html', projects=active_projects)

@app.route('/update-task/<int:task_id>', methods=['POST'])
def update_task(task_id):
    status = request.form.get('status', '')
    time_spent = request.form.get('time_spent', '')
    
    command = ["update-task", str(task_id)]
    if status:
        command.extend(["--status", status])
    if time_spent:
        command.extend(["--time", time_spent])
    
    output = run_tracker_command(command)
    return redirect(request.referrer or url_for('index'))

@app.route('/update-project/<int:project_id>', methods=['POST'])
def update_project(project_id):
    status = request.form.get('status', '')
    progress = request.form.get('progress', '')
    time_spent = request.form.get('time_spent', '')
    
    command = ["update-project", str(project_id)]
    if status:
        command.extend(["--status", status])
    if progress:
        command.extend(["--progress", progress])
    if time_spent:
        command.extend(["--time", time_spent])
    
    output = run_tracker_command(command)
    return redirect(request.referrer or url_for('index'))

@app.route('/feedback/<filename>')
def view_feedback(filename):
    feedback_path = os.path.join(FEEDBACK_DIR, filename)
    
    if not os.path.exists(feedback_path):
        return redirect(url_for('index'))
    
    with open(feedback_path, 'r') as f:
        content = f.read()
    
    return render_template('view_feedback.html', filename=filename, content=content)

@app.route('/generate-calendar')
def generate_calendar():
    output = run_tracker_command(["generate-calendar"])
    return redirect(url_for('index'))

@app.route('/generate-charts')
def generate_charts():
    output = run_tracker_command(["generate-charts"])
    return redirect(url_for('index'))

@app.route('/generate-feedback')
def generate_feedback():
    output = run_tracker_command(["generate-feedback"])
    return redirect(url_for('index'))

if __name__ == '__main__':
    # Create templates directory
    templates_dir = os.path.join(DATA_DIR, "templates")
    os.makedirs(templates_dir, exist_ok=True)
    
    # Create basic templates
    with open(os.path.join(templates_dir, "base.html"), 'w') as f:
        f.write('''<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}Quantum Brain Tracker{% endblock %}</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        :root {
            --color-bg: #f5f5f7;
            --color-card: #ffffff;
            --color-text: #333333;
            --color-primary: #6e56cf;
            --color-secondary: #ec4899;
            --color-accent: #38bdf8;
            --color-success: #10b981;
            --color-warning: #f59e0b;
            --color-danger: #ef4444;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--color-bg);
            color: var(--color-text);
            margin: 0;
            padding: 0;
            line-height: 1.5;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 1rem;
        }
        
        header {
            background: linear-gradient(90deg, var(--color-primary), var(--color-secondary));
            color: white;
            padding: 1rem;
            margin-bottom: 2rem;
        }
        
        header h1 {
            margin: 0;
            font-size: 1.8rem;
        }
        
        .card {
            background-color: var(--color-card);
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            padding: 1.5rem;
            margin-bottom: 1.5rem;
        }
        
        .card h2 {
            margin-top: 0;
            color: var(--color-primary);
            border-bottom: 1px solid #eee;
            padding-bottom: 0.5rem;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 1.5rem;
        }
        
        .btn {
            display: inline-block;
            padding: 0.5rem 1rem;
            background-color: var(--color-primary);
            color: white;
            border-radius: 4px;
            text-decoration: none;
            cursor: pointer;
            border: none;
            font-size: 1rem;
        }
        
        .btn-success {
            background-color: var(--color-success);
        }
        
        .btn-warning {
            background-color: var(--color-warning);
        }
        
        .btn-danger {
            background-color: var(--color-danger);
        }
        
        .btn-small {
            padding: 0.25rem 0.5rem;
            font-size: 0.875rem;
        }
        
        form {
            margin-bottom: 1rem;
        }
        
        .form-group {
            margin-bottom: 1rem;
        }
        
        label {
            display: block;
            margin-bottom: 0.5rem;
            font-weight: 500;
        }
        
        input, textarea, select {
            width: 100%;
            padding: 0.5rem;
            border: 1px solid #ccc;
            border-radius: 4px;
            font-size: 1rem;
        }
        
        .progress-bar {
            width: 100%;
            background-color: #eee;
            border-radius: 4px;
            height: 12px;
            overflow: hidden;
        }
        
        .progress-bar-fill {
            height: 100%;
            background-color: var(--color-primary);
        }
        
        .due-soon {
            color: var(--color-danger);
            font-weight: 500;
        }
        
        .task-list {
            list-style: none;
            padding: 0;
        }
        
        .task-item {
            padding: 0.75rem;
            border: 1px solid #eee;
            border-radius: 4px;
            margin-bottom: 0.5rem;
        }
        
        .priority-high {
            border-left: 4px solid var(--color-danger);
        }
        
        .priority-medium {
            border-left: 4px solid var(--color-warning);
        }
        
        .priority-low {
            border-left: 4px solid var(--color-success);
        }
        
        footer {
            margin-top: 2rem;
            text-align: center;
            padding: 1rem;
            color: #666;
            font-size: 0.875rem;
        }
    </style>
</head>
<body>
    <header>
        <div class="container">
            <h1>Quantum Brain Tracker</h1>
        </div>
    </header>
    
    <div class="container">
        {% block content %}{% endblock %}
    </div>
    
    <footer>
        <div class="container">
            Quantum Brain Project Tracking System
        </div>
    </footer>
</body>
</html>''')
    
    with open(os.path.join(templates_dir, "index.html"), 'w') as f:
        f.write('''{% extends "base.html" %}

{% block content %}
    <div class="card">
        <h2>Dashboard</h2>
        <div>
            <a href="{{ url_for('add_project') }}" class="btn">Add Project</a>
            <a href="{{ url_for('add_task') }}" class="btn">Add Task</a>
            <a href="{{ url_for('generate_calendar') }}" class="btn btn-success">Generate Calendar</a>
            <a href="{{ url_for('generate_charts') }}" class="btn btn-success">Generate Charts</a>
            <a href="{{ url_for('generate_feedback') }}" class="btn btn-success">Get AI Feedback</a>
        </div>
    </div>
    
    <div class="grid">
        <div class="card">
            <h2>Tasks Due Soon</h2>
            {% if soon_tasks %}
                <ul class="task-list">
                    {% for task in soon_tasks %}
                        <li class="task-item priority-{{ task.priority }}">
                            <div><strong>{{ task.title }}</strong></div>
                            <div>Project: {{ task.project }}</div>
                            <div>Due: {{ task.due_date }} 
                                {% if task.days_left == 0 %}
                                    <span class="due-soon">(Today!)</span>
                                {% elif task.days_left == 1 %}
                                    <span class="due-soon">(Tomorrow!)</span>
                                {% else %}
                                    <span class="due-soon">({{ task.days_left }} days left)</span>
                                {% endif %}
                            </div>
                            <div style="margin-top: 0.5rem;">
                                <form action="{{ url_for('update_task', task_id=task.id) }}" method="post" style="display:inline;">
                                    <input type="hidden" name="status" value="done">
                                    <button type="submit" class="btn btn-small btn-success">Complete</button>
                                </form>
                            </div>
                        </li>
                    {% endfor %}
                </ul>
            {% else %}
                <p>No tasks due soon.</p>
            {% endif %}
        </div>
        
        <div class="card">
            <h2>Active Projects</h2>
            {% if active_projects %}
                {% for project in active_projects %}
                    <div style="margin-bottom: 1rem;">
                        <div><strong><a href="{{ url_for('project_detail', project_id=project.id) }}">{{ project.name }}</a></strong></div>
                        <div>Category: {{ project.category }}</div>
                        <div>
                            <div class="progress-bar">
                                <div class="progress-bar-fill" style="width: {{ project.progress }}%;"></div>
                            </div>
                            <div style="text-align: right; font-size: 0.8rem;">{{ project.progress }}% complete</div>
                        </div>
                    </div>
                {% endfor %}
            {% else %}
                <p>No active projects.</p>
            {% endif %}
        </div>
        
        <div class="card">
            <h2>AI Feedback</h2>
            {% if feedback_files %}
                <ul>
                    {% for file in feedback_files %}
                        <li><a href="{{ url_for('view_feedback', filename=file) }}">{{ file }}</a></li>
                    {% endfor %}
                </ul>
            {% else %}
                <p>No AI feedback available.</p>
                <p><a href="{{ url_for('generate_feedback') }}" class="btn btn-small">Generate Feedback</a></p>
            {% endif %}
        </div>
    </div>
    
    {% if has_progress_chart or has_time_chart %}
        <div class="card">
            <h2>Progress Charts</h2>
            <div style="display: flex; flex-wrap: wrap; gap: 1rem;">
                {% if has_progress_chart %}
                    <div>
                        <h3>Project Progress</h3>
                        <img src="/charts/progress_chart.png" alt="Progress Chart" style="max-width: 100%;">
                    </div>
                {% endif %}
                
                {% if has_time_chart %}
                    <div>
                        <h3>Time Spent</h3>
                        <img src="/charts/time_chart.png" alt="Time Chart" style="max-width: 100%;">
                    </div>
                {% endif %}
            </div>
        </div>
    {% endif %}
{% endblock %}''')
    
    with open(os.path.join(templates_dir, "project_detail.html"), 'w') as f:
        f.write('''{% extends "base.html" %}

{% block title %}{{ project.name }} - Quantum Brain{% endblock %}

{% block content %}
    <div class="card">
        <h2>{{ project.name }}</h2>
        <div>
            <p><strong>Description:</strong> {{ project.description }}</p>
            <p><strong>Category:</strong> {{ project.category }}</p>
            {% if project.deadline %}
                <p><strong>Deadline:</strong> {{ project.deadline }}</p>
            {% endif %}
            <p><strong>Status:</strong> {{ project.status }}</p>
            <p><strong>Progress:</strong></p>
            <div class="progress-bar">
                <div class="progress-bar-fill" style="width: {{ project.progress }}%;"></div>
            </div>
            <div style="text-align: right; font-size: 0.8rem;">{{ project.progress }}% complete</div>
            
            <div style="margin-top: 1rem;">
                <form action="{{ url_for('update_project', project_id=project.id) }}" method="post" style="display:inline;">
                    <input type="hidden" name="status" value="active">
                    <button type="submit" class="btn btn-small btn-success">Mark Active</button>
                </form>
                
                <form action="{{ url_for('update_project', project_id=project.id) }}" method="post" style="display:inline;">
                    <input type="hidden" name="status" value="completed">
                    <button type="submit" class="btn btn-small btn-warning">Mark Completed</button>
                </form>
                
                <a href="{{ url_for('add_task') }}" class="btn btn-small">Add Task</a>
                <a href="{{ url_for('generate_feedback') }}" class="btn btn-small">Get AI Feedback</a>
            </div>
        </div>
    </div>
    
    <div class="grid">
        <div class="card">
            <h2>To Do</h2>
            {% if todo_tasks %}
                <ul class="task-list">
                    {% for task in todo_tasks %}
                        <li class="task-item priority-{{ task.priority }}">
                            <div><strong>{{ task.title }}</strong></div>
                            <div>{{ task.description }}</div>
                            {% if task.due_date %}
                                <div>Due: {{ task.due_date }}</div>
                            {% endif %}
                            <div style="margin-top: 0.5rem;">
                                <form action="{{ url_for('update_task', task_id=task.id) }}" method="post" style="display:inline;">
                                    <input type="hidden" name="status" value="in_progress">
                                    <button type="submit" class="btn btn-small btn-warning">Start</button>
                                </form>
                            </div>
                        </li>
                    {% endfor %}
                </ul>
            {% else %}
                <p>No tasks in this category.</p>
            {% endif %}
        </div>
        
        <div class="card">
            <h2>In Progress</h2>
            {% if in_progress_tasks %}
                <ul class="task-list">
                    {% for task in in_progress_tasks %}
                        <li class="task-item priority-{{ task.priority }}">
                            <div><strong>{{ task.title }}</strong></div>
                            <div>{{ task.description }}</div>
                            {% if task.due_date %}
                                <div>Due: {{ task.due_date }}</div>
                            {% endif %}
                            <div style="margin-top: 0.5rem;">
                                <form action="{{ url_for('update_task', task_id=task.id) }}" method="post" style="display:inline;">
                                    <input type="hidden" name="status" value="done">
                                    <button type="submit" class="btn btn-small btn-success">Complete</button>
                                </form>
                                
                                <form action="{{ url_for('update_task', task_id=task.id) }}" method="post" style="display:inline; margin-left: 0.5rem;">
                                    <input type="number" name="time_spent" placeholder="Hours spent" style="width: 100px; display: inline;">
                                    <button type="submit" class="btn btn-small">Log Time</button>
                                </form>
                            </div>
                        </li>
                    {% endfor %}
                </ul>
            {% else %}
                <p>No tasks in this category.</p>
            {% endif %}
        </div>
        
        <div class="card">
            <h2>Completed</h2>
            {% if done_tasks %}
                <ul class="task-list">
                    {% for task in done_tasks %}
                        <li class="task-item">
                            <div><strong>{{ task.title }}</strong></div>
                            <div>{{ task.description }}</div>
                            {% if task.completed_at %}
                                <div>Completed: {{ task.completed_at.split('T')[0] }}</div>
                            {% endif %}
                            {% if task.time_spent %}
                                <div>Time spent: {{ task.time_spent }} hours</div>
                            {% endif %}
                        </li>
                    {% endfor %}
                </ul>
            {% else %}
                <p>No tasks in this category.</p>
            {% endif %}
        </div>
    </div>
{% endblock %}''')
    
    with open(os.path.join(templates_dir, "add_project.html"), 'w') as f:
        f.write('''{% extends "base.html" %}

{% block title %}Add Project - Quantum Brain{% endblock %}

{% block content %}
    <div class="card">
        <h2>Add New Project</h2>
        <form action="{{ url_for('add_project') }}" method="post">
            <div class="form-group">
                <label for="name">Project Name</label>
                <input type="text" id="name" name="name" required>
            </div>
            
            <div class="form-group">
                <label for="description">Description</label>
                <textarea id="description" name="description" rows="4" required></textarea>
            </div>
            
            <div class="form-group">
                <label for="category">Category</label>
                <input type="text" id="category" name="category" required>
            </div>
            
            <div class="form-group">
                <label for="deadline">Deadline (optional)</label>
                <input type="date" id="deadline" name="deadline">
            </div>
            
            <div class="form-group">
                <label for="priority">Priority</label>
                <select id="priority" name="priority">
                    <option value="low">Low</option>
                    <option value="medium" selected>Medium</option>
                    <option value="high">High</option>
                </select>
            </div>
            
            <div class="form-group">
                <label for="tags">Tags (comma-separated)</label>
                <input type="text" id="tags" name="tags">
            </div>
            
            <button type="submit" class="btn">Add Project</button>
        </form>
    </div>
{% endblock %}''')
    
    with open(os.path.join(templates_dir, "add_task.html"), 'w') as f:
        f.write('''{% extends "base.html" %}

{% block title %}Add Task - Quantum Brain{% endblock %}

{% block content %}
    <div class="card">
        <h2>Add New Task</h2>
        <form action="{{ url_for('add_task') }}" method="post">
            <div class="form-group">
                <label for="title">Task Title</label>
                <input type="text" id="title" name="title" required>
            </div>
            
            <div class="form-group">
                <label for="description">Description</label>
                <textarea id="description" name="description" rows="4" required></textarea>
            </div>
            
            <div class="form-group">
                <label for="project_id">Project</label>
                <select id="project_id" name="project_id" required>
                    {% for project in projects %}
                        <option value="{{ project.id }}">{{ project.name }}</option>
                    {% endfor %}
                </select>
            </div>
            
            <div class="form-group">
                <label for="due_date">Due Date (optional)</label>
                <input type="date" id="due_date" name="due_date">
            </div>
            
            <div class="form-group">
                <label for="priority">Priority</label>
                <select id="priority" name="priority">
                    <option value="low">Low</option>
                    <option value="medium" selected>Medium</option>
                    <option value="high">High</option>
                </select>
            </div>
            
            <button type="submit" class="btn">Add Task</button>
        </form>
    </div>
{% endblock %}''')
    
    with open(os.path.join(templates_dir, "view_feedback.html"), 'w') as f:
        f.write('''{% extends "base.html" %}

{% block title %}AI Feedback - Quantum Brain{% endblock %}

{% block content %}
    <div class="card">
        <h2>AI Feedback</h2>
        <h3>{{ filename }}</h3>
        <div style="white-space: pre-wrap;">{{ content }}</div>
        <p><a href="{{ url_for('index') }}" class="btn">Back to Dashboard</a></p>
    </div>
{% endblock %}''')
    
    # Create systemd service file
    systemd_dir = os.path.expanduser("~/.config/systemd/user")
    os.makedirs(systemd_dir, exist_ok=True)
    
    with open(os.path.join(systemd_dir, "quantum-brain-tracker.service"), 'w') as f:
        f.write(f'''[Unit]
Description=Quantum Brain Project Tracker Web Interface
After=network.target

[Service]
ExecStart=/usr/bin/python3 {os.path.join(DATA_DIR, "web_interface.py")}
WorkingDirectory={DATA_DIR}
Environment="FLASK_APP=web_interface.py"
Environment="FLASK_ENV=production"
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
''')
    
    # Create charts directory for web server
    os.makedirs(os.path.join(DATA_DIR, "static", "charts"), exist_ok=True)
    
    app.template_folder = templates_dir
    app.static_folder = os.path.join(DATA_DIR, "static")
    app.static_url_path = "/static"
    
    # Create symbolic links for charts
    os.symlink(os.path.join(DATA_DIR, "charts"), os.path.join(DATA_DIR, "static", "charts"))
    
    app.run(host='0.0.0.0', port=5000)
EOL

chmod +x web_interface.py

# Create a systemd service for the daemon
cat > "$USER_CONFIG_DIR/quantum-brain-daemon.service" << EOL
[Unit]
Description=Quantum Brain Project Tracker Daemon
After=network.target

[Service]
ExecStart=python3 $USER_DATA_DIR/tracker/project_tracker.py run-scheduler
WorkingDirectory=$USER_DATA_DIR/tracker
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOL

# Copy the tracker files
cp project_tracker.py "$USER_DATA_DIR/tracker/"
cp web_interface.py "$USER_DATA_DIR/tracker/"

# Create a startup script for Quantum Brain
cd "$QUANTUM_BRAIN_HOME"
cat > start-quantum-brain.sh << EOL
#!/bin/bash

# Quantum Brain Startup Script

# Start Logseq
flatpak run com.logseq.Logseq &

# Start Plane
cd $USER_DATA_DIR/projects/plane
docker-compose up -d

# Start Docusaurus
cd $USER_DATA_DIR/documentation/docs-site
npm start &

# Start project tracker
systemctl --user start quantum-brain-tracker
xdg-open http://localhost:5000

echo "Quantum Brain is now running!"
EOL

chmod +x start-quantum-brain.sh

# Create symlinks in user's bin directory
mkdir -p "$HOME/.local/bin"
ln -sf "$QUANTUM_BRAIN_HOME/start-quantum-brain.sh" "$HOME/.local/bin/quantum-brain"
ln -sf "$USER_DATA_DIR/tracker/project_tracker.py" "$HOME/.local/bin/project-tracker"

# Create desktop shortcut
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/quantum-brain.desktop" << EOL
[Desktop Entry]
Name=Quantum Brain
Comment=Knowledge Management and Project Tracking System
Exec=$HOME/.local/bin/quantum-brain
Icon=evolution
Terminal=false
Type=Application
Categories=Office;ProjectManagement;
EOL

# Enable systemd services
systemctl --user enable "$USER_CONFIG_DIR/quantum-brain-daemon.service"
systemctl --user enable quantum-brain-tracker.service

# Create tutorial project
mkdir -p "$USER_PROJECTS_DIR/quantum-brain-tutorial"
cd "$USER_PROJECTS_DIR/quantum-brain-tutorial"

cat > README.md << 'EOL'
# Quantum Brain Tutorial

This is a tutorial project to help you get started with Quantum Brain.

## Features Overview

- **Knowledge Management**: Organize and connect your ideas
- **Project Tracking**: Monitor progress and deadlines
- **AI Feedback**: Get insights and suggestions for improvement
- **Calendar Integration**: Stay on top of deadlines and tasks
- **Documentation**: Create comprehensive documentation for your projects

## Next Steps

1. Create your first real project
2. Set up regular review reminders
3. Configure AI feedback
4. Explore the knowledge graph
EOL

# Complete setup
echo -e "${GREEN}Quantum Brain installation complete!${NC}"
echo
echo -e "${BLUE}Directory Structure:${NC}"
echo -e "  System files: ${YELLOW}$QUANTUM_BRAIN_HOME${NC}"
echo -e "  User data: ${YELLOW}$USER_DATA_DIR${NC}"
echo -e "  User config: ${YELLOW}$USER_CONFIG_DIR${NC}"
echo -e "  Projects: ${YELLOW}$USER_PROJECTS_DIR${NC}"
echo
echo -e "${BLUE}To start Quantum Brain:${NC}"
echo -e "  Run: ${YELLOW}quantum-brain${NC} or click the desktop shortcut"
echo
echo -e "${BLUE}To use the project tracker directly:${NC}"
echo -e "  Run: ${YELLOW}project-tracker <command>${NC}"
echo -e "  Examples:"
echo -e "    ${YELLOW}project-tracker list-projects${NC}"
echo -e "    ${YELLOW}project-tracker add-project \"My Project\" \"Description\" \"Category\"${NC}"
echo -e "    ${YELLOW}project-tracker add-task \"Task Title\" \"Description\" 1${NC}"
echo
echo -e "${BLUE}Web Interface:${NC}"
echo -e "  Open: ${YELLOW}http://localhost:5000${NC} in your browser"
echo
echo -e "${BLUE}Initial Setup:${NC}"
echo -e "  1. Start Quantum Brain: ${YELLOW}quantum-brain${NC}"
echo -e "  2. Set up Logseq when it starts by pointing it to: ${YELLOW}$USER_DATA_DIR/knowledge-base${NC}"
echo -e "  3. Configure project metadata and AI feedback in the tracker web interface"
echo -e "  4. Check out the tutorial project at: ${YELLOW}$USER_PROJECTS_DIR/quantum-brain-tutorial${NC}"
echo
echo -e "${GREEN}Enjoy your organized and productive journey with Quantum Brain!${NC}"
