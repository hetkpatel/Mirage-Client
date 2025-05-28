# Mirage Web

## Overview

The **Mirage Web** is the web-based interface of the Mirage photo storage and management system. Designed with privacy and usability in mind, it provides a rich user experience to browse, organize, and interact with your personal media collection. It connects to the Mirage backend via RESTful API calls to perform various tasks such as viewing media, creating albums, tagging, searching, and more.

> **Note:** This is a work in progress project. The frontend is actively being developed and improved.
>
> This is only an example of a frontend client for the backend. Advanced users are encouraged to build their own frontend tailored to their needs using the Mirage backend API.

## Features

* **Interactive Gallery**: Browse photos and videos in a sleek, responsive interface.
* **Face Recognition Display**: View automatically detected faces and group them by individual.
* **Album Management**: Create, edit, and browse albums.
* **Duplicate Grouping**: See visually similar media grouped together for easy cleanup.
* **Advanced Search**: Filter by people, location, date, or custom tags.
* **Metadata Display**: View detailed metadata, including EXIF data.
* **Annotations**: Add titles, tags, and comments to photos.
* **Authentication**: Secure login to protect access to your media.

## Project Structure

The frontend is built using Flutter and best practices. It is served via a Docker container and connects to the Flask-based Mirage backend.

## Installation

### Recommended: Docker Compose (with Backend)

The easiest way to run the frontend (along with the backend) is using Docker Compose. From the Mirage project root:

```bash
git clone https://github.com/hetkpatel/Mirage.git
cd Mirage
cp example.env .env

# Update environment variables as needed

docker compose up -d
```

* The frontend will be available at `http://localhost:80`
* The backend API will be running at `http://localhost:5000`

## License

This project is licensed under the GNU AGPLv3 License - see the [LICENSE](LICENSE) file for details.
