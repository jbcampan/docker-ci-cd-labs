from fastapi import FastAPI

app = FastAPI(title="Lab 03 - Docker Build CI")


@app.get("/")
def root():
    return {"message": "Hello from GHCR!", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "healthy"}